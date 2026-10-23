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

#ifndef ZOO_TECOAL_UNIQUE_UNIQUE_H_  // NOLINT
#define ZOO_TECOAL_UNIQUE_UNIQUE_H_

#include <tecoal.h>
#include "zoo/tecoal/executor.h"

namespace optest {

class UniqueExecutor : public TecoalExecutor {
 public:
    UniqueExecutor() {}
    ~UniqueExecutor() {}

    void paramCheck();
    void paramParse();
    void paramGeneration();
    void compute();
    void cpuCompute();
    void gpuCompute();
    int64_t getTheoryOps() override;
    int64_t getTheoryIoSize() override;

 private:
    bool sorted_;
    bool return_inverse_;
    bool return_counts_;
    tecoalTensorDescriptor_t xDesc_;
    void *x_;
    tecoalTensorDescriptor_t yDesc_;
    void *y_;
    tecoalTensorDescriptor_t inverseDesc_;
    void *inverse_;
    tecoalTensorDescriptor_t countsDesc_;
    void *counts_;
    void *out_size_;
    tecoalUniqueMode_t mode_;
    tecoalAlgo_t algo_;
    int axis_;
};
};  // namespace optest

#endif  // ZOO_TECOAL_UNIQUE_UNIQUE_H_  // NOLINT