# encoding:utf-8
'''
Create on 2023-11-02
@author: zhangming
Describe: index_put in cpu/cuda
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
    if len(input_lists) < 3:
        print("The number of input data is wrong.")
        return False
    if len(reuse_lists) > 1:
        print("The number of reuse data is wrong.")
        return False
    if len(output_lists) > 1:
        print("The number of output data is wrong.")
        return False
    return True


def test_index_put(param_path, input_lists, reuse_lists, output_lists, device):
    if not check_inputs(param_path, input_lists, reuse_lists, output_lists):
        return
    params = read_prototxt(param_path)
    if "tecoal_param" in params:
        index_put_param = params["tecoal_param"]["index_put_param"]  
        index_num = int(index_put_param["indexputnum"])
        accumulate = index_put_param["accumulate"]
        if accumulate == 1 or accumulate == "true":
            accumulate = True
        else:
            accumulate = False
    else:
        index_num = len(params["input"]) - 2
        accumulate = True
    # index_put_param = params["tecoal_param"]["index_put_param"]  
    # index_num = int(index_put_param["indexputnum"])
    index_no = 0
    value_no = index_num + 0
    input_no = index_num + 1
    index = []

    index_type = params["input"][index_no]["dtype"]
    if index_type == 'DTYPE_BOOL':
        index_tensor = to_tensor(input_lists[index_no], params["input"][index_no], device=device)
    for i in range(index_num):
        cur_tensor = to_tensor(input_lists[i], params["input"][i], device=device)
        if index_type == 'DTYPE_BOOL':
            index.append(cur_tensor.bool())
        else:
            index.append(cur_tensor)

    value = to_tensor(input_lists[value_no], params["input"][value_no], device=device)
    input_tensor = to_tensor(input_lists[input_no], params["input"][input_no], device=device)
    if index_type == 'DTYPE_BOOL':
        index_true_num = index[0].sum()
        # value = value.reshape(-1)
        # value = value[0:index_true_num]
        if index_true_num != 0 :
            if len(value.shape) == len(input_tensor.shape) - len(index_tensor.shape) + 1:
                tmp_value = torch.split(value, index_true_num, dim=0)
                value = tmp_value[0]
        else:
            value = value.reshape(-1)
            value = value[0]
    # tod 
    output = input_tensor.index_put(index, value, accumulate)
    output_dtype = params["input"][input_no]["dtype"]
    with open(reuse_lists[0], "wb") as f:
        save_tensor(f, output, output_dtype)

def parse_params(filename):
    with open(filename, "r") as f:
        params = json.load(f)
    return params

if __name__ == "__main__":
    params = parse_params(sys.argv[1])
    device = sys.argv[2]
    test_index_put(params["param_path"], params["input_lists"], params["reuse_lists"], params["output_lists"], device)
    