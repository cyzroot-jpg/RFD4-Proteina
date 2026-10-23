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
#include "interface/common/marco.h"
#include "interface/common/tensor.h"

tecoalStatus_t TECOALWINAPI tecoalCreate(tecoalHandle_t *handle) {
    *handle = (tecoalHandle_t)malloc(sizeof(tecoalHandle_t));
    (*handle)->spa_num = 1;
    (*handle)->spe_num = 32;
    (*handle)->stream = nullptr;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t TECOALWINAPI tecoalDestroy(tecoalHandle_t handle) {
    if (!handle) return TECOAL_STATUS_BAD_PARAM;
    free(handle);
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t TECOALWINAPI tecoalSetStream(tecoalHandle_t handle, sdaaStream_t streamId) {
    if (!handle) return TECOAL_STATUS_BAD_PARAM;
    handle->stream = streamId;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t TECOALWINAPI tecoalGetStream(tecoalHandle_t handle, sdaaStream_t *streamId) {
    if (!handle || !streamId) return TECOAL_STATUS_BAD_PARAM;
    *streamId = handle->stream;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t TECOALWINAPI tecoalCreateTensorDescriptor(tecoalTensorDescriptor_t *tensorDesc) {
    *tensorDesc = new tecoalTensorStruct();
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t TECOALWINAPI tecoalSetTensor4dDescriptor(tecoalTensorDescriptor_t tensorDesc,
                                                        tecoalTensorFormat_t format,
                                                        tecoalDataType_t dataType, int n, int c,
                                                        int h, int w) {
    tensorDesc->format = format;
    tensorDesc->dataType = dataType;
    tensorDesc->nbDims = 4;
    checkTecoalStatus(tensorDesc->setTensorDimN(n));
    checkTecoalStatus(tensorDesc->setTensorDimC(c));
    checkTecoalStatus(tensorDesc->setTensorDimH(h));
    checkTecoalStatus(tensorDesc->setTensorDimW(w));

    int nStride, cStride, hStride, wStride;
    if (format == TECOAL_TENSOR_NCHW) {
        nStride = (c * h * w);
        cStride = (h * w);
        hStride = (w);
        wStride = (1);
    } else if (format == TECOAL_TENSOR_NHWC) {
        nStride = (h * w * c);
        cStride = (1);
        hStride = (w * c);
        wStride = (c);
    } else if (format == TECOAL_TENSOR_CHWN) {
        nStride = (1);
        cStride = (h * w * n);
        hStride = (w * n);
        wStride = (n);
    } else if (format == TECOAL_TENSOR_NWHC) {
        nStride = (w * h * c);
        cStride = (1);
        hStride = (c);
        wStride = (h * c);
    } else {
        return TECOAL_STATUS_BAD_PARAM;
    }
    checkTecoalStatus(tensorDesc->setTensorStrideN(nStride));
    checkTecoalStatus(tensorDesc->setTensorStrideC(cStride));
    checkTecoalStatus(tensorDesc->setTensorStrideH(hStride));
    checkTecoalStatus(tensorDesc->setTensorStrideW(wStride));
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t TECOALWINAPI tecoalGetTensor4dDescriptor(tecoalTensorDescriptor_t tensorDesc,
                                                        tecoalDataType_t *dataType, int *n, int *c,
                                                        int *h, int *w, int *nStride, int *cStride,
                                                        int *hStride, int *wStride) {
    if (tensorDesc->nbDims != 4) {
        return TECOAL_STATUS_BAD_PARAM;
    }

    if (dataType != nullptr) {
        *dataType = tensorDesc->dataType;
    }
    if (n != nullptr) {
        checkTecoalStatus(tensorDesc->getTensorDimN(n));
    }
    if (c != nullptr) {
        checkTecoalStatus(tensorDesc->getTensorDimC(c));
    }
    if (h != nullptr) {
        checkTecoalStatus(tensorDesc->getTensorDimH(h));
    }
    if (w != nullptr) {
        checkTecoalStatus(tensorDesc->getTensorDimW(w));
    }

    if (nStride != nullptr) {
        checkTecoalStatus(tensorDesc->getTensorStrideN(nStride));
    }
    if (cStride != nullptr) {
        checkTecoalStatus(tensorDesc->getTensorStrideC(cStride));
    }
    if (hStride != nullptr) {
        checkTecoalStatus(tensorDesc->getTensorStrideH(hStride));
    }
    if (wStride != nullptr) {
        checkTecoalStatus(tensorDesc->getTensorStrideW(wStride));
    }
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t TECOALWINAPI tecoalSetTensorNdDescriptor(tecoalTensorDescriptor_t tensorDesc,
                                                        tecoalDataType_t dataType, int nbDims,
                                                        const int dimA[], const int strideA[]) {
    if (nbDims <= 0) {
        return TECOAL_STATUS_BAD_PARAM;
    }

    tensorDesc->dataType = dataType;
    tensorDesc->format = TECOAL_TENSOR_NCHW;
    if (nbDims == 4) {
        tensorDesc->n = dimA[0];
        tensorDesc->c = dimA[1];
        tensorDesc->h = dimA[2];
        tensorDesc->w = dimA[3];
    }
    tensorDesc->nbDims = nbDims;

    if (nbDims > TECOAL_DIM_MAX) {
        if (TECO_PREDICT_FALSE(tensorDesc->expand_dims != nullptr)) {
            free(tensorDesc->expand_dims);
        }
        if (TECO_PREDICT_FALSE(tensorDesc->expand_strides != nullptr)) {
            free(tensorDesc->expand_strides);
        }
        tensorDesc->expand_dims = (int *)malloc(sizeof(int) * nbDims);
        tensorDesc->expand_strides = (int *)malloc(sizeof(int) * nbDims);
        tensorDesc->dimA = tensorDesc->expand_dims;
        tensorDesc->strideA = tensorDesc->expand_strides;
    }
    memcpy(tensorDesc->dimA, dimA, sizeof(int) * nbDims);

    if (strideA != nullptr) {
        memcpy(tensorDesc->strideA, strideA, sizeof(int) * nbDims);
    } else {
        (tensorDesc->strideA)[nbDims - 1] = 1;
        for (int i = nbDims - 2; i >= 0; i--) {
            (tensorDesc->strideA)[i] = (tensorDesc->strideA)[i + 1] * dimA[i + 1];
        }
    }
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t TECOALWINAPI tecoalGetTensorNdDescriptor(const tecoalTensorDescriptor_t tensorDesc,
                                                        int nbDimsRequested,
                                                        tecoalDataType_t *dataType, int *nbDims,
                                                        int dimA[], int strideA[]) {
    if (nbDimsRequested <= 0) {
        return TECOAL_STATUS_BAD_PARAM;
    }

    if (dataType != nullptr) {
        *dataType = tensorDesc->dataType;
    }

    int return_nbDims = tensorDesc->nbDims;
    if (nbDims != nullptr) {
        *nbDims = tensorDesc->nbDims;
        return_nbDims = (return_nbDims < nbDimsRequested) ? return_nbDims : nbDimsRequested;
    }
    if (dimA != nullptr) {
        memcpy(dimA, tensorDesc->dimA, sizeof(int) * (return_nbDims));
    }
    if (strideA != nullptr) {
        memcpy(strideA, tensorDesc->strideA, sizeof(int) * (return_nbDims));
    }
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t TECOALWINAPI tecoalDestroyTensorDescriptor(tecoalTensorDescriptor_t tensorDesc) {
    if (tensorDesc != nullptr) {
        delete tensorDesc;
    }
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t TECOALWINAPI tecoalCreateFilterDescriptor(tecoalFilterDescriptor_t *filterDesc) {
    *filterDesc = new tecoalFilterStruct;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t TECOALWINAPI tecoalSetFilter4dDescriptor(tecoalFilterDescriptor_t filterDesc,
                                                        tecoalDataType_t dataType,
                                                        tecoalTensorFormat_t format, int k, int c,
                                                        int h, int w) {
    filterDesc->dataType = dataType;
    filterDesc->format = format;
    filterDesc->nbDims = 4;
    filterDesc->m = k;
    filterDesc->c = c;
    filterDesc->r = h;
    filterDesc->s = w;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t TECOALWINAPI tecoalGetFilter4dDescriptor(const tecoalFilterDescriptor_t filterDesc,
                                                        tecoalDataType_t *dataType,
                                                        tecoalTensorFormat_t *format, int *k,
                                                        int *c, int *h, int *w) {
    if (filterDesc->nbDims != 4) {
        return TECOAL_STATUS_BAD_PARAM;
    }

    if (dataType != nullptr) {
        *dataType = filterDesc->dataType;
    }
    if (format != nullptr) {
        *format = filterDesc->format;
    }
    if (k != nullptr) {
        *k = filterDesc->m;
    }
    if (c != nullptr) {
        *c = filterDesc->c;
    }
    if (h != nullptr) {
        *h = filterDesc->r;
    }
    if (w != nullptr) {
        *w = filterDesc->s;
    }
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t TECOALWINAPI tecoalDestroyFilterDescriptor(tecoalFilterDescriptor_t filterDesc) {
    if (filterDesc != nullptr) {
        delete filterDesc;
    }
    return TECOAL_STATUS_SUCCESS;
}

const char *TECOALWINAPI tecoalGetErrorString(tecoalStatus_t status) {
    switch (status) {
        case TECOAL_STATUS_SUCCESS: return ("TECOAL_STATUS_SUCCESS");
        case TECOAL_STATUS_NOT_INITIALIZED: return ("TECOAL_STATUS_NOT_INITIALIZED");
        case TECOAL_STATUS_ALLOC_FAILED: return ("TECOAL_STATUS_ALLOC_FAILED");
        case TECOAL_STATUS_BAD_PARAM: return ("TECOAL_STATUS_BAD_PARAM");
        case TECOAL_STATUS_INTERNAL_ERROR: return ("TECOAL_STATUS_INTERNAL_ERROR");
        case TECOAL_STATUS_INVALID_VALUE: return ("TECOAL_STATUS_INVALID_VALUE");
        case TECOAL_STATUS_ARCH_MISMATCH: return ("TECOAL_STATUS_ARCH_MISMATCH");
        case TECOAL_STATUS_MAPPING_ERROR: return ("TECOAL_STATUS_MAPPING_ERROR");
        case TECOAL_STATUS_EXECUTION_FAILED: return ("TECOAL_STATUS_EXECUTION_FAILED");
        case TECOAL_STATUS_NOT_SUPPORTED: return ("TECOAL_STATUS_NOT_SUPPORTED");
        default: return ("unknown err\n");
    }
}

size_t TECOALWINAPI tecoalGetVersion(void) {
// TYPE {0:release, 1:release candidate, 2: beta, 3: alpha}
#define TECOAL_VERSION_TYPE 3
#define TECOAL_VERSION_TYPE_NO 7

    return TECOAL_MAJOR * 100000000 + TECOAL_MINOR * 1000000 + TECOAL_PATCH * 10000 +
           TECOAL_VERSION_TYPE * 100 + TECOAL_VERSION_TYPE_NO;

#undef TECOAL_VERSION_TYPE
#undef TECOAL_VERSION_TYPE_NO

    // return TECOAL_VERSION;
}
