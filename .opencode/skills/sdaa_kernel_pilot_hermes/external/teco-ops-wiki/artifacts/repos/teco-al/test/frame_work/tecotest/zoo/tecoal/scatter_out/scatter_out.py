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
from executor import *

def check_inputs(param_path, input_lists, reuse_lists, output_lists):
    if param_path == "":
        print("The path of prototxt file is empty.")
        return False
    if len(input_lists) != 3:
        print("The number of input data is wrong.")
        return False
    if len(reuse_lists) != 1:
        print("The number of reuse data is wrong.")
        return False
    if len(output_lists) != 0:
        print("The number of output data is wrong.")
    return True
    
dic_mode = {"SCATTEROUT_REDUCTION_NONE": "none", "SCATTEROUT_REDUCTION_ADD": "add", "SCATTEROUT_REDUCTION_MULTIPLY": "multiply"}
int2mode = ["SCATTEROUT_REDUCTION_NONE", "SCATTEROUT_REDUCTION_ADD", "SCATTEROUT_REDUCTION_MULTIPLY"]

dic_type = {"SCATTEROUT_INPUT_SCALAR": "scalar", "SCATTEROUT_INPUT_ARRAY": "array"}
int2type = ["SCATTEROUT_INPUT_SCALAR", "SCATTEROUT_INPUT_ARRAY"]

def test_scatter_out(param_path, input_lists, reuse_lists, output_lists, device):
    if not check_inputs(param_path, input_lists, reuse_lists, output_lists):
        return
    
    params = read_prototxt(param_path)
    scatterout_param = params["tecoal_param"]["scatter_out_param"]
    
    targetDim = int(scatterout_param["target_dim"])
    alpha = scatterout_param["alpha"]
    reduce_mode = scatterout_param["scatter_out_reduce_mode"]
    input_type = scatterout_param["scatter_out_input_type"]

    try:
        reduce_mode = int2mode[int(reduce_mode)]
    except: 
        pass
    reduce_mode = dic_mode[reduce_mode]
        
    try:
        input_type = int2type[int(input_type)]
    except: 
        pass
    input_type = dic_type[input_type]

    input_params = params["input"]
    input_data = to_tensor(input_lists[0], input_params[0], device=device)
    index = to_tensor(input_lists[1], input_params[1], device=device).long()
    output = to_tensor(input_lists[2], input_params[2], device=device)
    output_dtype = input_params[2]["dtype"]
    
    if input_type == "scalar":
        if reduce_mode == 'none':
            output = output.scatter_(targetDim, index, alpha)
        else:
            output = output.scatter_(targetDim, index, alpha, reduce = reduce_mode)
    elif input_type == "array":
        if reduce_mode == 'none':
            output = output.scatter_(targetDim, index, input_data)
        else:
            output = output.scatter_(targetDim, index, input_data, reduce = reduce_mode)
    else:
        print("only support scalar or array type.")

    with open(reuse_lists[0], "wb") as f:
        save_tensor(f, output, output_dtype)


def parse_params(filename):
    with open(filename, "r") as f:
        params = json.load(f)
    return params

if __name__ == "__main__":
    params = parse_params(sys.argv[1])
    device = sys.argv[2]
    test_scatter_out(params["param_path"], params["input_lists"], params["reuse_lists"], params["output_lists"], device)
