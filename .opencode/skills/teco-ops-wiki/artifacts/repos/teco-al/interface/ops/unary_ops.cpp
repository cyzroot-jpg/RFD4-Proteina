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
#include "ual/args/unary_ops_args.h"
#include "interface/common/marco.h"
#include "ual/ops/unary_ops/unary_ops.hpp"

using tecoal::ual::ops::UnaryOpsOp;
using tecoal::ual::args::UnaryOpsArgs;
using tecoal::ual::args::UnaryOpsPatchArgs;
using tecoal::Convert;

tecoalStatus_t TECOALWINAPI tecoalUnaryOps(tecoalHandle_t handle, tecoalUnaryOpsMode_t mode,
                                           const void *alpha, const tecoalTensorDescriptor_t xDesc,
                                           const void *x, const tecoalTensorDescriptor_t yDesc,
                                           void *y, tecoalAlgo_t algo) {
    int count = xDesc->dimA[0];
    for (int i = 1; i < xDesc->nbDims; i++) {
        count *= xDesc->dimA[i];
    }

    UnaryOpsArgs arg;
    arg.mode = mode;
    arg.x = x;
    arg.y = y;
    arg.n = count;
    arg.spe_num = handle->spe_num;
    arg.alpha_f32 = ((float *)alpha)[0];

    UnaryOpsPatchArgs arg_patch;
    arg_patch.arg = &arg;
    arg_patch.x_data_type = Convert::toUALDataType(xDesc->dataType);
    arg_patch.y_data_type = Convert::toUALDataType(yDesc->dataType);
    arg_patch.mode = Convert::toUALUnaryOpsMode(mode);
    arg_patch.algo = Convert::toUalAlgoType(algo);

    RUN_OP(UnaryOpsOp, arg, arg_patch, handle);
    return TECOAL_STATUS_SUCCESS;
}
