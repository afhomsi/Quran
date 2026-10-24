#!/usr/bin/env python3
"""Stores the decoder's token embedding in int8 instead of float32.

onnxruntime's dynamic quantization leaves the embedding that the decoder
looks tokens up in (a Gather) in float32, and that table is most of the
int8 decoder's size. This replaces each large float Gather table with an
int8 table and one scale per row, and looks up both:

    Gather(table, ids) -> Gather(table_q, ids) * Gather(scales, ids)

    python shrink_embedding.py in.onnx out.onnx
"""

import sys

import numpy as np
import onnx
from onnx import helper, numpy_helper, TensorProto


def shrink(src: str, dst: str, min_size: int = 1_000_000) -> None:
    model = onnx.load(src)
    graph = model.graph
    inits = {i.name: i for i in graph.initializer}
    users = {}
    for node in graph.node:
        for name in node.input:
            users.setdefault(name, []).append(node)

    nodes = []
    for node in graph.node:
        table = inits.get(node.input[0]) if node.op_type == "Gather" else None
        axis = next((a.i for a in node.attribute if a.name == "axis"), 0)
        if (
            table is None
            or axis != 0
            or table.data_type != TensorProto.FLOAT
            or np.prod(table.dims) < min_size
        ):
            nodes.append(node)
            continue

        w = numpy_helper.to_array(table)
        scales = np.abs(w).max(axis=1) / 127
        scales[scales == 0] = 1
        q = np.round(w / scales[:, None]).clip(-127, 127).astype(np.int8)
        base = table.name
        graph.initializer.append(numpy_helper.from_array(q, base + "_q"))
        graph.initializer.append(
            numpy_helper.from_array(scales[:, None].astype(np.float32), base + "_scale")
        )
        out = node.output[0]
        nodes += [
            helper.make_node("Gather", [base + "_q", node.input[1]], [out + "_q"], axis=0),
            helper.make_node("Cast", [out + "_q"], [out + "_f"], to=TensorProto.FLOAT),
            helper.make_node("Gather", [base + "_scale", node.input[1]], [out + "_s"], axis=0),
            helper.make_node("Mul", [out + "_f", out + "_s"], [out]),
        ]
        # Drop the float table unless something else still reads it.
        if len(users[base]) == 1:
            graph.initializer.remove(table)
        print(f"{base}: {w.shape} -> int8")

    del graph.node[:]
    graph.node.extend(nodes)
    onnx.checker.check_model(model)
    onnx.save(model, dst)


if __name__ == "__main__":
    shrink(sys.argv[1], sys.argv[2])
