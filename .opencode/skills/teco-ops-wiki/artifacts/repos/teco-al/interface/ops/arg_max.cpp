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
#include "ual/args/arg_max_args.h"
#include "interface/common/marco.h"
#include "ual/ops/arg_max/arg_max.hpp"

using tecoal::ual::ops::ArgMaxOp;
using tecoal::ual::args::ArgMaxArgs;
using tecoal::ual::args::ArgMaxPatchArgs;
using tecoal::Convert;

tecoalStatus_t TECOALWINAPI tecoalArgmax(tecoalHandle_t handle, const int axis,
                                         const tecoalTensorDescriptor_t xDesc, const void *x,
                                         const tecoalTensorDescriptor_t yDesc, void *y,
                                         tecoalAlgo_t algo) {
    // Initialize and fill the structure with tensor operation arguments
    ArgMaxArgs arg;

    arg.spa_num = handle->spa_num;
    arg.spe_num = handle->spe_num;
    arg.x = x;
    arg.y = y;
    int dims = xDesc->nbDims;
    int high_num = 1;
    int axis_num = xDesc->dimA[axis];
    int low_num = 1;
    for (int i = 0; i < axis; i++) {
        high_num *= xDesc->dimA[i];
    }
    for (int i = axis + 1; i < xDesc->nbDims; i++) {
        low_num *= xDesc->dimA[i];
    }
    arg.high_num = high_num;
    arg.axis_num = axis_num;
    arg.low_num = low_num;
    arg.axis = axis;
    arg.dims = dims;
    arg.dtype_size = Convert::toDescDataTypeSize(xDesc->dataType);

    int pattern_size = 1 << 10;
    int num, low_ln_blk;
    int nBLK = 1 << 10;
    int low_ln = low_num * axis_num;
    if (low_ln > nBLK) {
        low_ln_blk = nBLK;
        num = high_num >= 16 ? 16 : high_num;
    } else {
        low_ln_blk = low_ln;
        num = high_num * low_ln > 2 * nBLK ?
                  (2 * nBLK / low_ln > 16 ? (2 * nBLK / low_ln) / 16 * 16 : 16) :
                  high_num;
    }
    arg.low_ln_blk = low_ln_blk;
    arg.num = num;
    // define dispatcher args(can reuse ops args)
    ArgMaxPatchArgs patch_arg;
    patch_arg.amarg = &arg;
    patch_arg.algo = Convert::toUalAlgoType(algo);
    patch_arg.data_type = Convert::toUALDataType(xDesc->dataType);

    RUN_OP(ArgMaxOp, arg, patch_arg, handle);
    return TECOAL_STATUS_SUCCESS;
}
