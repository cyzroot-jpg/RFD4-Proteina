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

#ifndef TECO_INTERFACE_COMMON_TENSOR_H_
#define TECO_INTERFACE_COMMON_TENSOR_H_

#include "interface/include/tecoops.h"
#include "ual/com/log.h"

typedef struct tecoopsTensorStruct tecoopsTensorDescriptor;

struct tecoopsTensorStruct {
   public:
    // functions start
    tecoopsTensorStruct() : format(TECOOPS_TENSOR_NHWC), dataType(TECOOPS_DATA_FLOAT), nbDims(0) {}  // NOLINT
    ~tecoopsTensorStruct() {}

    tecoopsStatus_t check();

    tecoopsStatus_t getTensorDimN(int* dim_size);
    tecoopsStatus_t getTensorDimH(int* dim_size);
    tecoopsStatus_t getTensorDimW(int* dim_size);
    tecoopsStatus_t getTensorDimC(int* dim_size);
    tecoopsStatus_t getTensorStrideN(int* stride_size);
    tecoopsStatus_t getTensorStrideH(int* stride_size);
    tecoopsStatus_t getTensorStrideW(int* stride_size);
    tecoopsStatus_t getTensorStrideC(int* stride_size);

    tecoopsStatus_t setTensorDimN(int dim_size);
    tecoopsStatus_t setTensorDimH(int dim_size);
    tecoopsStatus_t setTensorDimW(int dim_size);
    tecoopsStatus_t setTensorDimC(int dim_size);
    tecoopsStatus_t setTensorStrideN(int stride_size);
    tecoopsStatus_t setTensorStrideH(int stride_size);
    tecoopsStatus_t setTensorStrideW(int stride_size);
    tecoopsStatus_t setTensorStrideC(int stride_size);

    tecoopsStatus_t getTensorNum(size_t* tensor_num);
    tecoopsStatus_t getTensorSizeInBytes(size_t* tensor_size);

    // member variables start
    tecoopsTensorFormat_t format = TECOOPS_TENSOR_NHWC;
    tecoopsDataType_t dataType = TECOOPS_DATA_FLOAT;
    int nbDims = 0;

    // if nbDims > TECOOPS_DIM_MAX, using expand dims and strides, user should malloc and free.  // NOLINT
    // else, using normal dims and strides, user don't need malloc and free.
    int normal_dims[TECOOPS_DIM_MAX] = {-1};
    int normal_strides[TECOOPS_DIM_MAX] = {-1};

    int* expand_dims = nullptr;
    int* expand_strides = nullptr;

    int* dimA = normal_dims;
    int* strideA = normal_strides;

    int n = 0;
    int c = 0;
    int h = 0;
    int w = 0;
    int nStride = 0;
    int cStride = 0;
    int hStride = 0;
    int wStride = 0;

   private:
};

#endif  // TECO_INTERFACE_COMMON_TENSOR_H_
