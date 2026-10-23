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

#include "zoo/tecoal/scatter_out/scatter_out.h"
#include <stdio.h>
#include <tecoal.h>
#include <iostream>
#include <string>
#include "zoo/tecoal/convert.h"

namespace optest {

void ScatterOutExecutor::paramCheck() {
    if (parser_->inputs().size() != 3) {
        ALLOG(ERROR) << "input num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }

    if (parser_->outputs().size() != 0) {
        ALLOG(ERROR) << "output num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));
    }
}

void ScatterOutExecutor::paramParse() {
    auto scatterout_param = parser_->getProtoNode()->tecoal_param().scatter_out_param();
    target_dim_ = scatterout_param.target_dim();
    alpha_ = scatterout_param.alpha();
    reduce_ = convert::toTecoalScatterOutReductionMode(scatterout_param.scatter_out_reduce_mode());
    input_type_ = convert::toTecoalScatterOutInputType(scatterout_param.scatter_out_input_type());
    algo_ = convert::toTecoalAlgo(scatterout_param.algo());
}

void ScatterOutExecutor::paramGeneration() {
    inputDesc_ = getInputDesc<tecoalTensorDescriptor_t>(0);
    input_ = dev_input[0];
    indexDesc_ = getInputDesc<tecoalTensorDescriptor_t>(1);
    index_ = dev_input[1];
    outputDesc_ = getInputDesc<tecoalTensorDescriptor_t>(2);
    output_ = dev_input[2];
}

void ScatterOutExecutor::compute() {
    checktecoal(tecoalScatterOut(handle_, target_dim_, alpha_, input_type_, reduce_, inputDesc_,
                                 input_, indexDesc_, index_, outputDesc_, output_, algo_));
}

int64_t ScatterOutExecutor::getTheoryOps() {
    int64_t theory_ops = parser_->input(0)->shape_count;
    return theory_ops;
}

int64_t ScatterOutExecutor::getTheoryIoSize() {
    size_t total_size = 0;
    total_size += 2 * parser_->input(2)->size_in_bytes;
    total_size += parser_->input(1)->size_in_bytes;
    total_size += parser_->input(0)->size_in_bytes;
    return total_size;
}

void ScatterOutExecutor::cpuCompute() { pythonComputeCPU("cpu"); }

void ScatterOutExecutor::gpuCompute() { pythonComputeGPU("cuda"); }

}  // namespace optest
