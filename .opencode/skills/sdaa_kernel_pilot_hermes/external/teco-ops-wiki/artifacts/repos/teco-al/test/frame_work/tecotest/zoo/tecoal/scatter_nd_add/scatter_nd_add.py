# encoding:utf-8

import os
import sys
import paddle
import json
import numpy as np
sys.path.append("../zoo/tecoal/")
sys.path.append("../")
from executor import *

def check_inputs(param_path, input_lists, reuse_lists, output_lists):
    if param_path == "":
        print("The path of prototxt file is empty.")
        return False
    if len(input_lists) != 3:
        print("The number of input data is wrong.")
        return False
    if len(reuse_lists) != 0:
        print("The number of reuse data is wrong.")
        return False
    if len(output_lists) != 1:
        print("The number of output data is wrong.")
        return False
    return True

def test_scatter_nd_add(param_path, input_lists, reuse_lists, output_lists, device):
    if not check_inputs(param_path, input_lists, reuse_lists, output_lists):
        return

    params = read_prototxt(param_path)
    input_params = params["input"]
    x = to_tensor(input_lists[0], input_params[0], framework="paddle", device=device)
    index = to_tensor(input_lists[1], input_params[1], framework="paddle", device=device)
    dy = to_tensor(input_lists[2], input_params[2], framework="paddle", device=device)
    dx = paddle.scatter_nd_add(x, index, dy)
    dx_dtype = params["output"]["dtype"]
    with open(output_lists[0], "wb") as f:
        save_tensor(f, dx, dx_dtype, framework="paddle")

def parse_params(filename):
    with open(filename, "r") as f:
        params = json.load(f)
    return params

if __name__ == "__main__":
    params = parse_params(sys.argv[1])
    device = sys.argv[2]
    test_scatter_nd_add(params["param_path"], params["input_lists"], params["reuse_lists"], params["output_lists"], device)
