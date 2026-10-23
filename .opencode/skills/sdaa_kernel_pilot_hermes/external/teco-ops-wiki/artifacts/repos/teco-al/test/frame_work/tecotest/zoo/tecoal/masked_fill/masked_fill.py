# encoding:utf-8
'''
Create on 2023-01-09
@author: shaoshuo
Describe: test python file of masked_fill
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
    if param_path == "":
        print("The path of prototxt file is empty.")
        return False
    if len(input_lists) != 2:
        print("The number of input data is wrong.")
        return False
    if len(reuse_lists) != 0:
        print("The number of reuse data is wrong.")
        return False
    if len(output_lists) != 1:
        print("The number of output data is wrong.")
        return False
    return True

def test_masked_fill(param_path, input_lists, reuse_lists, output_lists, device):
    if not check_inputs(param_path, input_lists, reuse_lists, output_lists):
        return

    device_available, used_device = is_device_available(device)
    if not device_available:
        return

    params = read_prototxt(param_path)
    masked_fill_params = params["tecoal_param"]["masked_fill_param"]
    value = masked_fill_params["value"]

    input_params = params["input"]
    x_dtype = input_params[0]["dtype"]
    x = to_tensor(input_lists[0], input_params[0], device=device)
    mask = to_tensor(input_lists[1], input_params[1], device=device).type(torch.bool)
    y = x.masked_fill(mask,value)

    with open(output_lists[0], "wb") as f:
        save_tensor(f, y, x_dtype)

def parse_params(filename):
    with open(filename, "r") as f:
        params = json.load(f)
    return params

if __name__ == "__main__":
    params = parse_params(sys.argv[1])
    device = sys.argv[2]
    test_masked_fill(params["param_path"], params["input_lists"], params["reuse_lists"], params["output_lists"], device=device)

