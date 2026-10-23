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
 
#ifndef DEVICE_CUDA_COMMON_H_  // NOLINT
#define DEVICE_CUDA_COMMON_H_

#include <cuda_runtime.h>
#include <cuda.h>

#define checkCudaErrors(func)                                                                   \
    {                                                                                           \
        cudaError_t status = func;                                                              \
        if (status != cudaSuccess) {                                                            \
            printf("file:%s, func:%s, line: %d, CUDA Error:%d\n", __FILE__, __func__, __LINE__, \
                   status);                                                                     \
        }                                                                                       \
    }

typedef cudaStream_t scdaStream_t;

#define scdaSetDevice(id) cudaSetDevice(id)
#define scdaGetDeviceCount(count) cudaGetDeviceCount(count)
#define scdaStreamCreate(stream) cudaStreamCreate(stream)
#define scdaStreamSynchronize(stream) cudaStreamSynchronize(stream)
#define scdaStreamDestroy(stream) cudaStreamDestroy(stream)
#define scdaMemcpy(dst, src, size, direction) cudaMemcpy(dst, src, size, cuda##direction)
#define scdaMemset(src, value, size) cudaMemset(src, value, size)
#define checkScdaErrors(func) checkCudaErrors(func)

#endif  // DEVICE_CUDA_COMMON_H_  // NOLINT
