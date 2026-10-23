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
#include "ual/args/masked_select_args.h"
#include "interface/common/marco.h"
#include "ual/ops/masked_select/masked_select.hpp"

using tecoal::ual::ops::MaskedSelectOp;
using tecoal::ual::args::MaskedSelectArgs;
using tecoal::ual::args::MaskedSelectPatchArgs;
using tecoal::Convert;

#define MAX(a, b) ((a) > (b) ? (a) : (b))

tecoalStatus_t TECOALWINAPI tecoalMaskedSelect(
    tecoalHandle_t handle, const tecoalTensorDescriptor_t inputDesc, const void *input,
    const tecoalTensorDescriptor_t maskDesc, const void *mask,
    const tecoalTensorDescriptor_t outDesc, void *out, void *selectCount, tecoalAlgo_t algo) {
    // mask broadcasts broadcast_flag 0x1 with a value of 1<<1 to input
    // input broadcasts broadcast_flag 0x2 to mask with a value of 1<<2
    // The mask and input bidirectional broadcast broadcast_flag have a value of 0x3
    int broadcast_flag = 0;
    MaskedSelectArgs arg;
    arg.spe_num = handle->spe_num;

    // The input will ensure that the nbDims of the mask input output will be the same, and the
    // insufficient will be supplemented by 1
    memset(arg.x_dim, 0, 8 * sizeof(int));
    memset(arg.mask_dim, 0, 8 * sizeof(int));
    memset(arg.broadcast_dim, 0, 8 * sizeof(int));
    memcpy(arg.x_dim, inputDesc->dimA, inputDesc->nbDims * sizeof(int));
    memcpy(arg.mask_dim, maskDesc->dimA, maskDesc->nbDims * sizeof(int));
    arg.expand_dims = inputDesc->nbDims;

    int input_len = 1;
    int mask_len = 1;
    int max_len = 1;
    for (int i = 0; i < arg.expand_dims; i++) {
        if (arg.x_dim[i] != arg.mask_dim[i] && arg.x_dim[i] != 1 && arg.mask_dim[i] != 1) {
            WARNING("The dims of x and the dims of mask do not meet the broadcast rules\n");
            return TECOAL_STATUS_BAD_PARAM;
        }
        int max = MAX(inputDesc->dimA[i], maskDesc->dimA[i]);
        input_len *= inputDesc->dimA[i];
        mask_len *= maskDesc->dimA[i];
        arg.broadcast_dim[i] = max;
        max_len *= max;
    }

    if (input_len < max_len) {
        broadcast_flag |= 0x2;  // Input broadcasts to mask
    }

    if (mask_len < max_len) {
        broadcast_flag |= 0x1;  // mask broadcasts to input
    }

    arg.input = input;
    arg.mask = mask;
    arg.output = out;
    arg.input_len = input_len;
    arg.mask_len = mask_len;
    arg.selectcount = (void *)selectCount;

    MaskedSelectPatchArgs arg_patch;
    arg_patch.args = &arg;
    arg_patch.broadcast_flag = broadcast_flag;
    arg_patch.x_type = Convert::toUALDataType(inputDesc->dataType);
    arg_patch.mask_type = Convert::toUALDataType(maskDesc->dataType);
    arg_patch.algo = Convert::toUalAlgoType(algo);

    RUN_OP(MaskedSelectOp, arg, arg_patch, handle);
    return TECOAL_STATUS_SUCCESS;
}
