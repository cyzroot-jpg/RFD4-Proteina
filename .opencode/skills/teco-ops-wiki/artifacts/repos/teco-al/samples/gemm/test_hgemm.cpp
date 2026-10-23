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

// Serial version of the host
static void test_hgemm(tecoalOperation_t transa, tecoalOperation_t transb, int M, int N, int K,
                       float alpha, const half_t *A, int lda, const half_t *B, int ldb, float beta,
                       half_t *C, int ldc) {
    float *a_f32, *b_f32, *true_f32;
    if (transa == TECOAL_OP_N && transb == TECOAL_OP_N) {
        a_f32 = (float *)malloc(M * lda * 4);
        b_f32 = (float *)malloc(K * ldb * 4);
        true_f32 = (float *)malloc(M * ldc * 4);
        transform_data_h2f((void *)a_f32, (void *)A, M * lda);
        transform_data_h2f((void *)b_f32, (void *)B, K * ldb);
        transform_data_h2f((void *)true_f32, (void *)C, M * ldc);

        for (int i = 0; i < M; ++i) {
            for (int j = 0; j < N; ++j) {
                float tmp = 0.;
                for (int k = 0; k < K; ++k) {
                    tmp += a_f32[i * lda + k] * b_f32[k * ldb + j];
                }
                true_f32[i * ldc + j] *= beta;
                true_f32[i * ldc + j] += tmp * alpha;
            }
        }
        transform_data_f2h(C, true_f32, M * ldc);
    }
    free(a_f32);
    free(b_f32);
    free(true_f32);
}

static tecoalAlgo_t convertArgsToAlgo(int ver) {
    switch (ver) {
        // join single-core
        case 0: return TECOAL_ALGO_0;
        // join muilt-core
        case 1: return TECOAL_ALGO_1;
        // join DMA
        case 2: return TECOAL_ALGO_2;
        // join simd
        case 3: return TECOAL_ALGO_3;
        // join sdaa c matmul
        case 4: return TECOAL_ALGO_4;
        // join broadcast
        case 5: return TECOAL_ALGO_5;
        // join double buffer
        case 6: return TECOAL_ALGO_6;
        default: {
            throw std::runtime_error("The algo type does not exist!\n");
        }
    }
}

int main(int argc, char *argv[]) {
    // Define matrix dimensions and transposition options
    int m, n, k, ta, tb, a, b, c;

    // Initialize alpha and beta for the matrix operation (GEMM)
    float alpha = 1, beta = 0;

    // Leading dimensions of the matrices
    int lda = 1, ldb = 1, ldc = 1;

    // Number of iterations for timing
    int maxloop = 10;

    // Variables for timing
    float all_time = 0, time = 0;

    // Check for valid number of command-line arguments
    if (argc < 3) {
        printf("The executable file parameter is incorrect\n");
        return -1;
    }

    int device_id = atoi(argv[1]);

    // Convert command-line argument to algorithm type
    tecoalAlgo_t algo = convertArgsToAlgo(atoi(argv[2]));

    // Set dimensions for matrices A (m x k), B (k x n) and C (m x n)
    m = 1024;
    n = 256;
    k = 1024;

    // Set leading dimensions based on matrix dimensions
    lda = k;
    ldb = n;
    ldc = n;

    // No transposition for matrices A and B
    tecoalOperation_t transa = TECOAL_OP_N;
    tecoalOperation_t transb = TECOAL_OP_N;

    // Calculate number of elements in matrices A, B, and C
    int a_num = m * lda;
    int b_num = k * ldb;
    int c_num = m * ldc;

    // Calculate size in bytes of matrices A, B, and C
    int a_size = a_num * sizeof(half_t);
    int b_size = b_num * sizeof(half_t);
    int c_size = c_num * sizeof(half_t);

    // Allocate memory for matrices A, B, C, and a copy of C (true_c)
    void *A, *B, *C, *true_c;
    A = malloc(a_size);
    B = malloc(b_size);
    C = malloc(c_size);
    true_c = malloc(c_size);

    // Initialize matrices A and B with random data, and matrix C with zeros
    rand_data_f16((half_t *)A, a_num, 0, 1);
    rand_data_f16((half_t *)B, b_num, 0, 1);
    rand_data_f16((half_t *)C, c_num, 0, 0);

    // Copy matrix C to true_c for verification
    memcpy(true_c, C, c_size);

    // Initialize the TECOAL handle
    tecoalHandle_t handle;
    tecoalCreate(&handle);
    sdaaSetDevice(device_id);

    // Allocate memory on the device for matrices A, B, and C
    void *d_a, *d_b, *d_c;
    sdaaMalloc((void **)&d_a, a_size);
    sdaaMalloc((void **)&d_b, b_size);
    sdaaMalloc((void **)&d_c, c_size);

    // Copy matrices A, B, and C to the device
    sdaaMemcpy(d_a, A, a_size, sdaaMemcpyHostToDevice);
    sdaaMemcpy(d_b, B, b_size, sdaaMemcpyHostToDevice);
    sdaaMemcpy(d_c, C, c_size, sdaaMemcpyHostToDevice);

    float htime = 0, stime = 0;
    sdaaEvent_t start, end;
    sdaaEventCreate(&start);
    sdaaEventCreate(&end);
    // Create a stream for asynchronous execution
    sdaaStream_t stream;
    sdaaStreamCreate(&stream);
    // Set the stream for the TECOAL operation
    tecoalSetStream(handle, stream);

    // timing host computation
    printf("Hgemm host start\n");
    sdaaStreamSynchronize(stream);
    sdaaEventRecord(start, stream);
    test_hgemm(transa, transb, m, n, k, alpha, (half_t *)A, lda, (half_t *)B, ldb, beta,
               (half_t *)true_c, ldc);
    sdaaEventRecord(end, stream);
    sdaaEventSynchronize(end);
    sdaaEventElapsedTime(&htime, start, end);
    printf("Hgemm host end\n");

    printf("begin kernel run\n");

    printf("tecoalHgemm start\n");

    // warm up
    const int warm_time = 5;
    const int perf_time = 10;
    for (int i = 0; i < warm_time; ++i) {
        tecoalHgemm(handle, transa, transb, m, n, k, alpha, (const void *)d_a, lda,
                    (const void *)d_b, ldb, beta, (void *)d_c, ldc, algo);
    }
    sdaaEventRecord(start, stream);
    // timing kernel computation
    for (int i = 0; i < perf_time; ++i) {
        tecoalHgemm(handle, transa, transb, m, n, k, alpha, (const void *)d_a, lda,
                    (const void *)d_b, ldb, beta, (void *)d_c, ldc, algo);
    }
    sdaaEventRecord(end, stream);
    sdaaEventSynchronize(end);
    sdaaEventElapsedTime(&stime, start, end);
    stime /= perf_time;
    printf("tecoalHgemm end\n");

    // Calculate and print the execution time for both host and device
    printf("tecoalHgemm host time = %f us, tecoal time : %f us\n", (float)htime * 1e3,
           (float)stime * 1e3);

    // Copy the result matrix C from device to host memory
    sdaaMemcpy(C, d_c, c_size, sdaaMemcpyDeviceToHost);

    // Compare the device result with the host result for verification
    compare_data_f16("C", (half_t *)C, (half_t *)true_c, c_num);

    // Free device memory
    sdaaFree(d_a);
    sdaaFree(d_b);
    sdaaFree(d_c);

    // free resources and memory
    tecoalDestroy(handle);
    free(A);
    free(B);
    free(C);
    free(true_c);
    sdaaStreamDestroy(stream);
    return 0;
}
