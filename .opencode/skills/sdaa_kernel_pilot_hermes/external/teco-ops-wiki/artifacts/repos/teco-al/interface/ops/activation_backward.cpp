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
#include "ual/args/activation_backward_args.h"
#include "interface/common/marco.h"
#include "ual/ops/activation_backward/activation_backward.hpp"

using tecoal::ual::ops::ActivationBwdOp;
using tecoal::ual::args::ActivationBwdArgs;
using tecoal::ual::args::ActivationBwdPatchArgs;
using tecoal::Convert;

tecoalStatus_t TECOALWINAPI tecoalActivationBackward(
    tecoalHandle_t handle, tecoalActivationDescriptor_t activationDesc, const void *alpha,
    const tecoalTensorDescriptor_t yDesc, const void *y, const tecoalTensorDescriptor_t dyDesc,
    const void *dy, const tecoalTensorDescriptor_t xDesc, const void *x, const void *beta,
    const tecoalTensorDescriptor_t dxDesc, void *dx, tecoalAlgo_t algo) {
    ActivationBwdArgs abarg;
    abarg.spe_num = handle->spe_num;
    abarg.data_num = xDesc->n * xDesc->h * xDesc->w * xDesc->c;
    abarg.mode = activationDesc->mode;
    abarg.COEF = activationDesc->coef;
    abarg.x = x;
    abarg.y = y;
    abarg.dy = dy;
    abarg.dx = dx;
    abarg.alpha = ((float *)alpha)[0];
    abarg.beta = ((float *)beta)[0];

    ActivationBwdPatchArgs abarg_patch;
    abarg_patch.abarg = &abarg;
    abarg_patch.data_type = Convert::toUALDataType(xDesc->dataType);
    abarg_patch.algo = Convert::toUalAlgoType(algo);

    RUN_OP(ActivationBwdOp, abarg, abarg_patch, handle);
    return TECOAL_STATUS_SUCCESS;
}
