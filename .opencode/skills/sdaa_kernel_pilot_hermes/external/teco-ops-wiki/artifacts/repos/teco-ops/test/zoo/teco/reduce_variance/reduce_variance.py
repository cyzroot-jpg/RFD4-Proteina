# BSD 3-Clause License
#
# Copyright (c) 2024, Tecorigin Co., Ltd.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# encoding:utf-8
'''
Create on
@author:
Describe:
'''

import os
import sys
import json
import torch
import numpy as np
sys.path.append("../zoo/teco/")
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

def test_reduce_variance(param_path, input_lists, reuse_lists, output_lists, device):
    if not check_inputs(param_path, input_lists, reuse_lists, output_lists):
        return

    if device == "cuda":
        if torch.cuda.is_available():
            used_device = torch.device("cuda:0")
        else:
            print("not found cuda device")
            return

    params = read_prototxt(param_path)
    input_params = params["input"]
    output_params = params["output"]
    reduce_variance_params = params["tecokernel_param"]["reduce_variance_param"]
    axis = int(reduce_variance_params["axis"])
    correction = int(reduce_variance_params["correction"])
    x_dtype = input_params["dtype"]
    y_dtype = output_params["dtype"]

    input_params = params["input"]
    x = to_tensor(input_lists[0], input_params, device=device)
    output = torch.var(x, dim=axis, correction=correction)

    with open(output_lists[0], "wb") as f:
        save_tensor(f, output, y_dtype)

def parse_params(filename):
    with open(filename, "r") as f:
        params = json.load(f)
    return params

if __name__ == "__main__":
    params = parse_params(sys.argv[1])
    device = sys.argv[2]
    test_reduce_variance(params["param_path"], params["input_lists"], params["reuse_lists"], params["output_lists"], device)