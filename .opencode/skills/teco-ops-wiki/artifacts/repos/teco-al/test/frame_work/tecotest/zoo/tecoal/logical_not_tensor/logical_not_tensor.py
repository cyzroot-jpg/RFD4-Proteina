# encoding:utf-8
'''
Create on 2023-01-09
@author: 
Describe: 
'''

import os
import sys
import json
import torch
import numpy as np
sys.path.append("../zoo/tecoal/")
sys.path.append("../")
from executor import *

def check_inputs(param_path, input_lists, reuse_lists, output_lists):
    # TODO
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

def test_logical_not_tensor(param_path, input_lists, reuse_lists, output_lists, device):
    if not check_inputs(param_path, input_lists, reuse_lists, output_lists):
        return
    params = read_prototxt(param_path)

    input_params = params["input"]
    output_params = params["output"]
    input1 = to_tensor(input_lists[0], input_params, device=device)
    output = torch.logical_not(input1)

    c_dtype = output_params["dtype"]
    with open(output_lists[0], "wb") as f:
        save_tensor(f, output, c_dtype)

def parse_params(filename):
    with open(filename, "r") as f:
        params = json.load(f)
    return params

if __name__ == "__main__":
    params = parse_params(sys.argv[1])
    device = sys.argv[2]
    test_logical_not_tensor(params["param_path"], params["input_lists"], params["reuse_lists"], params["output_lists"], device)

