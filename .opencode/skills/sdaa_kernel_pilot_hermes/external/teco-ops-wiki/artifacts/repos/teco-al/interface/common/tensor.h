#ifndef INTERFACE_COMMON_TENSOR_H_
#define INTERFACE_COMMON_TENSOR_H_

#include "interface/common/check.h"
#include "interface/common/marco.h"
#include "interface/include/tecoal.h"

#define TECOAL_DIM_MAX 8

struct tecoalTensorStruct {
 public:
    // functions start
    tecoalTensorStruct() : format(TECOAL_TENSOR_NHWC), dataType(TECOAL_DATA_FLOAT), nbDims(0) {}
    ~tecoalTensorStruct() {}

    tecoalStatus_t check();

    tecoalStatus_t getTensorDimN(int *dim_size);
    tecoalStatus_t getTensorDimH(int *dim_size);
    tecoalStatus_t getTensorDimW(int *dim_size);
    tecoalStatus_t getTensorDimC(int *dim_size);
    tecoalStatus_t getTensorStrideN(int *stride_size);
    tecoalStatus_t getTensorStrideH(int *stride_size);
    tecoalStatus_t getTensorStrideW(int *stride_size);
    tecoalStatus_t getTensorStrideC(int *stride_size);

    tecoalStatus_t setTensorDimN(int dim_size);
    tecoalStatus_t setTensorDimH(int dim_size);
    tecoalStatus_t setTensorDimW(int dim_size);
    tecoalStatus_t setTensorDimC(int dim_size);
    tecoalStatus_t setTensorStrideN(int stride_size);
    tecoalStatus_t setTensorStrideH(int stride_size);
    tecoalStatus_t setTensorStrideW(int stride_size);
    tecoalStatus_t setTensorStrideC(int stride_size);

    tecoalStatus_t getTensorSizeInBytes(size_t *tensor_size);

    // member variables start
    tecoalTensorFormat_t format = TECOAL_TENSOR_NHWC;
    tecoalDataType_t dataType = TECOAL_DATA_FLOAT;
    int nbDims = 0;

    // if nbDims > TECOAL_DIM_MAX, using expand dims and strides, user should malloc and free.
    // else, using normal dims and strides, user don't need malloc and free.
    int normal_dims[TECOAL_DIM_MAX] = {-1};
    int normal_strides[TECOAL_DIM_MAX] = {-1};

    int *expand_dims = nullptr;
    int *expand_strides = nullptr;

    int *dimA = normal_dims;
    int *strideA = normal_strides;

    int n = 0;
    int c = 0;
    int h = 0;
    int w = 0;
    int nStride = 0;
    int cStride = 0;
    int hStride = 0;
    int wStride = 0;

 private:
};

struct tecoalFilterStruct {
 public:
    // functions
    tecoalFilterStruct() : format(TECOAL_TENSOR_NHWC), dataType(TECOAL_DATA_FLOAT), nbDims(0) {}
    ~tecoalFilterStruct() {}

    tecoalStatus_t check();

    tecoalStatus_t getFilterDimM(int *dim_size);
    tecoalStatus_t getFilterDimC(int *dim_size);
    tecoalStatus_t getFilterDimR(int *dim_size);
    tecoalStatus_t getFilterDimS(int *dim_size);

    tecoalStatus_t setFilterDimM(int dim_size);
    tecoalStatus_t setFilterDimC(int dim_size);
    tecoalStatus_t setFilterDimR(int dim_size);
    tecoalStatus_t setFilterDimS(int dim_size);

    tecoalStatus_t getFilterSizeInBytes(size_t *tensor_size);

    // member variables
    tecoalTensorFormat_t format = TECOAL_TENSOR_NHWC;
    tecoalDataType_t dataType = TECOAL_DATA_FLOAT;
    int nbDims = 0;

    // if nbDims > TECOAL_DIM_MAX, using expand dims, user should malloc and free.
    // else, using normal dims, user don't need malloc and free.
    int normal_dims[TECOAL_DIM_MAX] = {-1};

    int *expand_dims = nullptr;

    int *filterDimA = normal_dims;

    int m = 0;
    int c = 0;
    int r = 0;
    int s = 0;

 private:
};

#endif  // INTERFACE_COMMON_TENSOR_H_
