# encoding:utf-8
'''
Create on 2023-01-18
@author:wwq 
Describe: 
'''

import os
import sys
import torch
import numpy as np
import json
sys.path.append("../zoo/tecoal/")
sys.path.append("../")
from executor import *

def check_inputs(param_path, input_lists, reuse_lists, output_lists):
    if param_path == "":
        print("The path of prototxt file is empty.")
        return False
    if len(input_lists) != 1:
        print("The number of input data is wrong.")
        return False
    if len(reuse_lists) != 0:
        print("The number of reuse data is wrong.")
        return False
    if len(output_lists) != 1:
        print("The number of output data is wrong.")
        return False
    return True

def test_arg_max(param_path, input_lists, reuse_lists, output_lists):
    if not check_inputs(param_path, input_lists, reuse_lists, output_lists):
        return

    params = read_prototxt(param_path)
    # api params
    arg_max_params = params["tecoal_param"]["arg_max_param"]
    axis = arg_max_params["axis"]

    # TODO 
    input_params = params["input"]
    x1 = to_tensor(input_lists[0], input_params)
    x = x1.type(torch.float32)

    y = torch.argmax(x, dim=int(axis))
    with open(output_lists[0], "wb") as f:
        save_tensor(f, y)

def parse_params(filename):
    with open(filename, "r") as f:
        params = json.load(f)
    return params

if __name__ == "__main__":
    params = parse_params(sys.argv[1])
    test_arg_max(params["param_path"], params["input_lists"], params["reuse_lists"], params["output_lists"])

