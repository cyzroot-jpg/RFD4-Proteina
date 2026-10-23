// BSD 3-Clause License
//
// Copyright (c) 2024, Tecorigin Co., Ltd.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#include <stdio.h>
#include <iostream>
#include <string>
#include "zoo/teco/convert.h"
#include "common/time.hpp"
#include "zoo/teco/reduce_variance/reduce_variance.h"


namespace optest {

void ReduceVarianceExecutor::paramCheck() {
    if (parser_->inputs().size() != 1) {
        ALLOG(ERROR) << "input num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));  // NOLINT
    }

    if (parser_->outputs().size() != 1) {
        ALLOG(ERROR) << "output num is wrong.";
        throw std::invalid_argument(std::string(__FILE__) + ":" + std::to_string(__LINE__));  // NOLINT
    }
}

void ReduceVarianceExecutor::paramParse() {
    auto reduce_variance_param = parser_->getProtoNode()->tecokernel_param().reduce_variance_param();
    axis_ = reduce_variance_param.axis();
    correction_ = reduce_variance_param.correction();
}

void ReduceVarianceExecutor::paramGeneration() {
    xDesc_ = getInputDesc<tecoopsTensorDescriptor_t>(0);
    x_ = dev_input[0];
    yDesc_ = getOutputDesc<tecoopsTensorDescriptor_t>(0);
    y_ = dev_output[0];
}

void ReduceVarianceExecutor::compute() {
    checkTECOOPS(tecoopsReduceVariance(handle_, axis_, correction_, xDesc_, x_, yDesc_, y_));
}

int64_t ReduceVarianceExecutor::getTheoryOps() {
    int64_t theory_ops = parser_->input(0)->shape_count * 3;
    return theory_ops;
}

int64_t ReduceVarianceExecutor::getTheoryIoSize() { return getIoSize(); }

void ReduceVarianceExecutor::cpuCompute() { pythonComputeCPU("cpu"); }

void ReduceVarianceExecutor::gpuCompute() { /*pythonComputeGPU("cuda"); */ }

}  // namespace optest
