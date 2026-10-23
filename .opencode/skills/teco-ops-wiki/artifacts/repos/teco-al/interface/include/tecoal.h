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

#ifndef INTERFACE_INCLUDE_TECOAL_H_
#define INTERFACE_INCLUDE_TECOAL_H_

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sdaa_runtime.h>
#include <string>

#define TECOAL_MAJOR 1
#define TECOAL_MINOR 1
#define TECOAL_PATCH 0
#define TECOAL_VERSION (TECOAL_MAJOR * 10000 + TECOAL_MINOR * 100 + TECOAL_PATCH)

#ifndef TECOALWINAPI
#ifdef _WIN32
#define TECOALWINAPI __stdcall
#else
#define TECOALWINAPI
#endif
#endif

#if defined(__cplusplus)
extern "C" {
#endif

typedef enum {
    TECOAL_STATUS_SUCCESS = 0,
    TECOAL_STATUS_NOT_INITIALIZED = 1,
    TECOAL_STATUS_ALLOC_FAILED = 2,
    TECOAL_STATUS_BAD_PARAM = 3,
    TECOAL_STATUS_INTERNAL_ERROR = 4,
    TECOAL_STATUS_INVALID_VALUE = 5,
    TECOAL_STATUS_ARCH_MISMATCH = 6,
    TECOAL_STATUS_MAPPING_ERROR = 7,
    TECOAL_STATUS_EXECUTION_FAILED = 8,
    TECOAL_STATUS_NOT_SUPPORTED = 9,
    TECOAL_STATUS_CONFIG_ERROR = 10,
    TECOAL_STATUS_BAD_LD
} tecoalStatus_t;

typedef enum {
    TECOAL_OP_N = 0,  // no transpose
    TECOAL_OP_T = 1,  // transpose
    TECOAL_OP_C = 2,  // conjugate transpose
} tecoalOperation_t;

typedef enum {
    TECOAL_DATA_FLOAT = 0,
    TECOAL_DATA_HALF = 1,
    TECOAL_DATA_INT8 = 2,
    TECOAL_DATA_INT16 = 3,
    TECOAL_DATA_INT32 = 4,
    TECOAL_DATA_INT64 = 5,
    TECOAL_DATA_DOUBLE = 6,
    TECOAL_DATA_BOOL = 7,
    TECOAL_DATA_UINT8 = 8,
    TECOAL_DATA_BFLOAT16 = 9
} tecoalDataType_t;

typedef enum {
    TECOAL_TENSOR_NCHW = 0,  // row major (wStride = 1, hStride = w)
    TECOAL_TENSOR_NHWC = 1,  // feature maps interleaved (cStride = 1)
    // each image point is vector of element of C, vector length in data type
    TECOAL_TENSOR_CHWN = 2,
    TECOAL_TENSOR_NWHC = 3,
} tecoalTensorFormat_t;

typedef enum {
    TECOAL_ALGO_0 = 0,
    TECOAL_ALGO_1,
    TECOAL_ALGO_2,
    TECOAL_ALGO_3,
    TECOAL_ALGO_4,
    TECOAL_ALGO_5,
    TECOAL_ALGO_6,
    TECOAL_ALGO_7,
    TECOAL_ALGO_8,
    TECOAL_ALGO_9,
    TECOAL_ALGO_10,
    TECOAL_ALGO_11,
    TECOAL_ALGO_12,
    TECOAL_ALGO_13,
    TECOAL_ALGO_14,
    TECOAL_ALGO_15,
    TECOAL_ALGO_16,
    TECOAL_ALGO_17,
    TECOAL_ALGO_18,
    TECOAL_ALGO_19,
    TECOAL_ALGO_20,
    TECOAL_ALGO_21,
    TECOAL_ALGO_22,
    TECOAL_ALGO_23,
    TECOAL_ALGO_24,
    TECOAL_ALGO_25,
    TECOAL_ALGO_26,
    TECOAL_ALGO_27,
    TECOAL_ALGO_28,
    TECOAL_ALGO_29,
    TECOAL_ALGO_30,
    TECOAL_ALGO_31,
    TECOAL_ALGO_32,
    TECOAL_ALGO_33,
    TECOAL_ALGO_34,
    TECOAL_ALGO_35,
    TECOAL_ALGO_36,
    TECOAL_ALGO_37,
    TECOAL_ALGO_38,
    TECOAL_ALGO_39,
    TECOAL_ALGO_40,
    TECOAL_ALGO_41,
    TECOAL_ALGO_42,
    TECOAL_ALGO_43,
    TECOAL_ALGO_44,
    TECOAL_ALGO_45,
    TECOAL_ALGO_46,
    TECOAL_ALGO_47,
    TECOAL_ALGO_48,
    TECOAL_ALGO_49,
    TECOAL_ALGO_50,
    TECOAL_ALGO_51,
    TECOAL_ALGO_52,
    TECOAL_ALGO_53,
    TECOAL_ALGO_54,
    TECOAL_ALGO_55,
    TECOAL_ALGO_56,
    TECOAL_ALGO_57,
    TECOAL_ALGO_58,
    TECOAL_ALGO_59,
    TECOAL_ALGO_60,
    TECOAL_ALGO_61,
    TECOAL_ALGO_62,
    TECOAL_ALGO_63,
    TECOAL_ALGO_64,
    TECOAL_ALGO_65,
    TECOAL_ALGO_66,
    TECOAL_ALGO_67,
    TECOAL_ALGO_68,
    TECOAL_ALGO_69,
    TECOAL_ALGO_70,
    TECOAL_ALGO_71,
    TECOAL_ALGO_72,
    TECOAL_ALGO_73,
    TECOAL_ALGO_74,
    TECOAL_ALGO_75,
    TECOAL_ALGO_76,
    TECOAL_ALGO_77,
    TECOAL_ALGO_78,
    TECOAL_ALGO_79,
    TECOAL_ALGO_80,
    TECOAL_ALGO_81,
    TECOAL_ALGO_82,
    TECOAL_ALGO_83,
    TECOAL_ALGO_84,
    TECOAL_ALGO_85,
    TECOAL_ALGO_86,
    TECOAL_ALGO_87,
    TECOAL_ALGO_88,
    TECOAL_ALGO_89,
    TECOAL_ALGO_90,
    TECOAL_ALGO_91,
    TECOAL_ALGO_92,
    TECOAL_ALGO_93,
    TECOAL_ALGO_94,
    TECOAL_ALGO_95,
    TECOAL_ALGO_96,
    TECOAL_ALGO_97,
    TECOAL_ALGO_98,
    TECOAL_ALGO_99,
    TECOAL_ALGO_100,
    TECOAL_ALGO_101,
    TECOAL_ALGO_102,
    TECOAL_ALGO_103,
    TECOAL_ALGO_104,
    TECOAL_ALGO_105,
    TECOAL_ALGO_106,
    TECOAL_ALGO_107,
    TECOAL_ALGO_108,
    TECOAL_ALGO_109,
    TECOAL_ALGO_110
} tecoalAlgo_t;

struct tecoalContext;
typedef struct tecoalContext *tecoalHandle_t;

tecoalStatus_t TECOALWINAPI tecoalSetStream(tecoalHandle_t handle, sdaaStream_t streamId);
tecoalStatus_t TECOALWINAPI tecoalGetStream(tecoalHandle_t handle, sdaaStream_t *streamId);

tecoalStatus_t TECOALWINAPI tecoalCreate(tecoalHandle_t *handle);

tecoalStatus_t TECOALWINAPI tecoalDestroy(tecoalHandle_t handle);

tecoalStatus_t TECOALWINAPI tecoalGetVersion(tecoalHandle_t handle, int *version);

const char *tecoalGetErrorString(tecoalStatus_t status);

tecoalStatus_t TECOALWINAPI tecoalHgemm(tecoalHandle_t handle, tecoalOperation_t transa,
                                        tecoalOperation_t transb, int m, int n, int k, float alpha,
                                        const void *A, int lda, const void *B, int ldb, float beta,
                                        void *C, int ldc, tecoalAlgo_t algo);

typedef struct tecoalTensorStruct *tecoalTensorDescriptor_t;
typedef struct tecoalConvolutionStruct *tecoalConvolutionDescriptor_t;
typedef struct tecoalFilterStruct *tecoalFilterDescriptor_t;
typedef struct tecoalActivationStruct *tecoalActivationDescriptor_t;

typedef enum {
    TECOAL_DEFAULT_MATH = 0,
    TECOAL_TENSOR_ACC_MATH = 1,
    TECOAL_TENSOR_ACC_MATH_ALLOW_CONVERSION = 2,
} tecoalMathType_t;

tecoalStatus_t TECOALWINAPI tecoalCreateTensorDescriptor(tecoalTensorDescriptor_t *tensorDesc);

tecoalStatus_t TECOALWINAPI
tecoalSetTensor4dDescriptor(tecoalTensorDescriptor_t tensorDesc, tecoalTensorFormat_t format,
                            tecoalDataType_t dataType,  // image data type
                            int n,                      // number of inputs (batch size)
                            int c,                      // number of input feature maps
                            int h,                      // height of input section
                            int w);                     // width of input section

tecoalStatus_t TECOALWINAPI tecoalGetTensor4dDescriptor(
    const tecoalTensorDescriptor_t tensorDesc, tecoalDataType_t *dataType,  // image data type
    int *n,  // number of inputs (batch size)
    int *c,  // number of input feature maps
    int *h,  // height of input section
    int *w,  // width of input section
    int *nStride, int *cStride, int *hStride, int *wStride);

tecoalStatus_t TECOALWINAPI tecoalSetTensorNdDescriptor(tecoalTensorDescriptor_t tensorDesc,
                                                        tecoalDataType_t dataType, int nbDims,
                                                        const int dimA[], const int strideA[]);

tecoalStatus_t TECOALWINAPI tecoalGetTensorNdDescriptor(const tecoalTensorDescriptor_t tensorDesc,
                                                        int nbDimsRequested,
                                                        tecoalDataType_t *dataType, int *nbDims,
                                                        int dimA[], int strideA[]);

tecoalStatus_t TECOALWINAPI tecoalDestroyTensorDescriptor(tecoalTensorDescriptor_t tensorDesc);

tecoalStatus_t TECOALWINAPI tecoalCreateFilterDescriptor(tecoalFilterDescriptor_t *filterDesc);

tecoalStatus_t TECOALWINAPI tecoalSetFilter4dDescriptor(
    tecoalFilterDescriptor_t filterDesc, tecoalDataType_t dataType,  // image data type
    tecoalTensorFormat_t format, int k,  // number of output feature maps
    int c,                               // number of input feature maps
    int h,                               // height of each input filter
    int w);                              // width of  each input filter

tecoalStatus_t TECOALWINAPI tecoalGetFilter4dDescriptor(
    const tecoalFilterDescriptor_t filterDesc, tecoalDataType_t *dataType,  // image data type
    tecoalTensorFormat_t *format, int *k,  // number of output feature maps
    int *c,                                // number of input feature maps
    int *h,                                // height of each input filter
    int *w);                               // width of  each input filter

tecoalStatus_t TECOALWINAPI tecoalDestroyFilterDescriptor(tecoalFilterDescriptor_t filterDesc);

tecoalStatus_t TECOALWINAPI tecoalAddTensor(tecoalHandle_t handle, const void *alpha,
                                            const tecoalTensorDescriptor_t aDesc, const void *A,
                                            const void *beta, const tecoalTensorDescriptor_t cDesc,
                                            void *C, tecoalAlgo_t algo);

typedef enum {
    TECOAL_CONVOLUTION = 0,
    TECOAL_CROSS_CORRELATION = 1,
} tecoalConvolutionMode_t;

tecoalStatus_t TECOALWINAPI
tecoalCreateConvolutionDescriptor(tecoalConvolutionDescriptor_t *convDesc);

tecoalStatus_t TECOALWINAPI
tecoalDestroyConvolutionDescriptor(tecoalConvolutionDescriptor_t convDesc);

tecoalStatus_t TECOALWINAPI tecoalSetConvolution2dDescriptor(
    tecoalConvolutionDescriptor_t convDesc, int pad_h,  // zero-padding height
    int pad_w,                                          // zero-padding width
    int u,                                              // vertical filter stride
    int v,                                              // horizontal filter stride
    int dilation_h,                                     // filter dilation in the vertical dimension
    int dilation_w,  // filter dilation in the horizontal dimension
    tecoalConvolutionMode_t mode, tecoalDataType_t dataType);

tecoalStatus_t TECOALWINAPI tecoalGetConvolution2dDescriptor(
    const tecoalConvolutionDescriptor_t convDesc, int *pad_h,  // zero-padding height
    int *pad_w,                                                // zero-padding width
    int *u,                                                    // vertical filter stride
    int *v,                                                    // horizontal filter stride
    int *dilation_h,  // filter dilation in the vertical dimension
    int *dilation_w,  // filter dilation in the horizontal dimension
    tecoalConvolutionMode_t *mode, tecoalDataType_t *dataType);

tecoalStatus_t TECOALWINAPI tecoalGetConvolutionForwardWorkspaceSize(
    tecoalHandle_t handle, const tecoalTensorDescriptor_t xDesc,
    const tecoalFilterDescriptor_t wDesc, const tecoalConvolutionDescriptor_t convDesc,
    const tecoalTensorDescriptor_t yDesc, tecoalAlgo_t algo, size_t *workSpaceSizeInBytes);

tecoalStatus_t TECOALWINAPI tecoalConvolutionForward(
    tecoalHandle_t handle, const void *alpha, const tecoalTensorDescriptor_t xDesc, const void *x,
    const tecoalFilterDescriptor_t wDesc, const void *w,
    const tecoalConvolutionDescriptor_t convDesc, tecoalAlgo_t algo, void *workSpace,
    size_t workSpaceSizeInBytes, const void *beta, const tecoalTensorDescriptor_t yDesc, void *y);

// Scale all values of a tensor by a given factor : y[i] = alpha * y[i]
tecoalStatus_t TECOALWINAPI tecoalScaleTensor(tecoalHandle_t handle,
                                              const tecoalTensorDescriptor_t yDesc, void *y,
                                              const void *alpha, tecoalAlgo_t algo);

typedef enum {
    TECOAL_SCATTEROUT_REDUCTION_NONE = 0,
    TECOAL_SCATTEROUT_REDUCTION_ADD = 1,
    TECOAL_SCATTEROUT_REDUCTION_MULTIPLY = 2,
} tecoalScatterOutReductionMode_t;

typedef enum {
    TECOAL_SCATTEROUT_INPUT_SCALAR = 0,
    TECOAL_SCATTEROUT_INPUT_ARRAY = 1,
} tecoalScatterOutInputType_t;

tecoalStatus_t TECOALWINAPI tecoalScatterOut(
    tecoalHandle_t handle, const unsigned int target_dim, const float alpha,
    const tecoalScatterOutInputType_t input_type, const tecoalScatterOutReductionMode_t reduce,
    const tecoalTensorDescriptor_t inputDesc, const void *input,
    const tecoalTensorDescriptor_t indexDesc, const void *index,
    const tecoalTensorDescriptor_t outputDesc, void *output, tecoalAlgo_t algo);

typedef enum {
    TECOAL_UNIQUE_NONE = 0,
    TECOAL_UNIQUE_NOT_NONE = 1,
} tecoalUniqueMode_t;

tecoalStatus_t TECOALWINAPI tecoalUnique(tecoalHandle_t handle, tecoalUniqueMode_t mode, int axis,
                                         bool sorted, bool return_inverse, bool return_counts,
                                         const tecoalTensorDescriptor_t inputDesc,
                                         const void *input,
                                         const tecoalTensorDescriptor_t outputDesc, void *output,
                                         const tecoalTensorDescriptor_t inverseDesc, void *inverse,
                                         const tecoalTensorDescriptor_t countsDesc, void *counts,
                                         void *out_size, tecoalAlgo_t algo);

tecoalStatus_t TECOALWINAPI
tecoalMaskedFill(tecoalHandle_t handle, const float value, const tecoalTensorDescriptor_t inputDesc,
                 const void *input, const tecoalTensorDescriptor_t maskDesc, const void *mask,
                 const tecoalTensorDescriptor_t outputDesc, void *output, tecoalAlgo_t algo);

tecoalStatus_t TECOALWINAPI tecoalArgmax(tecoalHandle_t handle, const int axis,
                                         const tecoalTensorDescriptor_t xDesc, const void *x,
                                         const tecoalTensorDescriptor_t yDesc, void *y,
                                         tecoalAlgo_t algo);
typedef enum {
    // without alpha
    // TECOAL_BATCH_LOG = 0,
    // TECOAL_BATCH_EXP = 1,
    // TECOAL_BATCH_SQRT = 2,
    // TECOAL_BATCH_RSQRT = 3,
    // TECOAL_BATCH_SQUARE = 4,
    // TECOAL_BATCH_SIN = 5,
    // TECOAL_BATCH_COS = 6,
    // TECOAL_BATCH_TANH = 7,
    // TECOAL_BATCH_CEIL = 8,
    // TECOAL_BATCH_FLOOR = 9,
    // TECOAL_BATCH_FABS = 10,

    // with alpha
    TECOAL_BATCH_ADD_A = 11,
    // TECOAL_BATCH_SUB_A = 12,
    TECOAL_BATCH_MUL_A = 13,
    // TECOAL_BATCH_DIV_A = 14,
    // TECOAL_BATCH_RDIV = 15,
    // TECOAL_BATCH_POW = 16,

    // convert
    // TECOAL_BATCH_S2H = 17,
    // TECOAL_BATCH_H2S = 18
} tecoalUnaryOpsMode_t;

tecoalStatus_t TECOALWINAPI tecoalUnaryOps(tecoalHandle_t handle, tecoalUnaryOpsMode_t mode,
                                           const void *alpha, const tecoalTensorDescriptor_t xDesc,
                                           const void *x, const tecoalTensorDescriptor_t yDesc,
                                           void *y, tecoalAlgo_t algo);

tecoalStatus_t TECOALWINAPI
tecoalIndexPut(tecoalHandle_t handle, int indices_length, bool accumulate,
               const tecoalTensorDescriptor_t *indicesDesc, void **indices,
               const tecoalTensorDescriptor_t valuesDesc, const void *values,
               const tecoalTensorDescriptor_t inputDesc, const void *input,
               const tecoalTensorDescriptor_t outputDesc, void *output, tecoalAlgo_t algo);

tecoalStatus_t TECOALWINAPI tecoalMaskedSelect(
    tecoalHandle_t handle, const tecoalTensorDescriptor_t inputDesc, const void *input,
    const tecoalTensorDescriptor_t maskDesc, const void *mask,
    const tecoalTensorDescriptor_t outDesc, void *out, void *selectCount, tecoalAlgo_t algo);

tecoalStatus_t TECOALWINAPI tecoalLogicalNotTensor(tecoalHandle_t handle,
                                                   const tecoalTensorDescriptor_t aDesc,
                                                   const void *A,
                                                   const tecoalTensorDescriptor_t cDesc, void *C,
                                                   tecoalAlgo_t algo);
typedef enum {
    TECOAL_NOT_PROPAGATE_NAN = 0,
    TECOAL_PROPAGATE_NAN = 1,
} tecoalNanPropagation_t;

typedef enum {
    // TECOAL_ACTIVATION_SIGMOID = 0,
    // TECOAL_ACTIVATION_RELU = 1,
    // TECOAL_ACTIVATION_TANH = 2,
    // TECOAL_ACTIVATION_CLIPPED_RELU = 3,
    // TECOAL_ACTIVATION_ELU = 4,
    // TECOAL_ACTIVATION_IDENTITY = 5,
    // TECOAL_ACTIVATION_SIGMOID_TAB = 6,
    // TECOAL_ACTIVATION_ELU_TAB = 7,
    // TECOAL_ACTIVATION_TANH_TAB = 8,
    // TECOAL_ACTIVATION_GELU = 9,
    // TECOAL_ACTIVATION_LEAKYRELU = 10,
    // TECOAL_ACTIVATION_SELU = 11,
    // TECOAL_ACTIVATION_RELU6 = 12,
    TECOAL_ACTIVATION_SILU = 13,
} tecoalActivationMode_t;

tecoalStatus_t TECOALWINAPI
tecoalCreateActivationDescriptor(tecoalActivationDescriptor_t *activationDesc);

tecoalStatus_t TECOALWINAPI tecoalSetActivationDescriptor(
    tecoalActivationDescriptor_t activationDesc, tecoalActivationMode_t mode,
    tecoalNanPropagation_t reluNanOpt, double coef); /* ceiling for clipped RELU, alpha for ELU */

tecoalStatus_t TECOALWINAPI tecoalGetActivationDescriptor(
    const tecoalActivationDescriptor_t activationDesc, tecoalActivationMode_t *mode,
    tecoalNanPropagation_t *reluNanOpt, double *coef); /* ceiling for clipped RELU, alpha for ELU */

tecoalStatus_t TECOALWINAPI
tecoalDestroyActivationDescriptor(tecoalActivationDescriptor_t activationDesc);

tecoalStatus_t TECOALWINAPI tecoalActivationForward(
    tecoalHandle_t handle, tecoalActivationDescriptor_t activationDesc, const void *alpha,
    const tecoalTensorDescriptor_t xDesc, const void *x, const void *beta,
    const tecoalTensorDescriptor_t yDesc, void *y, tecoalAlgo_t algo);

tecoalStatus_t TECOALWINAPI tecoalActivationBackward(
    tecoalHandle_t handle, tecoalActivationDescriptor_t activationDesc, const void *alpha,
    const tecoalTensorDescriptor_t yDesc, const void *y, const tecoalTensorDescriptor_t dyDesc,
    const void *dy, const tecoalTensorDescriptor_t xDesc, const void *x, const void *beta,
    const tecoalTensorDescriptor_t dxDesc, void *dx, tecoalAlgo_t algo);

tecoalStatus_t TECOALWINAPI
tecoalScatterNdAdd(tecoalHandle_t handle, const tecoalTensorDescriptor_t xDesc, const void *x,
                   const tecoalTensorDescriptor_t indexDesc, const void *index,
                   const tecoalTensorDescriptor_t updatesDesc, const void *updates,
                   const tecoalTensorDescriptor_t outDesc, void *out, tecoalAlgo_t algo);

#if defined(__cplusplus)
}
#endif

#endif  // INTERFACE_INCLUDE_TECOAL_H_
