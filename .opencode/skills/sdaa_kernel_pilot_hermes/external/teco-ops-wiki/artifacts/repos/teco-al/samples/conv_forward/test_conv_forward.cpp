#include <stdio.h>
#include <sdaa_runtime.h>
#include <cstdio>
#include <stdexcept>
#include "interface/include/tecoal.h"
#include "samples/test_data.h"

static void test_hconvf(void *x_h, void *w_h, void *y_h, int N, int H, int W, int C, int R, int S,
                        int M, int E, int F, int PH, int PW, int SH, int SW, int DH, int DW, int DR,
                        int DS) {
// Macros for accessing input, weight, and output data in a linear array format.
// These macros calculate the index based on dimensions and strides.
#define IDX(n, h, w, c) ((((n)*H + h) * W + w) * C + c)
#define IW(c, r, s, m) ((((c)*R + r) * S + s) * M + m)
#define IDY(n, e, f, m) ((((n)*E + e) * F + f) * M + m)

    // Perform the convolution operation on the CPU for verification.
    for (int n = 0; n < N; ++n) {
        for (int e = 0; e < E; ++e) {
            for (int f = 0; f < F; ++f) {
                for (int m = 0; m < M; ++m) {
                    float tmp = 0.0f;
                    for (int r = 0; r < DR; r += DH) {
                        for (int s = 0; s < DS; s += DW) {
                            int real_h = e * SH + r - PH;
                            int real_w = f * SW + s - PW;
                            if (real_h >= 0 && real_h < H && real_w >= 0 && real_w < W) {
                                int real_r = r / DH;
                                int real_s = s / DW;
                                for (int c = 0; c < C; ++c) {
                                    tmp +=
                                        __half2float(((half_t *)x_h)[IDX(n, real_h, real_w, c)]) *
                                        __half2float(((half_t *)w_h)[IW(c, real_r, real_s, m)]);
                                }
                            }
                        }
                    }
                    ((half_t *)y_h)[IDY(n, e, f, m)] = __float2half(tmp);
                }
            }
        }
    }
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
    // Verify the correct number of arguments are passed
    if (argc < 3) {
        printf("The executable file parameter is incorrect\n");
        return -1;
    }

    // Set parameters for the convolution.
    const int N = 200;
    const int H = 16;
    const int W = 16;
    const int C = 96;
    const int R = 1;
    const int S = 1;
    const int M = 96;
    const int E = 16;
    const int F = 16;
    const int pad_h = 0;
    const int pad_w = 0;
    const int stride_h = 1;
    const int stride_w = 1;
    const int dilation_h = 1;
    const int dilation_w = 1;
    const int warm_time = 5;
    const int perf_time = 10;
    // Declare variables for the sizes of input, weight, and output data.
    int num_x, num_w, num_y;
    num_x = N * H * W * C;
    num_w = C * R * S * M;
    num_y = N * E * F * M;

    int device_id = atoi(argv[1]);

    // Convert command-line argument to a tecoal algorithm type.
    tecoalAlgo_t algo = convertArgsToAlgo(atoi(argv[2]));

    // Create a tecoal handle for managing the convolution operation.
    tecoalHandle_t handle;
    tecoalCreate(&handle);

    // Declare pointers for data on both host and device.
    void *x_h, *w_h, *y_h_cpu, *y_h_gpu, *x_d, *w_d, *y_d;

    sdaaSetDevice(device_id);

    // Allocate memory on the host for input, weight, and output data.
    x_h = malloc(num_x * sizeof(half_t));
    w_h = malloc(num_w * sizeof(half_t));
    y_h_cpu = malloc(num_y * sizeof(half_t));
    y_h_gpu = malloc(num_y * sizeof(half_t));

    // Initialize input and weight data with random numbers.
    rand_data_f16((half_t *)x_h, num_x, 0, 1);
    rand_data_f16((half_t *)w_h, num_w, 0, 1);

    // Allocate memory on the device for input, weight, and output data.
    sdaaMalloc(&x_d, num_x * sizeof(half_t));
    sdaaMalloc(&w_d, num_w * sizeof(half_t));
    sdaaMalloc(&y_d, num_y * sizeof(half_t));

    // Copy input and weight data from host to device.
    sdaaMemcpy(x_d, x_h, num_x * sizeof(half_t), sdaaMemcpyHostToDevice);
    sdaaMemcpy(w_d, w_h, num_w * sizeof(half_t), sdaaMemcpyHostToDevice);

    // Timing mechanism for the serial (CPU) implementation.
    float htime = 0, stime = 0;
    sdaaEvent_t start, end;
    sdaaEventCreate(&start);
    sdaaEventCreate(&end);
    sdaaStream_t stream;
    sdaaStreamCreate(&stream);
    tecoalSetStream(handle, stream);

    printf("ConvForward host start\n");
    sdaaStreamSynchronize(stream);
    // Start the timer for the serial CPU convolution computation.
    sdaaEventRecord(start, stream);
    test_hconvf(x_h, w_h, y_h_cpu, N, H, W, C, R, S, M, E, F, pad_h, pad_w, stride_h, stride_w,
                dilation_h, dilation_w, (dilation_h - 1) * (R - 1) + R,
                (dilation_w - 1) * (S - 1) + S);
    // Stop the timer and calculate the elapsed time for the CPU computation.
    sdaaEventRecord(end, stream);
    sdaaEventSynchronize(end);
    sdaaEventElapsedTime(&htime, start, end);
    printf("ConvForward host end\n");

    printf("begin kernel run\n");

    float alpha = 1.0;
    float beta = 0;

    // Create tensor, filter, and convolution descriptors.
    tecoalTensorDescriptor_t xDesc, yDesc;
    tecoalFilterDescriptor_t wDesc;
    tecoalConvolutionDescriptor_t convDesc;
    tecoalCreateTensorDescriptor(&xDesc);
    tecoalCreateTensorDescriptor(&yDesc);
    tecoalCreateFilterDescriptor(&wDesc);
    tecoalCreateConvolutionDescriptor(&convDesc);

    // Set descriptors with dimensions, padding, stride, and dilation.
    tecoalSetTensor4dDescriptor(xDesc, TECOAL_TENSOR_NHWC, TECOAL_DATA_HALF, N, C, H, W);
    tecoalSetFilter4dDescriptor(wDesc, TECOAL_DATA_HALF, TECOAL_TENSOR_CHWN, M, C, R, S);
    tecoalSetTensor4dDescriptor(yDesc, TECOAL_TENSOR_NHWC, TECOAL_DATA_HALF, N, M, E, F);
    tecoalSetConvolution2dDescriptor(convDesc, pad_h, pad_w, stride_h, stride_w, dilation_h,
                                     dilation_w, TECOAL_CROSS_CORRELATION, TECOAL_DATA_HALF);

    printf("tecoalConvForward start\n");
    // Determine the required workspace size for the convolution operation.
    size_t workSpaceSizeInBytes = 0;
    tecoalGetConvolutionForwardWorkspaceSize(handle, xDesc, wDesc, convDesc, yDesc, TECOAL_ALGO_0,
                                             &workSpaceSizeInBytes);
    void *workSpace;
    sdaaMalloc(&workSpace, workSpaceSizeInBytes);
    // Perform the convolution operation on the GPU using tecoal.
    // warm_up
    for (int i = 0; i < warm_time; ++i) {
        tecoalConvolutionForward(handle, &alpha, xDesc, x_d, wDesc, w_d, convDesc, algo, workSpace,
                                 workSpaceSizeInBytes, &beta, yDesc, y_d);
    }
    // Start the timer
    sdaaEventRecord(start, stream);
    for (int i = 0; i < perf_time; ++i) {
        tecoalConvolutionForward(handle, &alpha, xDesc, x_d, wDesc, w_d, convDesc, algo, workSpace,
                                 workSpaceSizeInBytes, &beta, yDesc, y_d);
    }
    sdaaEventRecord(end, stream);
    sdaaEventSynchronize(end);
    sdaaEventElapsedTime(&stime, start, end);
    stime /= perf_time;
    printf("tecoalConvForward end\n");
    printf("tecoalConvForward host time = %f us, tecoal time = %f us\n", (float)htime * 1e3,
           (float)stime * 1e3);

    sdaaFree(workSpace);

    // Copy the result from the device to the host for comparison.
    sdaaMemcpy(y_h_gpu, y_d, num_y * sizeof(half_t), sdaaMemcpyDeviceToHost);

    // Compare the GPU and CPU results to verify correctness.
    compare_data_f16("conv output data", (half_t *)y_h_gpu, (half_t *)y_h_cpu, num_y);

    // Cleanup: Free all resources.
    free(x_h);
    free(w_h);
    free(y_h_cpu);
    free(y_h_gpu);
    sdaaFree(x_d);
    sdaaFree(w_d);
    sdaaFree(y_d);
    tecoalDestroyTensorDescriptor(xDesc);
    tecoalDestroyTensorDescriptor(yDesc);
    tecoalDestroyFilterDescriptor(wDesc);
    tecoalDestroyConvolutionDescriptor(convDesc);
    tecoalDestroy(handle);

    return 0;
}
