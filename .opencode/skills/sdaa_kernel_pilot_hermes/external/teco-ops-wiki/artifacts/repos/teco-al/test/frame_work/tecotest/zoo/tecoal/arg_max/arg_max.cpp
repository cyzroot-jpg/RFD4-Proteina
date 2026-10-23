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

#include "zoo/tecoal/arg_max/arg_max.h"
#include <stdio.h>
#include <tecoal.h>
#include <iostream>
#include <string>
#include "zoo/tecoal/convert.h"

namespace optest {

void ArgMaxExecutor::paramCheck() {
    if (parser_->inputs().size() != 1) {
        ALLOG(ERROR) << "input num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }

    if (parser_->outputs().size() != 1) {
        ALLOG(ERROR) << "output num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }
}

void ArgMaxExecutor::paramParse() {
    auto arg_max_param = parser_->getProtoNode()->tecoal_param().arg_max_param();
    axis_ = arg_max_param.axis();
    algo_ = convert::toTecoalAlgo(arg_max_param.algo());
}

void ArgMaxExecutor::paramGeneration() {
    xDesc_ = getInputDesc<tecoalTensorDescriptor_t>(0);
    x_ = dev_input[0];
    yDesc_ = getOutputDesc<tecoalTensorDescriptor_t>(0);
    y_ = dev_output[0];
}

void ArgMaxExecutor::compute() {
    checktecoal(tecoalArgmax(handle_, axis_, xDesc_, x_, yDesc_, y_, algo_));
}

int64_t ArgMaxExecutor::getTheoryOps() {
    int64_t theory_ops = parser_->input(0)->shape_count;
    return theory_ops;
}

int64_t ArgMaxExecutor::getTheoryIoSize() { return getIoSize(); }

void ArgMaxExecutor::cpuCompute() { pythonComputeCPU("cpu"); }

}  // namespace optest
