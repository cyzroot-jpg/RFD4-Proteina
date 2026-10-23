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

#include "zoo/tecoal/unique/unique.h"
#include <stdio.h>
#include <tecoal.h>
#include <iostream>
#include <string>
#include "zoo/tecoal/convert.h"

namespace optest {

void UniqueExecutor::paramCheck() {
    if (parser_->inputs().size() != 4) {
        ALLOG(ERROR) << "input num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }

    if (parser_->outputs().size() != 1) {
        ALLOG(ERROR) << "output num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }
}

void UniqueExecutor::paramParse() {
    auto unique_param = parser_->getProtoNode()->tecoal_param().unique_param();
    sorted_ = unique_param.sorted();
    return_inverse_ = unique_param.return_inverse();
    return_counts_ = unique_param.return_counts();
    mode_ = convert::toTecoalUniqueMode(unique_param.mode());
    axis_ = unique_param.axis();
    algo_ = convert::toTecoalAlgo(unique_param.algo());
}

void UniqueExecutor::paramGeneration() {
    xDesc_ = getInputDesc<tecoalTensorDescriptor_t>(0);
    x_ = dev_input[0];
    yDesc_ = getInputDesc<tecoalTensorDescriptor_t>(1);
    y_ = dev_input[1];
    inverseDesc_ = getInputDesc<tecoalTensorDescriptor_t>(2);
    inverse_ = dev_input[2];
    countsDesc_ = getInputDesc<tecoalTensorDescriptor_t>(3);
    counts_ = dev_input[3];
    out_size_ = dev_output[0];
}

void UniqueExecutor::compute() {
    checktecoal(tecoalUnique(handle_, mode_, axis_, sorted_, return_inverse_, return_counts_,
                             xDesc_, x_, yDesc_, y_, inverseDesc_, inverse_, countsDesc_, counts_,
                             out_size_, algo_));
}

int64_t UniqueExecutor::getTheoryOps() {
    int64_t theory_ops = parser_->input(0)->shape_count;
    return theory_ops;
}

int64_t UniqueExecutor::getTheoryIoSize() { return getIoSize(); }

void UniqueExecutor::cpuCompute() { pythonComputeCPU("cpu"); }

void UniqueExecutor::gpuCompute() { pythonComputeGPU("cuda"); }

}  // namespace optest
