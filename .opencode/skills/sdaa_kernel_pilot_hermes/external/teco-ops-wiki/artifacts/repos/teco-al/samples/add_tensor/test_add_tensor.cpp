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

#include <stdio.h>
#include <sdaa_runtime.h>
#include <cstdio>
#include <stdexcept>
#include "interface/include/tecoal.h"
#include "samples/test_data.h"
#include "samples/time.hpp"

// test the AddTensor operation on the CPU
static void test_add_tensor(half_t *A, half_t *true_c, int n, int h, int w, int c, float alpha,
                            float beta) {
    float *a_f32, *true_f32;
    size_t num = n * h * w * c;

    // Allocate memory for float32 arrays
    a_f32 = (float *)malloc(num * 4);
    true_f32 = (float *)malloc(num * 4);

    // Convert half precision float data (FP16) to single precision float (FP32)
    transform_data_h2f((void *)a_f32, (void *)A, num);
    transform_data_h2f((void *)true_f32, (void *)true_c, num);

    // Compute the tensor addition in single precision to emulate high precision calculation
    for (size_t i = 0; i < num; i++) {
        true_f32[i] = beta * true_f32[i] + alpha * a_f32[i];
    }

    // Convert the result back to half precision
    transform_data_f2h(true_c, true_f32, num);

    // free
    free(a_f32);
    free(true_f32);
}

static tecoalAlgo_t convertArgsToAlgo(int ver) {
    switch (ver) {
        case 0: return TECOAL_ALGO_0;
        case 1: return TECOAL_ALGO_1;
        case 2: return TECOAL_ALGO_2;
        case 3: return TECOAL_ALGO_3;
        case 4: return TECOAL_ALGO_4;
        case 5: return TECOAL_ALGO_5;
        default: {
            throw std::runtime_error("The algo type does not exist!\n");
        }
    }
}

int main(int argc, char *argv[]) {
    // Initialize variables
    float alpha = 0.234;
    float beta = 0.76;
    float all_time = 0, time = 0;

    // Check for valid number of command-line arguments
    if (argc < 3) {
        printf("The executable file parameter is incorrect\n");
        return -1;
    }

    int device_id = atoi(argv[1]);

    // Convert command-line argument to algorithm type
    tecoalAlgo_t algo = convertArgsToAlgo(atoi(argv[2]));

    // Dimensions of the tensors
    int n = 768, h = 512, w = 6, c = 2;
    size_t num = n * h * w * c;

    // Calculate size in bytes for the tensors
    int a_size = num * sizeof(half_t);
    int c_size = num * sizeof(half_t);

    void *A, *C, *true_c;

    // Allocate memory for tensor A, C, true result
    A = malloc(a_size);
    C = malloc(c_size);
    true_c = malloc(c_size);

    // Initialize tensor A with random values and tensor C with zeros
    rand_data_f16((half_t *)A, num, -500, 500);
    rand_data_f16((half_t *)C, num, 0, 0);

    // Copy tensor C to true_c for validation
    memcpy(true_c, C, c_size);

    // Create a Tecoal handle for the operation
    tecoalHandle_t handle;
    tecoalCreate(&handle);

    void *d_a, *d_c, *d_c_warm;

    sdaaSetDevice(device_id);

    // Allocate memory on the device
    sdaaMalloc((void **)&d_a, a_size);
    sdaaMalloc((void **)&d_c, c_size);
    sdaaMalloc((void **)&d_c_warm, c_size);

    // Copy data from host to device
    sdaaMemcpy(d_a, A, a_size, sdaaMemcpyHostToDevice);
    sdaaMemcpy(d_c, C, c_size, sdaaMemcpyHostToDevice);
    sdaaMemset(d_c_warm, 0, c_size);

    // timing for host computation
    printf("AddTensor host start\n");
    TimeRecorder::TimeStamp host_start = TimeRecorder::now();
    test_add_tensor((half_t *)A, (half_t *)true_c, n, h, w, c, alpha, beta);
    TimeRecorder::TimeStamp host_end = TimeRecorder::now();
    printf("AddTensor host end\n");

    // Set the SDAA stream for Tecoal operations
    sdaaStream_t stream;
    sdaaStreamCreate(&stream);
    tecoalSetStream(handle, stream);

    // Create tensor descriptor for tensor A, C
    tecoalTensorDescriptor_t aDesc, cDesc;
    tecoalCreateTensorDescriptor(&aDesc);
    tecoalCreateTensorDescriptor(&cDesc);

    // Set the descriptors for 4D tensors in NHWC format
    tecoalSetTensor4dDescriptor(aDesc, TECOAL_TENSOR_NHWC, TECOAL_DATA_HALF, n, c, h, w);
    tecoalSetTensor4dDescriptor(cDesc, TECOAL_TENSOR_NHWC, TECOAL_DATA_HALF, n, c, h, w);

    printf("tecoalAddTensor start\n");

    // warm up
    const int warm_time = 5;
    for (int i = 0; i < warm_time; ++i) {
        tecoalAddTensor(handle, &alpha, aDesc, d_a, &beta, cDesc, d_c_warm, algo);
    }

    // Wait for previous operations to complete
    checkSdaaErrors(sdaaStreamSynchronize(stream));

    // timing for device computation
    TimeRecorder::TimeStamp kernel_start = TimeRecorder::now();
    tecoalAddTensor(handle, &alpha, aDesc, d_a, &beta, cDesc, d_c, algo);
    checkSdaaErrors(sdaaStreamSynchronize(stream));
    TimeRecorder::TimeStamp kernel_end = TimeRecorder::now();
    printf("tecoalAddTensor end\n");

    // Compare host execution time to device execution time
    float htime = TimeRecorder::duration(host_start, host_end);
    float stime = TimeRecorder::duration(kernel_start, kernel_end);

    printf("AddTensor host time = %f us, tecoal time : %f us\n", htime, stime);

    // Copy the result back to host
    sdaaMemcpy(C, d_c, c_size, sdaaMemcpyDeviceToHost);

    // Compare the computed tensor C with the true tensor C to validate the result
    compare_data_f16("C", (half_t *)C, (half_t *)true_c, num);

    // Free device memory
    sdaaFree(d_a);
    sdaaFree(d_c);

    // Destroy the Tecoal handle
    tecoalDestroy(handle);

    // Destroy tensor descriptor for A, C
    tecoalDestroyTensorDescriptor(aDesc);
    tecoalDestroyTensorDescriptor(cDesc);

    // Free host memory
    free(A);
    free(C);
    free(true_c);

    // Destroy the SDAA stream
    sdaaStreamDestroy(stream);
    return 0;
}
