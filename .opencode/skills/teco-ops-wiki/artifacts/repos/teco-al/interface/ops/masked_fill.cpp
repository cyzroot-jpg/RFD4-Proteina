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

#include "interface/include/tecoal.h"
#include "interface/include/builtin_type.h"
#include "ual/args/masked_fill_args.h"
#include "interface/common/marco.h"
#include "ual/ops/masked_fill/masked_fill.hpp"

using tecoal::ual::ops::MaskedFillOp;
using tecoal::ual::args::MaskedFillArgs;
using tecoal::ual::args::MaskedFillPatchArgs;
using tecoal::Convert;

#define SWAP_TYPE(type, x, y) \
    do {                      \
        type t = x;           \
        x = y;                \
        y = t;                \
    } while (0)

static inline void REV(int *a, int ln) {
    int cnt = ln >> 1;
    for (int i = 0; i < cnt; ++i) {
        SWAP_TYPE(int, a[i], a[ln - 1 - i]);
    }
}

tecoalStatus_t TECOALWINAPI
tecoalMaskedFill(tecoalHandle_t handle, const float value, const tecoalTensorDescriptor_t inputDesc,
                 const void *input, const tecoalTensorDescriptor_t maskDesc, const void *mask,
                 const tecoalTensorDescriptor_t outputDesc, void *output, tecoalAlgo_t algo) {
    // Initialize and fill the structure with tensor operation arguments
    MaskedFillArgs arg;
    arg.spe_num = handle->spe_num;
    arg.value = value;
    arg.input = input;
    arg.mask = mask;
    arg.output = output;

    arg.dimLen = inputDesc->nbDims;

    int *h_dim_A = inputDesc->dimA;
    int *h_dim_B = maskDesc->dimA;
    int *h_dim_C = outputDesc->dimA;
    int dim_ln_A = inputDesc->nbDims;
    int dim_ln_B = maskDesc->nbDims;
    int dim_ln_C = outputDesc->nbDims;
    memcpy(arg.dimInput, h_dim_A, dim_ln_A * sizeof(int));
    memcpy(arg.dimMask, h_dim_B, dim_ln_B * sizeof(int));
    memcpy(arg.dimOutput, h_dim_C, dim_ln_C * sizeof(int));

    int off = dim_ln_C - dim_ln_B;
    for (int i = dim_ln_B - 1; i >= 0; i--) {
        int t_b = h_dim_B[i];
        int t_c = h_dim_C[i + off];
    }

    REV(arg.dimInput, dim_ln_A);
    REV(arg.dimMask, dim_ln_B);
    REV(arg.dimOutput, dim_ln_C);
    for (int i = dim_ln_B; i < dim_ln_C; ++i) {
        arg.dimMask[i] = 1;
    }

    MaskedFillPatchArgs patch_arg;
    patch_arg.args = &arg;
    patch_arg.data_type = Convert::toUALDataType(inputDesc->dataType);
    patch_arg.algo = Convert::toUalAlgoType(algo);

    RUN_OP(MaskedFillOp, arg, patch_arg, handle);
    return TECOAL_STATUS_SUCCESS;
}
