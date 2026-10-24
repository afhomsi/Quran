#!/usr/bin/env python3
"""Makes an int8 Whisper decoder without any float32 token embedding.

The decoder reads its token embedding twice: a Gather looks up the input
tokens, and the output layer multiplies by its transpose. Because the
transpose is computed in the graph, onnxruntime's dynamic quantization
quantizes neither, and the float32 table is most of the int8 decoder's
size. This script

1. stores the transposed table as its own initializer, so dynamic
   quantization turns the output layer into an int8 MatMul, and
2. replaces the Gather table with an int8 table and one scale per row:

       Gather(table, ids) -> Gather(table_q, ids) * Gather(scales, ids)

    python shrink_embedding.py decoder.onnx decoder.small.onnx
"""

import os
import sys
import tempfile

import numpy as np
import onnx
from onnx import helper, numpy_helper, TensorProto
from onnxruntime.quantization import QuantType, quantize_dynamic

_MIN_SIZE = 1_000_000


def _big_float_tables(graph):
    inits = {i.name: i for i in graph.initializer}
    return {
        node.input[0]: inits[node.input[0]]
        for node in graph.node
        if node.op_type == "Gather"
        and node.input[0] in inits
        and inits[node.input[0]].data_type == TensorProto.FLOAT
        and np.prod(inits[node.input[0]].dims) >= _MIN_SIZE
    }


def _rewire(nodes, renames) -> None:
    for node in nodes:
        for k, name in enumerate(node.input):
            if name in renames:
                node.input[k] = renames[name]


def _fold_transposes(model) -> None:
    """Turns Transpose(table) into a constant transposed table.

    The exporter reads the table for the output layer through an Identity,
    so those are bypassed first.
    """
    graph = model.graph
    tables = _big_float_tables(graph)
    identities = {
        node.output[0]: node.input[0]
        for node in graph.node
        if node.op_type == "Identity" and node.input[0] in tables
    }
    kept = [n for n in graph.node if n.output[0] not in identities]
    _rewire(kept, identities)
    renames = {}
    nodes = kept
    kept = []
    for node in nodes:
        if node.op_type == "Transpose" and node.input[0] in tables:
            perm = next((list(a.ints) for a in node.attribute if a.name == "perm"), None)
            w = numpy_helper.to_array(tables[node.input[0]])
            name = node.input[0] + "_transposed"
            graph.initializer.append(
                numpy_helper.from_array(np.ascontiguousarray(np.transpose(w, perm)), name)
            )
            renames[node.output[0]] = name
            print(f"folded Transpose of {node.input[0]} into {name}")
        else:
            kept.append(node)
    _rewire(kept, renames)
    for node in kept:
        if any(name in tables for name in node.input) and node.op_type != "Gather":
            print(f"table still read by {node.op_type} {node.name}")
    del graph.node[:]
    graph.node.extend(kept)


def _quantize_gathers(model) -> None:
    graph = model.graph
    tables = _big_float_tables(graph)
    nodes = []
    for node in graph.node:
        axis = next((a.i for a in node.attribute if a.name == "axis"), 0)
        if node.op_type != "Gather" or node.input[0] not in tables or axis != 0:
            nodes.append(node)
            continue
        base = node.input[0]
        w = numpy_helper.to_array(tables[base])
        scales = np.abs(w).max(axis=1) / 127
        scales[scales == 0] = 1
        q = np.round(w / scales[:, None]).clip(-127, 127).astype(np.int8)
        if not any(i.name == base + "_q" for i in graph.initializer):
            graph.initializer.append(numpy_helper.from_array(q, base + "_q"))
            graph.initializer.append(
                numpy_helper.from_array(
                    scales[:, None].astype(np.float32), base + "_scale"
                )
            )
        out = node.output[0]
        nodes += [
            helper.make_node("Gather", [base + "_q", node.input[1]], [out + "_q"], axis=0),
            helper.make_node("Cast", [out + "_q"], [out + "_f"], to=TensorProto.FLOAT),
            helper.make_node("Gather", [base + "_scale", node.input[1]], [out + "_s"], axis=0),
            helper.make_node("Mul", [out + "_f", out + "_s"], [out]),
        ]
        print(f"{base}: {w.shape} -> int8 rows")
    del graph.node[:]
    graph.node.extend(nodes)

    used = {name for node in graph.node for name in node.input}
    for init in list(graph.initializer):
        if init.name not in used:
            graph.initializer.remove(init)
            print(f"dropped unused {init.name}")


def shrink(src: str, dst: str) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        folded = os.path.join(tmp, "folded.onnx")
        quantized = os.path.join(tmp, "quantized.onnx")
        model = onnx.load(src)
        _fold_transposes(model)
        onnx.save(model, folded)
        quantize_dynamic(
            model_input=folded,
            model_output=quantized,
            op_types_to_quantize=["MatMul"],
            weight_type=QuantType.QInt8,
        )
        model = onnx.load(quantized)
    _quantize_gathers(model)
    onnx.checker.check_model(model)
    onnx.save(model, dst)


if __name__ == "__main__":
    shrink(sys.argv[1], sys.argv[2])
