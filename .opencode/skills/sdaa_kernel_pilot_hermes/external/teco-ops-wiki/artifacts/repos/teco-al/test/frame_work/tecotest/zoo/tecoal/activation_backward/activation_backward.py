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
import torch.nn as nn
sys.path.append("../zoo/tecoal/")
sys.path.append("../")
from executor import *

def check_inputs(param_path, input_lists, reuse_lists, output_lists):
    if param_path == "":
        print("The path of prototxt file is empty.")
        return False
    if len(input_lists) != 4:
        print("The number of input data is wrong.")
        return False
    if len(reuse_lists) != 1:
        print("The number of reuse data is wrong.")
        return False
    if len(output_lists) != 0:
        print("The number of output data is wrong.")
        return False
    return True

mode_convert = {0:"ACTIVATION_SIGMOID",
                1:"ACTIVATION_RELU",
                2:"ACTIVATION_TANH",
                3:"ACTIVATION_CLIPPED_RELU",
                4:"ACTIVATION_ELU",
                5:"ACTIVATION_IDENTITY",
                6:"ACTIVATION_SIGMOID_TAB",
                7:"ACTIVATION_ELU_TAB",
                8:"ACTIVATION_TANH_TAB",
                9:"ACTIVATION_GELU",
                10:"ACTIVATION_LEAKYRELU",
                11:"ACTIVATION_SELU",
                12:"ACTIVATION_RELU6",
                13:"ACTIVATION_SILU",
                14:"ACTIVATION_GELU_APPROXIMATE",
                15:"ACTIVATION_TANH_ACCURATE",
                16:"ACTIVATION_GELU_ACCURATE",
                17:"ACTIVATION_GELU_APPROXIMATE_ACCURATE",
                18:"ACTIVATION_SIGMOID_PRECISION"
                }

def test_activation_backward(param_path, input_lists, reuse_lists, output_lists, device):
    if not check_inputs(param_path, input_lists, reuse_lists, output_lists):
        return
    params = read_prototxt(param_path)
    # api params
    activation_backward_param = params["tecoal_param"]["activation_backward_param"]
    alpha = activation_backward_param["alpha"]
    beta = activation_backward_param["beta"]
    activation_desc_param = activation_backward_param["act_desc_param"]
    activation_mode = activation_desc_param["mode"]
    # nanPropagation_ = activation_desc_param["relu_nanopt"]
    coef = activation_desc_param["coef"]

    if type(activation_mode) != str:
        activation_mode = mode_convert[int(activation_mode)]
    
    input_params = params["input"]
    dx_dtype = input_params[3]["dtype"]
    dy = to_tensor(input_lists[1], input_params[1], device=device)
    x = to_tensor(input_lists[2], input_params[2], device=device)
    x.requires_grad=True

    if activation_mode == "ACTIVATION_SIGMOID":
        sigmoid = torch.nn.Sigmoid()
        y = sigmoid(x)

    if activation_mode == "ACTIVATION_RELU":
        relu = torch.nn.ReLU()
        y = relu(x)
   
    if activation_mode == "ACTIVATION_TANH":
        tanh = torch.nn.Tanh()
        y = tanh(x)

    if activation_mode == "ACTIVATION_TANH_ACCURATE":
        tanh = torch.nn.Tanh()
        y = tanh(x)

    if activation_mode == "ACTIVATION_CLIPPED_RELU":
        y_max = torch.relu(x)
        tensor_coef = torch.full(y_max.shape, coef, device=x.device)
        y = torch.where(y_max < tensor_coef, y_max, tensor_coef)
    
    if activation_mode == "ACTIVATION_ELU":
        elu = torch.nn.ELU(alpha=coef)
        y = elu(x)

    if activation_mode == "ACTIVATION_IDENTITY":
        y = x

    if activation_mode == "ACTIVATION_SIGMOID_TAB":
        sigmoid = torch.nn.Sigmoid()
        y = sigmoid(x)

    if activation_mode == "ACTIVATION_ELU_TAB":
        elu = torch.nn.ELU(alpha=coef)
        y = elu(x)

    if activation_mode == "ACTIVATION_TANH_TAB":
        tanh = torch.nn.Tanh()
        y = tanh(x)

    if activation_mode == "ACTIVATION_GELU":
        gelu = torch.nn.GELU()
        y = gelu(x)

    if activation_mode == "ACTIVATION_GELU_ACCURATE":
        gelu = torch.nn.GELU()
        y = gelu(x)

    if activation_mode == "ACTIVATION_LEAKYRELU":
        leakyRelu = torch.nn.LeakyReLU(negative_slope=coef)
        y = leakyRelu(x)

    if activation_mode == "ACTIVATION_SELU":
        selu = torch.nn.SELU()
        y = selu(x)

    if activation_mode == "ACTIVATION_RELU6":
        relu6 = torch.nn.ReLU6()
        y = relu6(x)

    if activation_mode == "ACTIVATION_SILU":
        silu = torch.nn.SiLU()
        y = silu(x)

    if activation_mode == "ACTIVATION_GELU_APPROXIMATE":
        gelu = torch.nn.GELU(approximate='tanh')
        y = gelu(x)

    if activation_mode == "ACTIVATION_GELU_APPROXIMATE_ACCURATE":
        gelu = torch.nn.GELU(approximate='tanh')
        y = gelu(x)

    if activation_mode == "ACTIVATION_SIGMOID_PRECISION":
        sigmoid = torch.nn.Sigmoid()
        y = sigmoid(x)

    y.backward(dy)
    dx = alpha * x.grad
    if beta != 0:
        dx_in = to_tensor(input_lists[3], input_params[3], device=device)
        dx += beta * dx_in

    with open(reuse_lists[0], "wb") as f:
        save_tensor(f, dx, dx_dtype)

def parse_params(filename):
    with open(filename, "r") as f:
        params = json.load(f)
    return params

if __name__ == "__main__":
    params = parse_params(sys.argv[1])
    device = sys.argv[2]
    test_activation_backward(params["param_path"], params["input_lists"], params["reuse_lists"], params["output_lists"], device)
