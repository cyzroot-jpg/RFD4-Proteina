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
#include "ual/args/scale_tensor_args.h"
#include "interface/common/marco.h"
#include "ual/ops/scale_tensor/scale_tensor.hpp"

using tecoal::ual::ops::ScaleTensorOp;
using tecoal::ual::args::ScaleTensorArgs;
using tecoal::ual::args::ScaleTensorPatchArgs;
using tecoal::Convert;

tecoalStatus_t TECOALWINAPI tecoalScaleTensor(tecoalHandle_t handle,
                                              const tecoalTensorDescriptor_t yDesc, void *y,
                                              const void *alpha, tecoalAlgo_t algo) {
    // init params
    ScaleTensorArgs arg;
    arg.spe_num = handle->spe_num;
    arg.x = *reinterpret_cast<const float *>(alpha);
    arg.data_num = 1;
    arg.spa_num = 0;
    arg.y = y;
    int data_num = 1;
    for (size_t i = 0; i < yDesc->nbDims; ++i) {
        data_num *= yDesc->dimA[i];
    }
    arg.data_num = data_num;
    if (yDesc->dataType == TECOAL_DATA_FLOAT)
        arg.x = *reinterpret_cast<const float *>(alpha);
    else
        return TECOAL_STATUS_NOT_SUPPORTED;

    ScaleTensorPatchArgs patch_arg;
    patch_arg.starg = &arg;
    patch_arg.data_type = Convert::toUALDataType(yDesc->dataType);
    patch_arg.algo = Convert::toUalAlgoType(algo);

    RUN_OP(ScaleTensorOp, arg, patch_arg, handle);
    return TECOAL_STATUS_SUCCESS;
}
