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
    if param_path == "":
        print("The path of prototxt file is empty.")
        return False
    if len(input_lists) != 3:
        print("The number of input data is wrong.")
        return False
    if len(reuse_lists) != 1:
        print("The number of reuse data is wrong.")
        return False
    return True

def test_conv_forward(param_path, input_lists, reuse_lists, output_lists, device):
    if not check_inputs(param_path, input_lists, reuse_lists, output_lists):
        return

    device_available, used_device = is_device_available(device)
    if not device_available:
        return

    params = read_prototxt(param_path)
    conv_forward_params = params["tecoal_param"]["conv_forward_param"]
    alpha = conv_forward_params["alpha"]
    beta = conv_forward_params["beta"]
    conv_desc_param = conv_forward_params["conv_desc_param"]
    input_params = params["input"]

    if 4 == len(input_params[1]["shape"]["dims"]):
        conv_dim = 2
    else:
        conv_dim = 3

    if 3 == conv_dim:
        stride = (int(conv_desc_param["stride_array"][0]), int(conv_desc_param["stride_array"][1]), int(conv_desc_param["stride_array"][2]))
        padding = (int(conv_desc_param["pad_array"][0]), int(conv_desc_param["pad_array"][1]), int(conv_desc_param["pad_array"][2]))
        dilation = (int(conv_desc_param["dilation_array"][0]), int(conv_desc_param["dilation_array"][1]), int(conv_desc_param["dilation_array"][2]))
    else :
        stride =(int(conv_desc_param["stride_h"]), int(conv_desc_param["stride_w"]))
        padding = (int(conv_desc_param["padding_h"]), int(conv_desc_param["padding_w"]))
        dilation = (int(conv_desc_param["dilation_h"]), int(conv_desc_param["dilation_w"]))
    groups = int(conv_desc_param["groups"])

    w_layout = input_params[1]["layout"]
    w_shape = input_params[1]["shape"]["dims"]
    if w_layout == "LAYOUT_CHWN":
        in_channel, kernel_h, kernel_w, out_channel = [int(i) for i in w_shape]
    elif w_layout == "LAYOUT_NHWC":
        out_channel, kernel_h, kernel_w, in_channel = [int(i) for i in w_shape]
    elif w_layout == "LAYOUT_NCHW":
        out_channel, in_channel, kernel_h, kernel_w = [int(i) for i in w_shape]
    elif w_layout == "LAYOUT_NWHC":
        out_channel, kernel_w, kernel_h, in_channel = [int(i) for i in w_shape]
    elif w_layout == "LAYOUT_NDHWC":
        out_channel, kernel_d, kernel_h, kernel_w, in_channel = [int(i) for i in w_shape]
    elif w_layout == "LAYOUT_CDHWN":
        in_channel, kernel_d, kernel_h, kernel_w, out_channel = [int(i) for i in w_shape]

    x_layout = input_params[0]["layout"]
    x_shape = input_params[0]["shape"]["dims"]
    if x_layout == "LAYOUT_NHWC":
        in_channel = int(x_shape[3])
    elif x_layout == "LAYOUT_NCHW":
        in_channel = int(x_shape[1])
    elif x_layout == "LAYOUT_NCHWD":
        in_channel = int(x_shape[1])
    elif x_layout == "LAYOUT_NDHWC":
        in_channel = int(x_shape[4])

    if 2 == conv_dim:
        conv = torch.nn.Conv2d(in_channel, out_channel, (kernel_h, kernel_w), stride=stride, padding=padding, dilation=dilation, groups=groups, bias=False)
    else:
        conv = torch.nn.Conv3d(in_channel, out_channel, (kernel_d, kernel_h, kernel_w), stride=stride, padding=padding, dilation=dilation, groups=groups, bias=False)

    if device=="cuda":
        conv.to(used_device)

    y_layout = input_params[2]["layout"]
    y_dtype = input_params[2]["dtype"]

    x = to_tensor(input_lists[0], input_params[0], device=device)
    w = to_tensor(input_lists[1], input_params[1], device=device)
    if 2 == conv_dim:
        x = tensor_to_NCHW(x, x_layout)
        w = tensor_to_NCHW(w, w_layout)
    else :
        x = tensor_to_NCDHW(x, x_layout)
        w = tensor_to_NCDHW(w, w_layout)

    if device == "cuda":
        # x and w trans to half except dwconv
        dwconv = (in_channel == groups) and (out_channel == groups)
        if not dwconv and x.dtype == torch.float32 and w.dtype == torch.float32:
            x = x.type(torch.float16).type(torch.float32)
            w = w.type(torch.float16).type(torch.float32)
        # support half half float
        if x.dtype==torch.float16 and w.dtype==torch.float16 and y_dtype=="DTYPE_FLOAT":
            x = x.type(torch.float32)
            w = w.type(torch.float32)

    conv.weight = torch.nn.Parameter(w)
    y = conv(x)

    if 2 == conv_dim:
        y = tensor_from_NCHW(y, y_layout)
    else :
        y = tensor_from_NCDHW(y, y_layout)
    y = alpha * y
    if beta != 0:
        y_in = to_tensor(input_lists[2], input_params[2], device=device)
        y += beta * y_in

    if torch.isinf(y).any():
        print("The output of the case includes Inf !!!")
    with open(reuse_lists[0], "wb") as f:
        save_tensor(f, y, y_dtype)

def parse_params(filename):
    with open(filename, "r") as f:
        params = json.load(f)
    return params

if __name__ == "__main__":
    params = parse_params(sys.argv[1])
    device = sys.argv[2]
    test_conv_forward(params["param_path"], params["input_lists"], params["reuse_lists"], params["output_lists"], device)