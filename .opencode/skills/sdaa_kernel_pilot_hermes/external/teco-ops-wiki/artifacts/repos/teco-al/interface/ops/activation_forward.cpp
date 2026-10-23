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
#include "ual/args/activation_forward_args.h"
#include "interface/common/marco.h"
#include "ual/ops/activation_forward/activation_forward.hpp"

using tecoal::ual::ops::ActivationFwdOp;
using tecoal::ual::args::ActivationFwdArgs;
using tecoal::ual::args::ActivationFwdPatchArgs;
using tecoal::Convert;

tecoalStatus_t TECOALWINAPI
tecoalCreateActivationDescriptor(tecoalActivationDescriptor_t *activationDesc) {
    *activationDesc =
        (tecoalActivationDescriptor_t)malloc(sizeof(tecoalActivationStruct));
    (*activationDesc)->tab_A = NULL;
    (*activationDesc)->tab_B = NULL;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t TECOALWINAPI tecoalSetActivationDescriptor(
    tecoalActivationDescriptor_t activationDesc, tecoalActivationMode_t mode,
    tecoalNanPropagation_t reluNanOpt, double coef) {
    if (activationDesc == NULL) {
        WARNING("activationDesc is NULL\n");
        return TECOAL_STATUS_BAD_PARAM;
    }

    activationDesc->mode = mode;
    activationDesc->reluNanOpt = reluNanOpt;
    activationDesc->coef = coef;

    activationDesc->tab_A = NULL;
    activationDesc->tab_B = NULL;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t TECOALWINAPI tecoalGetActivationDescriptor(
    const tecoalActivationDescriptor_t activationDesc, tecoalActivationMode_t *mode,
    tecoalNanPropagation_t *reluNanOpt, double *coef) {
    if (activationDesc == NULL) {
        WARNING("activationDesc is NULL\n");
        return TECOAL_STATUS_BAD_PARAM;
    }

    if (mode != NULL) *mode = activationDesc->mode;
    if (reluNanOpt != NULL) *reluNanOpt = activationDesc->reluNanOpt;
    if (coef != NULL) *coef = activationDesc->coef;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t TECOALWINAPI
tecoalDestroyActivationDescriptor(tecoalActivationDescriptor_t activationDesc) {
    if (activationDesc == NULL) {
        WARNING("activationDesc is NULL\n");
        return TECOAL_STATUS_BAD_PARAM;
    }
    if (activationDesc != NULL) {
        free(activationDesc);
        // delete activationDesc;
    }
    return TECOAL_STATUS_SUCCESS;
}


tecoalStatus_t TECOALWINAPI tecoalActivationForward(
    tecoalHandle_t handle, tecoalActivationDescriptor_t activationDesc, const void *alpha,
    const tecoalTensorDescriptor_t xDesc, const void *x, const void *beta,
    const tecoalTensorDescriptor_t yDesc, void *y, tecoalAlgo_t algo) {
    // define ops args
    ActivationFwdArgs arg;
    arg.spe_num = handle->spe_num;
    arg.data_num = xDesc->n * xDesc->c * xDesc->h * xDesc->w;
    arg.mode = (int)(activationDesc->mode);
    arg.coef = (double)(activationDesc->coef);
    arg.alpha = *reinterpret_cast<const float *>(alpha);
    arg.beta = *reinterpret_cast<const float *>(beta);
    arg.x = x;
    arg.y = y;

    // define dispatcher args(can reuse ops args)
    ActivationFwdPatchArgs patch_arg;
    patch_arg.afarg = &arg;
    patch_arg.tab_A = activationDesc->tab_A;
    patch_arg.tab_B = activationDesc->tab_B;
    patch_arg.data_type = Convert::toUALDataType(xDesc->dataType);
    patch_arg.algo = Convert::toUalAlgoType(algo);
    RUN_OP(ActivationFwdOp, arg, patch_arg, handle);
    return TECOAL_STATUS_SUCCESS;
}
