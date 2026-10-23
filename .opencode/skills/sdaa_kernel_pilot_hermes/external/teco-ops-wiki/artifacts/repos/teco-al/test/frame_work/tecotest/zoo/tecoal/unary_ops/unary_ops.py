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
sys.path.append("../tools/")
# from extractor import get_cuda_ops_perf

def unary_ops(op, alpha, y):
    if op == "BATCH_LOG":
        return torch.log(y)
    if op == "BATCH_EXP":
        return torch.exp(y)
    if op == "BATCH_SQRT":
        return torch.sqrt(y)
    if op == "BATCH_RSQRT":
        return 1/torch.sqrt(y)
    if op == "BATCH_SQUARE":
        return torch.pow(y, 2)
    if op == "BATCH_SIN":
        return torch.sin(y)
    if op == "BATCH_COS":
        return torch.cos(y)
    if op == "BATCH_TANH":
        return torch.tanh(y)
    if op == "BATCH_CEIL":
        return torch.ceil(y)
    if op == "BATCH_FLOOR":
        return torch.floor(y)
    if op == "BATCH_FABS":
        return torch.abs(y)

    if op == "BATCH_ADD_A":
        return y + alpha
    if op == "BATCH_SUB_A":
        return y - alpha
    if op == "BATCH_MUL_A":
        return alpha*y
    if op == "BATCH_DIV_A":
        return y/alpha
    if op == "BATCH_RDIV":
        return alpha/y
    if op == "BATCH_POW":
        return torch.pow(y, alpha)

    if op == "BATCH_S2H":
        return y.type(torch.float16)
    if op == "BATCH_H2S":
        return y.type(torch.float32)

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

def test_unary_ops(param_path, input_lists, reuse_lists, output_lists, device):
    if not check_inputs(param_path, input_lists, reuse_lists, output_lists):
        return

    params = read_prototxt(param_path)
    unary_ops_params = params["tecoal_param"]["unary_ops_param"]
    mode = unary_ops_params["mode"]
    alpha = unary_ops_params["unary_alpha"]
    modedic = {13:'BATCH_MUL_A'}

    if type(mode) != str:
        mode = modedic[int(mode)]
    input_params = params["input"]
    output_params = params["output"]
    out_dtype = output_params['dtype']
    x = to_tensor(input_lists[0], input_params, device=device)
    if (out_dtype == 'DTYPE_BOOL'):
        alpha = bool(alpha)
    if (out_dtype == 'DTYPE_INT64' or out_dtype == 'DTYPE_INT32'):
        alpha = int(alpha)
    output = unary_ops(mode, alpha, x)
    out_dtype = output_params["dtype"]
    with open(output_lists[0], "wb") as f:
        save_tensor(f, output, out_dtype)


def parse_params(filename):
    with open(filename, "r") as f:
        params = json.load(f)
    return params

if __name__ == "__main__":
    params = parse_params(sys.argv[1])
    device = sys.argv[2]
    test_unary_ops(params["param_path"], params["input_lists"], params["reuse_lists"], params["output_lists"], device)

