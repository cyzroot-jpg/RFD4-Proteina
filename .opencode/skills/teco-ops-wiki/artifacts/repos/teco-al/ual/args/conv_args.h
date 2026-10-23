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

#ifndef UAL_ARGS_CONV_ARGS_H_
#define UAL_ARGS_CONV_ARGS_H_

#include "ual/com/def.h"

using namespace tecoal::ual::common;

namespace tecoal {
namespace ual {
namespace args {
typedef struct ConvFwdArgs {
    int N;
    int C;  // must % 32 == 0
    int H;
    int W;
    int M;  // must % 32 == 0
    int R;
    int S;
    int E;
    int F;
    int pad_h;
    int pad_w;
    int stride_h;
    int stride_w;
    int dilation_h;
    int dilation_w;
    const void *x;  // must 4B align
    const void *w;  // must 4B align
    void *y;        // must 4B align
    int spa_num;
    int spe_num;
    float alpha;
    float beta;
    void *workSpace;
    size_t workSpaceSize;
    UALDataType out_data_type;
} ConvFwdArgs;

typedef struct ConvFwdPatchArgs {
    ConvFwdArgs *convf;
    UALDataType x_data_type;
    UALDataType w_data_type;
    UALDataType y_data_type;
    UALAlgoType algo;
} ConvFwdPatchArgs;
}  // namespace args
}  // namespace ual
}  // namespace tecoal

#endif  // UAL_ARGS_CONV_ARGS_H_
