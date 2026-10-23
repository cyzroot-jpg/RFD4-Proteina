// MIT License
// 
// Copyright (c) 2024, Tecorigin Co., Ltd.
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
 
#include "device/cuda/version.h"
#include <stdlib.h>
#include <cuda.h>
#include <cuda_runtime.h>
#include "common/variable.h"

#if DNN_ENABLE
#include <cudnn.h>
#endif
#if BLAS_ENABLE
// #include <cublas.h>
#include <cublas_v2.h>
#endif

#include <iostream>
#include <string>
#include "device/cuda/common.h"

extern optest::GlobalVar global_var;

namespace optest {
namespace cuda {

std::string formatVersion(int version) { return std::to_string(version); }

void printVersions() {
    cuInit(0);
    int driver_version = 0, runtime_version = 0;
    char device_name[100];
    CUdevice device = global_var.kernel_id_;
    CUresult res = cuDeviceGetName(device_name, sizeof(device_name), device);
    checkCudaErrors(cudaDriverGetVersion(&driver_version));
    checkCudaErrors(cudaRuntimeGetVersion(&runtime_version));

    size_t dnn_version = 0;
    int blas_version = 0;
#if DNN_ENABLE
    dnn_version = cudnnGetVersion();
#endif

#if BLAS_ENABLE
    // cublasGetVersion(&blas_version);
    cublasHandle_t handle;
    cublasCreate(&handle);
    cublasGetVersion(handle, &blas_version);
    cublasDestroy(handle);
#endif

    std::cout << "----------------------------" << std::endl;
    std::cout << "device     : " << (std::string)device_name << std::endl;
    std::cout << "cudadriver : " << formatVersion(driver_version) << std::endl;
    std::cout << "cudart     : " << formatVersion(runtime_version) << std::endl;
    std::cout << "tecoal    : " << formatVersion(dnn_version) << std::endl;
    std::cout << "tecoblas   : " << formatVersion(blas_version) << std::endl;
    std::cout << "----------------------------" << std::endl;
}

}  // namespace cuda
}  // namespace optest
