#include "interface/common/tensor.h"
#include "interface/common/convert.h"
#include "ual/com/log.h"

using tecoal::Convert;

// tecoalTensorStruct
tecoalStatus_t tecoalTensorStruct::check() {
    switch (format) {
        case TECOAL_TENSOR_NCHW:
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_NWHC:
        case TECOAL_TENSOR_CHWN: {
            if (nbDims != 4) {
                ERROR("tecoal tensor struct format and nbDims mismatch\n");
                return TECOAL_STATUS_BAD_PARAM;
            }
            return TECOAL_STATUS_SUCCESS;
        }
        default:
            ERROR("tecoal tensor struct illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
}

tecoalStatus_t tecoalTensorStruct::getTensorDimN(int *dim_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NCHW:
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_NWHC: index = 0; break;
        case TECOAL_TENSOR_CHWN: index = 3; break;
        default:
            ERROR("tecoal getTensorDimN illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    *dim_size = dimA[index];
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalTensorStruct::getTensorDimH(int *dim_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_CHWN: index = 1; break;
        case TECOAL_TENSOR_NCHW:
        case TECOAL_TENSOR_NWHC: index = 2; break;
        default:
            ERROR("tecoal getTensorDimH illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    *dim_size = dimA[index];
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalTensorStruct::getTensorDimW(int *dim_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NWHC: index = 1; break;
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_CHWN: index = 2; break;
        case TECOAL_TENSOR_NCHW: index = 3; break;
        default:
            ERROR("tecoal getTensorDimW illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    *dim_size = dimA[index];
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalTensorStruct::getTensorDimC(int *dim_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_CHWN: index = 0; break;
        case TECOAL_TENSOR_NCHW: index = 1; break;
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_NWHC: index = 3; break;
        default:
            ERROR("tecoal getTensorDimC illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    *dim_size = dimA[index];
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalTensorStruct::getTensorStrideN(int *stride_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NCHW:
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_NWHC: index = 0; break;
        case TECOAL_TENSOR_CHWN: index = 3; break;
        default:
            ERROR("tecoal getTensorStrideN illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    *stride_size = strideA[index];
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalTensorStruct::getTensorStrideH(int *stride_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_CHWN: index = 1; break;
        case TECOAL_TENSOR_NCHW:
        case TECOAL_TENSOR_NWHC: index = 2; break;
        default:
            ERROR("tecoal getTensorStrideH illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    *stride_size = strideA[index];
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalTensorStruct::getTensorStrideW(int *stride_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NWHC: index = 1; break;
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_CHWN: index = 2; break;
        case TECOAL_TENSOR_NCHW: index = 3; break;
        default:
            ERROR("tecoal getTensorStrideW illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    *stride_size = strideA[index];
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalTensorStruct::getTensorStrideC(int *stride_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_CHWN: index = 0; break;
        case TECOAL_TENSOR_NCHW: index = 1; break;
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_NWHC: index = 3; break;
        default:
            ERROR("tecoal getTensorStrideC illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    *stride_size = strideA[index];
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalTensorStruct::setTensorDimN(int dim_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NCHW:
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_NWHC: index = 0; break;
        case TECOAL_TENSOR_CHWN: index = 3; break;
        default:
            ERROR("tecoal setTensorDimN illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    dimA[index] = dim_size;
    n = dim_size;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalTensorStruct::setTensorDimH(int dim_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_CHWN: index = 1; break;
        case TECOAL_TENSOR_NCHW:
        case TECOAL_TENSOR_NWHC: index = 2; break;
        default:
            ERROR("tecoal setTensorDimH illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    dimA[index] = dim_size;
    h = dim_size;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalTensorStruct::setTensorDimW(int dim_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NWHC: index = 1; break;
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_CHWN: index = 2; break;
        case TECOAL_TENSOR_NCHW: index = 3; break;
        default:
            ERROR("tecoal setTensorDimW illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    dimA[index] = dim_size;
    w = dim_size;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalTensorStruct::setTensorDimC(int dim_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_CHWN: index = 0; break;
        case TECOAL_TENSOR_NCHW: index = 1; break;
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_NWHC: index = 3; break;
        default:
            ERROR("tecoal setTensorDimC illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    dimA[index] = dim_size;
    c = dim_size;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalTensorStruct::setTensorStrideN(int stride_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NCHW:
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_NWHC: index = 0; break;
        case TECOAL_TENSOR_CHWN: index = 3; break;
        default:
            ERROR("tecoal setTensorStrideN illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    strideA[index] = stride_size;
    nStride = stride_size;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalTensorStruct::setTensorStrideH(int stride_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_CHWN: index = 1; break;
        case TECOAL_TENSOR_NCHW:
        case TECOAL_TENSOR_NWHC: index = 2; break;
        default:
            ERROR("tecoal setTensorStrideH illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    strideA[index] = stride_size;
    hStride = stride_size;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalTensorStruct::setTensorStrideW(int stride_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NWHC: index = 1; break;
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_CHWN: index = 2; break;
        case TECOAL_TENSOR_NCHW: index = 3; break;
        default:
            ERROR("tecoal setTensorStrideW illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    strideA[index] = stride_size;
    wStride = stride_size;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalTensorStruct::setTensorStrideC(int stride_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_CHWN: index = 0; break;
        case TECOAL_TENSOR_NCHW: index = 1; break;
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_NWHC: index = 3; break;
        default:
            ERROR("tecoal setTensorStrideC illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    strideA[index] = stride_size;
    cStride = stride_size;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalTensorStruct::getTensorSizeInBytes(size_t *tensor_size) {
    *tensor_size = 1;
    for (int i = nbDims - 1; i >= 0; i--) {
        *tensor_size += (dimA[i] - 1) * strideA[i];
    }
    *tensor_size *= Convert::toDescDataTypeSize(dataType);
    return TECOAL_STATUS_SUCCESS;
}

// tecoalFilterStruct
tecoalStatus_t tecoalFilterStruct::check() {
    switch (format) {
        case TECOAL_TENSOR_NCHW:
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_NWHC:
        case TECOAL_TENSOR_CHWN: {
            if (nbDims != 4) {
                ERROR("tecoal filter struct format and nbDims mismatch\n");
                return TECOAL_STATUS_BAD_PARAM;
            }
            return TECOAL_STATUS_SUCCESS;
        }
        default:
            ERROR("tecoal filter struct illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
}

tecoalStatus_t tecoalFilterStruct::getFilterDimM(int *dim_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NCHW:
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_NWHC: index = 0; break;
        case TECOAL_TENSOR_CHWN: index = 3; break;
        default:
            ERROR("tecoal getFilterDimN illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    *dim_size = filterDimA[index];
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalFilterStruct::getFilterDimC(int *dim_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_CHWN: index = 0; break;
        case TECOAL_TENSOR_NCHW: index = 1; break;
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_NWHC: index = 3; break;
        default:
            ERROR("tecoal getFilterDimC illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    *dim_size = filterDimA[index];
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalFilterStruct::getFilterDimR(int *dim_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_CHWN: index = 1; break;
        case TECOAL_TENSOR_NCHW:
        case TECOAL_TENSOR_NWHC: index = 2; break;
        default:
            ERROR("tecoal getFilterDimR illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    *dim_size = filterDimA[index];
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalFilterStruct::getFilterDimS(int *dim_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NWHC: index = 1; break;
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_CHWN: index = 2; break;
        case TECOAL_TENSOR_NCHW: index = 3; break;
        default:
            ERROR("tecoal getFilterDimS illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    *dim_size = filterDimA[index];
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalFilterStruct::setFilterDimM(int dim_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NCHW:
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_NWHC: index = 0; break;
        case TECOAL_TENSOR_CHWN: index = 3; break;
        default:
            ERROR("tecoal setFilterDimN illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    filterDimA[index] = dim_size;
    m = dim_size;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalFilterStruct::setFilterDimC(int dim_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_CHWN: index = 0; break;
        case TECOAL_TENSOR_NCHW: index = 1; break;
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_NWHC: index = 3; break;
        default:
            ERROR("tecoal setFilterDimC illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    filterDimA[index] = dim_size;
    c = dim_size;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalFilterStruct::setFilterDimR(int dim_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_CHWN: index = 1; break;
        case TECOAL_TENSOR_NCHW:
        case TECOAL_TENSOR_NWHC: index = 2; break;
        default:
            ERROR("tecoal setFilterDimR illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    filterDimA[index] = dim_size;
    r = dim_size;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalFilterStruct::setFilterDimS(int dim_size) {
    checkTecoalStatus(check());

    int index;
    switch (format) {
        case TECOAL_TENSOR_NWHC: index = 1; break;
        case TECOAL_TENSOR_NHWC:
        case TECOAL_TENSOR_CHWN: index = 2; break;
        case TECOAL_TENSOR_NCHW: index = 3; break;
        default:
            ERROR("tecoal setFilterDimS illegal format: %d\n", format);
            return TECOAL_STATUS_BAD_PARAM;
    }
    filterDimA[index] = dim_size;
    s = dim_size;
    return TECOAL_STATUS_SUCCESS;
}

tecoalStatus_t tecoalFilterStruct::getFilterSizeInBytes(size_t *filter_size) {
    checkTecoalStatus(check());

    *filter_size = 1;
    for (int i = nbDims - 1; i >= 0; i--) {
        *filter_size *= filterDimA[i];
    }
    *filter_size *= Convert::toDescDataTypeSize(dataType);

    return TECOAL_STATUS_SUCCESS;
}

// }  // namespace al
// }  // namespace teco
