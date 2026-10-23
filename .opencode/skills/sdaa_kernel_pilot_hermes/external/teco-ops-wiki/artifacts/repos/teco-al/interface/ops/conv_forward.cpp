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

#include "interface/include/builtin_type.h"
#include "interface/common/check.h"
#include "interface/common/marco.h"
#include "ual/ops/conv_forward/conv_forward.hpp"

using tecoal::ual::args::ConvFwdArgs;
using tecoal::ual::args::ConvFwdPatchArgs;
using tecoal::ual::ops::ConvFwdOp;
using namespace tecoal;

static tecoalStatus_t getConvFwdArgs(tecoalHandle_t handle, const tecoalTensorDescriptor_t xDesc,
                                     const tecoalFilterDescriptor_t wDesc,
                                     const tecoalConvolutionDescriptor_t convDesc,
                                     const tecoalTensorDescriptor_t yDesc, ConvFwdArgs *arg,
                                     ConvFwdPatchArgs *args_patch) {
    arg->spa_num = handle->spa_num;
    arg->spe_num = handle->spe_num;
    arg->N = xDesc->n, arg->C = xDesc->c, arg->H = xDesc->h, arg->W = xDesc->w;
    arg->M = wDesc->m, arg->R = wDesc->r, arg->S = wDesc->s;
    arg->E = yDesc->h, arg->F = yDesc->w;
    arg->pad_h = convDesc->padA[0];
    arg->pad_w = convDesc->padA[1];
    arg->stride_h = convDesc->filterStrideA[0];
    arg->stride_w = convDesc->filterStrideA[1];
    arg->dilation_h = convDesc->dilationA[0];
    arg->dilation_w = convDesc->dilationA[1];
    arg->alpha = 1.0;
    arg->beta = 0.0;

    arg->out_data_type = Convert::toUALDataType(yDesc->dataType);

    arg->x = nullptr;
    arg->w = nullptr;
    arg->y = nullptr;

    arg->workSpace = nullptr;
    arg->workSpaceSize = 0;

    args_patch->convf = arg;
    args_patch->x_data_type = Convert::toUALDataType(xDesc->dataType);
    args_patch->w_data_type = Convert::toUALDataType(wDesc->dataType);
    args_patch->y_data_type = Convert::toUALDataType(yDesc->dataType);

    return TECOAL_STATUS_SUCCESS;
}

// Create an instance of convolution descriptor
tecoalStatus_t TECOALWINAPI
tecoalCreateConvolutionDescriptor(tecoalConvolutionDescriptor_t *convDesc) {
    *convDesc = (tecoalConvolutionDescriptor_t)malloc(sizeof(tecoalConvolutionStruct));
    (*convDesc)->padA = nullptr;
    (*convDesc)->filterStrideA = nullptr;
    (*convDesc)->dilationA = nullptr;
    (*convDesc)->mathType = TECOAL_TENSOR_ACC_MATH;
    return TECOAL_STATUS_SUCCESS;
}

// Destroy an instance of convolution descriptor
tecoalStatus_t TECOALWINAPI
tecoalDestroyConvolutionDescriptor(tecoalConvolutionDescriptor_t convDesc) {
    if (convDesc != NULL) {
        free(convDesc);
    }
    return TECOAL_STATUS_SUCCESS;
}

// Set the parameters for a 2D convolution operation in its descriptor.
tecoalStatus_t TECOALWINAPI tecoalSetConvolution2dDescriptor(
    tecoalConvolutionDescriptor_t convDesc, int pad_h,  // zero-padding height
    int pad_w,                                          // zero-padding width
    int u,                                              // vertical filter stride
    int v,                                              // horizontal filter stride
    int dilation_h,                                     // filter dilation in the vertical dimension
    int dilation_w,  // filter dilation in the horizontal dimension
    tecoalConvolutionMode_t mode, tecoalDataType_t dataType) {
    convDesc->pad_h = pad_h;
    convDesc->pad_w = pad_w;
    convDesc->u = u;
    convDesc->v = v;
    convDesc->dilation_h = dilation_h;
    convDesc->dilation_w = dilation_w;
    if (convDesc->padA != nullptr) {
        free(convDesc->padA);
    }
    convDesc->padA = (int *)malloc(sizeof(int) * 2);
    convDesc->padA[0] = pad_h;
    convDesc->padA[1] = pad_w;
    if (convDesc->filterStrideA != nullptr) {
        free(convDesc->filterStrideA);
    }
    convDesc->filterStrideA = (int *)malloc(sizeof(int) * 2);
    convDesc->filterStrideA[0] = u;
    convDesc->filterStrideA[1] = v;
    if (convDesc->dilationA != nullptr) {
        free(convDesc->dilationA);
    }
    convDesc->dilationA = (int *)malloc(sizeof(int) * 2);
    convDesc->dilationA[0] = dilation_h;
    convDesc->dilationA[1] = dilation_w;
    convDesc->mode = mode;
    convDesc->dataType = dataType;
    return TECOAL_STATUS_SUCCESS;
}

// Retrieve the parameters of a 2D convolution descriptor.
tecoalStatus_t TECOALWINAPI tecoalGetConvolution2dDescriptor(
    const tecoalConvolutionDescriptor_t convDesc, int *pad_h,  // zero-padding height
    int *pad_w,                                                // zero-padding width
    int *u,                                                    // vertical filter stride
    int *v,                                                    // horizontal filter stride
    int *dilation_h,  // filter dilation in the vertical dimension
    int *dilation_w,  // filter dilation in the horizontal dimension
    tecoalConvolutionMode_t *mode, tecoalDataType_t *dataType) {
    if (pad_h != NULL) *pad_h = convDesc->pad_h;
    if (pad_w != NULL) *pad_w = convDesc->pad_w;
    if (u != NULL) *u = convDesc->u;
    if (v != NULL) *v = convDesc->v;
    if (dilation_h != NULL) *dilation_h = convDesc->dilation_h;
    if (dilation_w != NULL) *dilation_w = convDesc->dilation_w;
    if (mode != NULL) *mode = convDesc->mode;
    if (dataType != NULL) *dataType = convDesc->dataType;
    return TECOAL_STATUS_SUCCESS;
}

// Calculate the size of the workspace needed for a forward convolution operation.
tecoalStatus_t TECOALWINAPI tecoalGetConvolutionForwardWorkspaceSize(
    tecoalHandle_t handle, const tecoalTensorDescriptor_t xDesc,
    const tecoalFilterDescriptor_t wDesc, const tecoalConvolutionDescriptor_t convDesc,
    const tecoalTensorDescriptor_t yDesc, tecoalAlgo_t algo, size_t *workSpaceSizeInBytes) {
    ConvFwdArgs arg;
    ConvFwdPatchArgs args_patch;
    checkTecoalStatus(getConvFwdArgs(handle, xDesc, wDesc, convDesc, yDesc, &arg, &args_patch));
    args_patch.algo = Convert::toUalAlgoType(algo);
    ConvFwdOp op{};
    Status status = op.getWorkspace(&args_patch, workSpaceSizeInBytes);
    checkUalStatusInTecoal(status);
    return TECOAL_STATUS_SUCCESS;
}

// Function to perform the forward pass for batch convolution
tecoalStatus_t TECOALWINAPI tecoalConvolutionForward(
    tecoalHandle_t handle, const void *alpha, const tecoalTensorDescriptor_t xDesc, const void *x,
    const tecoalFilterDescriptor_t wDesc, const void *w,
    const tecoalConvolutionDescriptor_t convDesc, tecoalAlgo_t algo, void *workSpace,
    size_t workSpaceSizeInBytes, const void *beta, const tecoalTensorDescriptor_t yDesc, void *y) {
    // Structure to hold arguments for the forward convolution operation
    ConvFwdArgs arg;

    // Structure to hold patched arguments for the operation
    ConvFwdPatchArgs args_patch;

    // Validate and retrieve the convolution operation arguments based on descriptors
    checkTecoalStatus(getConvFwdArgs(handle, xDesc, wDesc, convDesc, yDesc, &arg, &args_patch));

    // Assign data to arguments
    arg.x = x;
    arg.w = w;
    arg.y = y;
    arg.workSpace = workSpace;
    arg.workSpaceSize = workSpaceSizeInBytes;
    args_patch.algo = Convert::toUalAlgoType(algo);

    // Execute the forward convolution operation
    RUN_OP(ConvFwdOp, arg, args_patch, handle);

    return TECOAL_STATUS_SUCCESS;
}
