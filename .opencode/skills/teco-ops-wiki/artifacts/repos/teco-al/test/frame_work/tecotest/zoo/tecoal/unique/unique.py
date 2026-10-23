# encoding:utf-8
"""
Create on 2023-01-09
@author:
Describe:
"""

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
    if len(input_lists) != 4:
        print("The number of input data is wrong.")
        return False
    if len(reuse_lists) != 3:
        print("The number of reuse data is wrong.")
        return False
    if len(output_lists) != 1:
        print("The number of output data is wrong.")
        return False
    return True


def test_unique2(param_path, input_lists, reuse_lists, output_lists, device):
    if not check_inputs(param_path, input_lists, reuse_lists, output_lists):
        return

    params = read_prototxt(param_path)
    unique2_params = params["tecoal_param"]["unique_param"]
    is_sorted = unique2_params["sorted"]
    return_inverse = unique2_params["return_inverse"]
    return_counts = unique2_params["return_counts"]

    input_params = params["input"]
    output_params = params["output"]
    x = to_tensor(input_lists[0], input_params[0], device=device)
    y = to_tensor(input_lists[1], input_params[1], device=device)
    inverse = to_tensor(input_lists[2], input_params[2], device=device)
    counts = to_tensor(input_lists[3], input_params[3], device=device)
    values_dtype = input_params[1]["dtype"]
    inverse_dtype = input_params[2]["dtype"]
    counts_dtype = input_params[3]["dtype"]
    out_dtype = output_params["dtype"]
    if str(is_sorted) == "true" or is_sorted == 1:
        is_sorted = True
    else:
        is_sorted = False

    if str(return_inverse) == "true" or return_inverse == 1:
        is_return_inverse = True
    else:
        is_return_inverse = False

    if str(return_counts) == "true" or return_counts == 1:
        is_return_counts = True
    else:
        is_return_counts = False

    m = torch.unique(
        x,
        sorted=is_sorted,
        return_inverse=is_return_inverse,
        return_counts=is_return_counts,
        dim=None,
    )

    if is_return_inverse == False and is_return_counts == False:
        out_size = m.shape[0]
        y[0:out_size] = m
        with open(reuse_lists[0], "wb") as f:
            save_tensor(f, y, values_dtype)
        with open(reuse_lists[1], "wb") as f:
            save_tensor(f, inverse, inverse_dtype)
        with open(reuse_lists[2], "wb") as f:
            save_tensor(f, counts, counts_dtype)
        with open(output_lists[0], "wb") as f:
            save_tensor(f, torch.tensor(out_size), out_dtype)
    if is_return_inverse or is_return_counts:
        out_num = len(m)
        out_size = m[0].shape[0]
        y[0:out_size] = m[0]
        with open(reuse_lists[0], "wb") as f:
            save_tensor(f, y, values_dtype)
        with open(output_lists[0], "wb") as f:
            save_tensor(f, torch.tensor(out_size), out_dtype)
        if out_num == 2:
            if is_return_inverse:
                with open(reuse_lists[1], "wb") as f:
                    save_tensor(f, m[1], inverse_dtype)
                with open(reuse_lists[2], "wb") as f:
                    save_tensor(f, counts, counts_dtype)
            else:
                with open(reuse_lists[1], "wb") as f:
                    save_tensor(f, inverse, inverse_dtype)
                with open(reuse_lists[2], "wb") as f:
                    save_tensor(f, m[1], counts_dtype)
        if out_num == 3:
            with open(reuse_lists[1], "wb") as f:
                save_tensor(f, m[1], inverse_dtype)
            with open(reuse_lists[2], "wb") as f:
                save_tensor(f, m[2], counts_dtype)


def parse_params(filename):
    with open(filename, "r") as f:
        params = json.load(f)
    return params


if __name__ == "__main__":
    params = parse_params(sys.argv[1])
    device = sys.argv[2]
    test_unique2(
        params["param_path"],
        params["input_lists"],
        params["reuse_lists"],
        params["output_lists"],
        device,
    )
