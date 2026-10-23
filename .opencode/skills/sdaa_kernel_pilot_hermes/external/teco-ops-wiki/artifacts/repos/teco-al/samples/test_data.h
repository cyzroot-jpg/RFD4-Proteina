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

#ifndef SAMPLES_TEST_DATA_H_
#define SAMPLES_TEST_DATA_H_

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <cstdio>
#include "samples/test_half.h"

#if defined(__cplusplus)
extern "C" {
#endif

#define TEST_DATA_FLOAT (0)
#define TEST_DATA_HALF (1)
#define TEST_DATA_INT8 (2)
#define TEST_DATA_INT16 (3)
#define TEST_DATA_INT32 (4)
#define TEST_DATA_DOUBLE (5)

static void rand_data_f32(float *data, int num, float min, float max);
static void rand_data_f16(half_t *data, int num, float min, float max);
static void rand_data_int32(int32_t *data, int num, float min, float max);
static void rand_data(void *data, int num, float min, float max, unsigned type);

#define NUM_IN_SAME_LINE 8
static void print_data_f32(const char *data_name, float *data, int num);
static void print_data_f16(const char *data_name, half_t *data, int num);
static void print_data_int32(const char *data_name, int32_t *data, int num);
static void print_data(const char *data_name, void *data, int num, unsigned type);

#define ERROR_SIZE (1e-5)
#define REAL_ERROR_SIZE (1e-4)

#define HALF_ERROR_SIZE (1e-5)
#define HALF_REAL_ERROR_SIZE (3e-2)
#define PRINT_MAX_FAULT_COUNT 32
static void compare_data_f32(const char *data_name, float *data, float *true_data, int num);
static void compare_data_f16(const char *data_name, half_t *data, half_t *true_data, int num);
static void compare_data_int32(const char *data_name, int32_t *data, int32_t *true_data, int num);
static void compare_data(const char *data_name, void *data, void *true_data, int num,
                         unsigned type);
static void compare_data_f16_f32(const char *data_name, half_t *data, float *true_data, int num);

// ####################################################################
size_t size_of_dataType(unsigned dataType) {
    switch (dataType) {
        case TEST_DATA_FLOAT: return (sizeof(float));
        case TEST_DATA_HALF: return (2);
        case TEST_DATA_INT32: return (sizeof(int32_t));
        case TEST_DATA_INT8: return (sizeof(int8_t));
        case TEST_DATA_INT16: return (sizeof(int16_t));
        default: printf("error data type len, and use default float.\n"); return (sizeof(float));
    }
}

static void generate_seed(void) {
    static int seed_flag = 0;
    if (!seed_flag) {
        srand((unsigned)time(NULL));
        seed_flag++;
    }
}

static float rand_in_range(float min, float max) {
    if (fabs(max - min) < 1e-5) return min;
    return ((max - min) * (rand() / (float)RAND_MAX) + min);
}

static void rand_data(void *data, int num, float min, float max, unsigned type) {
    generate_seed();
    switch (type) {
        case TEST_DATA_FLOAT:
            // float
            for (int i = 0; i < num; i++) ((float *)data)[i] = rand_in_range(min, max);
            break;
        case TEST_DATA_DOUBLE:
            // float
            for (int i = 0; i < num; i++) ((double *)data)[i] = (double)rand_in_range(min, max);
            break;
        case TEST_DATA_HALF:
            // half
            for (int i = 0; i < num; i++)
                ((half_t *)data)[i] = __float2half(rand_in_range(min, max));
            break;
        case TEST_DATA_INT32:
            // int32
            for (int i = 0; i < num; i++) ((int32_t *)data)[i] = (int32_t)(rand_in_range(min, max));
            break;
        case TEST_DATA_INT8:
            // int8
            for (int i = 0; i < num; i++) ((int8_t *)data)[i] = (int8_t)(rand_in_range(min, max));
            break;
        case TEST_DATA_INT16:
            // int16
            for (int i = 0; i < num; i++) ((int16_t *)data)[i] = (int16_t)(rand_in_range(min, max));
            break;
        default: printf("rand_data not support type %d\n", type);
    }
}

static void rand_data_f32(float *data, int num, float min, float max) {
    rand_data((void *)data, num, min, max, TEST_DATA_FLOAT);
}

static void rand_data_f64(double *data, int num, float min, float max) {
    rand_data((void *)data, num, min, max, TEST_DATA_DOUBLE);
}

static void rand_data_f16(half_t *data, int num, float min, float max) {
    rand_data((void *)data, num, min, max, TEST_DATA_HALF);
}

static void rand_data_int32(int32_t *data, int num, float min, float max) {
    rand_data((void *)data, num, min, max, TEST_DATA_INT32);
}

//=========================================
static void print_data_value(void *data, unsigned index, unsigned type) {
    switch (type) {
        case TEST_DATA_FLOAT:
            // float
            printf("%f", ((float *)data)[index]);
            break;
        case TEST_DATA_HALF:
            // half
            printf("%f", __half2float(((half_t *)data)[index]));
            break;
        case TEST_DATA_INT32:
            // int32
            printf("%d", ((int32_t *)data)[index]);
            break;
        case TEST_DATA_INT8:
            // int8
            printf("%d", (int)(((int8_t *)data)[index]));
            break;
        case TEST_DATA_INT16:
            // int16
            printf("%d", (int)(((int16_t *)data)[index]));
            break;
        default: printf("prit_ceil_value not support type %d\n", type);
    }
}

static void print_data(const char *data_name, void *data, int num, unsigned type) {
    printf("%s(%d):\n", data_name, num);
    for (int i = 0; i < num; i += NUM_IN_SAME_LINE) {
        for (int index = i; (index < i + NUM_IN_SAME_LINE) && (index < num); index++) {
            printf(" ");  // printf("\t");
            print_data_value(data, index, type);
        }
        printf("\n");
    }
}

static void print_data_f32(const char *data_name, float *data, int num) {
    print_data(data_name, (void *)data, num, TEST_DATA_FLOAT);
}

static void print_data_f16(const char *data_name, half_t *data, int num) {
    print_data(data_name, (void *)data, num, TEST_DATA_HALF);
}

static void print_data_int32(const char *data_name, int32_t *data, int num) {
    print_data(data_name, (void *)data, num, TEST_DATA_INT32);
}

//=========================================
static int print_err_flag = 1;  // use for print err data in compare_data_value()
static int compare_data_value(void *data, void *true_data, unsigned index, unsigned type) {
    float data_f32, true_data_f32;
    float err_size, real_err_size;
    float err, real_err;
    switch (type) {
        case TEST_DATA_FLOAT:
            // float
            data_f32 = ((float *)data)[index];
            true_data_f32 = ((float *)true_data)[index];
            err_size = ERROR_SIZE;
            real_err_size = REAL_ERROR_SIZE;
            break;
        case TEST_DATA_DOUBLE:
            // double
            data_f32 = ((double *)data)[index];
            true_data_f32 = ((double *)true_data)[index];
            err_size = ERROR_SIZE;
            real_err_size = REAL_ERROR_SIZE;
            break;
        case TEST_DATA_HALF:
            // half
            data_f32 = __half2float(((half_t *)data)[index]);
            true_data_f32 = __half2float(((half_t *)true_data)[index]);
            err_size = HALF_ERROR_SIZE;
            real_err_size = HALF_REAL_ERROR_SIZE;
            break;
        case TEST_DATA_INT32:
            // int32
            data_f32 = (float)((int32_t *)data)[index];
            true_data_f32 = (float)((int32_t *)true_data)[index];
            err_size = ERROR_SIZE;
            real_err_size = REAL_ERROR_SIZE;
            break;
        case TEST_DATA_INT8:
            // int8
            data_f32 = (float)((int8_t *)data)[index];
            true_data_f32 = (float)((int8_t *)true_data)[index];
            err_size = ERROR_SIZE;
            real_err_size = REAL_ERROR_SIZE;
            break;
        case TEST_DATA_INT16:
            // int16
            data_f32 = (float)((int16_t *)data)[index];
            true_data_f32 = (float)((int16_t *)true_data)[index];
            err_size = ERROR_SIZE;
            real_err_size = REAL_ERROR_SIZE;
            break;
        default: printf("compare_data_value not support type %d\n", type);
    }

    if (!isfinite(true_data_f32)) {
        if (print_err_flag)
            printf("index %d, compareData %.6f, trueData %.6f\n", index, data_f32, true_data_f32);
        return 2;
    }

    err = fabs(data_f32 - true_data_f32);
    real_err = err / (fabs(true_data_f32) < 1e-5 ? 1 : fabs(true_data_f32));
    if (err > err_size && real_err > real_err_size) {
        if (print_err_flag)
            printf("index %d, compareData %.6f, trueData %.6f\n", index, data_f32, true_data_f32);
        return 1;
    }

    return 0;
}

static void compare_data(const char *data_name, void *data, void *true_data, int num,
                         unsigned type) {
    printf("%s(%d):\n", data_name, num);
    int fault_num = 0;
    int print_err_flag_bak = print_err_flag;
    print_err_flag = 1;
    for (int i = 0; i < num; i++) {
        if (compare_data_value(data, true_data, i, type)) {
            fault_num++;
            if (fault_num > PRINT_MAX_FAULT_COUNT) print_err_flag = 0;
        }
    }

    float success_rate = 1.0f - fault_num / (float)num;
    printf("%s success rate %.2f , faultNum %d\n", data_name, success_rate, fault_num);
    fflush(NULL);
    print_err_flag = print_err_flag_bak;
}

static float get_success_rate(const char *data_name, void *data, void *true_data, int num,
                              unsigned type) {
    printf("%s(%d):\n", data_name, num);
    int fault_num = 0;
    int print_err_flag_bak = print_err_flag;
    print_err_flag = 1;
    for (int i = 0; i < num; i++) {
        if (compare_data_value(data, true_data, i, type)) {
            fault_num++;
            if (fault_num > PRINT_MAX_FAULT_COUNT) print_err_flag = 0;
        }
    }
    float success_rate = 1.0f - fault_num / (float)num;
    printf("%s success rate %.2f , faultNum %d\n", data_name, success_rate, fault_num);
    // fflush(NULL);
    print_err_flag = print_err_flag_bak;
    printf("fds(%d):\n", num);
    return success_rate;
}

static void compare_data_f32(const char *data_name, float *data, float *true_data, int num) {
    compare_data(data_name, (void *)data, (void *)true_data, num, 0);
}

static void compare_data_f64(const char *data_name, double *data, double *true_data, int num) {
    compare_data(data_name, (void *)data, (void *)true_data, num, TEST_DATA_DOUBLE);
}

static void compare_data_f16(const char *data_name, half_t *data, half_t *true_data, int num) {
    compare_data(data_name, (void *)data, (void *)true_data, num, 1);
}

static void compare_data_int32(const char *data_name, int32_t *data, int32_t *true_data, int num) {
    compare_data(data_name, (void *)data, (void *)true_data, num, TEST_DATA_INT32);
}

static void compare_data_f16_f32(const char *data_name, half_t *data, float *true_data, int num) {
    void *data_f32 = malloc(num * sizeof(float));
    transform_data_h2f(data_f32, data_f32, num);
    compare_data_f32(data_name, (float *)data, true_data, num);
    free(data_f32);
}

float compare_data_f32_batch(const char *data_name, float *data[], float *true_data[],
                             int batchcount, int num) {
    float *success_rate = (float *)malloc(batchcount * sizeof(float));
    for (int i = 0; i < batchcount; i++) {
        success_rate[i] = get_success_rate(data_name, (void *)data[i], (void *)true_data[i], num,
                                           TEST_DATA_FLOAT);
    }
    float tmp = 0.0f;
    float success = 0.0f;

    for (int i = 0; i < batchcount; i++) {
        tmp = tmp + success_rate[i];
    }

    free(success_rate);

    success = tmp / batchcount;
    printf("%f", success);

    return success;
}
float compare_data_f16_batch(const char *data_name, half_t *data[], half_t *true_data[],
                             int batchcount, int num) {
    float *success_rate = (float *)malloc(batchcount * sizeof(float));
    for (int i = 0; i < batchcount; i++) {
        success_rate[i] =
            get_success_rate(data_name, (void *)data[i], (void *)true_data[i], num, TEST_DATA_HALF);
    }

    float tmp = 0.0f;
    float success = 0.0f;

    for (int i = 0; i < batchcount; i++) {
        tmp = tmp + success_rate[i];
    }

    free(success_rate);

    success = tmp / batchcount;

    return success;
}

#if defined(__cplusplus)
}
#endif

#endif  // SAMPLES_TEST_DATA_H_
