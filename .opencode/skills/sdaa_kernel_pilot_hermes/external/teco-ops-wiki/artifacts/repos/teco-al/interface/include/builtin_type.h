// BSD 3- Clause License Copyright (c) 2024, Tecorigin Co., Ltd. All rights
// reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
// Neither the name of the copyright holder nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY,OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)  ARISING IN ANY
// WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
// OF SUCH DAMAGE.

#ifndef INTERFACE_INCLUDE_BUILTIN_TYPE_H_
#define INTERFACE_INCLUDE_BUILTIN_TYPE_H_

#include "interface/include/tecoal.h"
#include "interface/common/tensor.h"

struct tecoalContext {
    int spa_num;
    int spe_num;
    int spm_size;
    sdaaStream_t stream;
};

struct tecoalConvolutionStruct {
    int pad_h;       // zero-padding height
    int pad_w;       // zero-padding width
    int u;           // vertical filter stride
    int v;           // horizontal filter stride
    int dilation_h;  // filter dilation in the vertical dimension
    int dilation_w;  // filter dilation in the horizontal dimension
    int *padA;
    int *filterStrideA;
    int *dilationA;
    tecoalConvolutionMode_t mode;
    tecoalDataType_t dataType;
    tecoalMathType_t mathType;
};

struct tecoalActivationStruct {
    tecoalActivationMode_t mode;
    tecoalNanPropagation_t reluNanOpt;
    double coef;
    void *tab_A, *tab_B;
};

#endif  // INTERFACE_INCLUDE_BUILTIN_TYPE_H_
