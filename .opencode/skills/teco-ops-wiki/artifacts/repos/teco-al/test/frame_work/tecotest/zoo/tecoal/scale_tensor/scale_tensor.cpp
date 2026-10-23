// MIT License
//
// Copyright (c) 2024, Tecorigin Co., Ltd.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#include <stdio.h>
#include <tecoal.h>
#include <iostream>
#include <string>
#include "zoo/tecoal/convert.h"
#include "zoo/tecoal/scale_tensor/scale_tensor.h"
namespace optest {

void ScaleTensorExecutor::paramCheck() {
    if (parser_->inputs().size() != 1) {
        ALLOG(ERROR) << "input num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }

    if (parser_->outputs().size() != 0) {
        ALLOG(ERROR) << "output num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }
}

void ScaleTensorExecutor::paramParse() {
    auto scale_tensor_param = parser_->getProtoNode()->tecoal_param().scale_tensor_param();
    alpha_ = scale_tensor_param.alpha();
    dtype = parser_->getProtoNode()->input(0).dtype();
    algo_ = convert::toTecoalAlgo(scale_tensor_param.algo());
}

void ScaleTensorExecutor::paramGeneration() {
    yDesc_ = getInputDesc<tecoalTensorDescriptor_t>(0);
    // bool flag = input_desc_[0].dimA== nullptr;
    // printf("%d \n", flag);
    y_ = dev_input[0];
}

void ScaleTensorExecutor::compute() {
    if (dtype == testpt::DTYPE_FLOAT || dtype == testpt::DTYPE_HALF) {
        checktecoal(tecoalScaleTensor(handle_, yDesc_, y_, &alpha_, algo_));
    } else {
        int64_t alpha_i = (int64_t)alpha_;
        checktecoal(tecoalScaleTensor(handle_, yDesc_, y_, &alpha_i, algo_));
    }
}

int64_t ScaleTensorExecutor::getTheoryOps() {
    int64_t theory_ops = parser_->input(0)->shape_count;
    return theory_ops;
}

int64_t ScaleTensorExecutor::getTheoryIoSize() { return getIoSizeWithReused(); }

void ScaleTensorExecutor::cpuCompute() { pythonComputeCPU("cpu"); }

void ScaleTensorExecutor::gpuCompute() { pythonComputeGPU("cuda"); }

}  // namespace optest
