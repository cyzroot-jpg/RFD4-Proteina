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

#ifndef ZOO_TECOAL_SCATTEROUT_SCATTEROUT_H_  // NOLINT
#define ZOO_TECOAL_SCATTEROUT_SCATTEROUT_H_

#include <tecoal.h>
#include "zoo/tecoal/executor.h"

namespace optest {

class ScatterOutExecutor : public TecoalExecutor {
 public:
    ScatterOutExecutor() {}
    ~ScatterOutExecutor() {}

    void paramCheck();
    void paramParse();
    void paramGeneration();
    void compute();
    void cpuCompute();
    void gpuCompute();
    int64_t getTheoryIoSize() override;
    int64_t getTheoryOps() override;

 private:
    unsigned int target_dim_;
    float alpha_;
    tecoalScatterOutReductionMode_t reduce_;
    tecoalScatterOutInputType_t input_type_;
    tecoalTensorDescriptor_t inputDesc_;
    void *input_;
    tecoalTensorDescriptor_t indexDesc_;
    void *index_;
    tecoalTensorDescriptor_t outputDesc_;
    void *output_;
    tecoalAlgo_t algo_;
};
};  // namespace optest

#endif  // ZOO_TECOAL_SCATTEROUT_SCATTEROUT_H_ //NOLINT
