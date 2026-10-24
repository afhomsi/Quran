#!/usr/bin/env python3
"""Lists a model's large tables and the nodes that read them.

    python inspect_model.py model.onnx ...
"""

import os
import sys

import numpy as np
import onnx

for path in sys.argv[1:]:
    model = onnx.load(path)
    graph = model.graph
    print(f"== {path}: {os.path.getsize(path) / 1e6:.1f} MB")
    big = {
        i.name: (list(i.dims), onnx.TensorProto.DataType.Name(i.data_type))
        for i in graph.initializer
        if np.prod(i.dims) >= 1_000_000
    }
    for node in graph.node:
        if node.op_type == "Constant":
            for a in node.attribute:
                if a.t and np.prod(a.t.dims) >= 1_000_000:
                    print(f"  Constant {node.output[0]} {list(a.t.dims)}")
        for name in node.input:
            if name in big:
                print(f"  {name} {big[name]} <- {node.op_type} {node.name}")
