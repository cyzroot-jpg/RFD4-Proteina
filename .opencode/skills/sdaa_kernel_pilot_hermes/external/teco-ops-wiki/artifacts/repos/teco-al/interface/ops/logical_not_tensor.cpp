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
#include "ual/args/logical_not_tensor_args.h"
#include "interface/common/marco.h"
#include "ual/ops/logical_not_tensor/logical_not_tensor.hpp"

using tecoal::ual::ops::LogicalNotTensorOp;
using tecoal::ual::args::LogicalNotTensorArgs;
using tecoal::ual::args::LogicalNotTensorPatchArgs;
using tecoal::Convert;

tecoalStatus_t TECOALWINAPI tecoalLogicalNotTensor(tecoalHandle_t handle,
                                                   const tecoalTensorDescriptor_t aDesc,
                                                   const void *A,
                                                   const tecoalTensorDescriptor_t cDesc, void *C,
                                                   tecoalAlgo_t algo) {
    LogicalNotTensorArgs ntarg;
    ntarg.spe_num = handle->spe_num;
    ntarg.A_num = aDesc->n * aDesc->h * aDesc->w * aDesc->c;
    ntarg.A = A;
    ntarg.C = C;

    LogicalNotTensorPatchArgs ntarg_patch;
    ntarg_patch.ntarg = &ntarg;
    ntarg_patch.data_type = Convert::toUALDataType(aDesc->dataType);
    ntarg_patch.algo = Convert::toUalAlgoType(algo);

    RUN_OP(LogicalNotTensorOp, ntarg, ntarg_patch, handle);
    return TECOAL_STATUS_SUCCESS;
}
