#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <simd.h>

#include "sdaa_runtime.h"
#include "rt.h"
#include "../common/test_data.h"
#include "../common/torch_io.h"

/* ================================================================
 *  Device Kernel — 全局常量（仅 kernel 引用的放这里）
 * ================================================================ */

constexpr int TILE_ELEMS = 1024;

/* ================================================================
 *  Device Kernel — SIMD 计算循环封装为 __device__ 函数
 *  规则：涉及 simd_load / simd_store / batch_* / reduce_* 的向量化
 *  循环必须抽成 device 函数，禁止裸写在 global 里
 * ================================================================ */

static __device__ inline __attribute__((always_inline)) void
vec_add_impl(const float *a, const float *b, float *c, int n) {
    floatv16 va, vb, vc;
    const int aligned = n / 16 * 16;
    for (int i = 0; i < aligned; i += 16) {
        simd_load(va, a + i);
        simd_load(vb, b + i);
        vc = va + vb;
        simd_store(vc, c + i);
    }
    for (int i = aligned; i < n; i++) {
        c[i] = a[i] + b[i];
    }
}

/* ================================================================
 *  Device Kernel — global 函数，负责 LDM/DMA/ACE/流水编排
 *  禁止：args struct / namespace / 在 global 里裸写 simd 循环
 *  - simd 循环 → 必须抽成 __device__ 函数
 *  - ACE 调用 → 直接写在 global 里（涉及 DMA/sync/writeback，属于编排）
 * ================================================================ */

__global__ void teco_slave_<op_name>(
    int slave_core_num, int n, const void *a, const void *b, void *c)
{
    const int tid = _PEN;
    if (tid >= slave_core_num) return;

    const float *a_f = (const float *)a;
    const float *b_f = (const float *)b;
    float *c_f = (float *)c;

    // 1. 分片
    const int tile_elems = (n + slave_core_num - 1) / slave_core_num;
    const int start = tid * tile_elems;
    if (start >= n) return;
    const int cur = (start + tile_elems <= n) ? tile_elems : (n - start);

    // 2. LDM 分配
    const int tile_bytes = cur * sizeof(float);
    float *a_tile = (float *)rt_ldm_malloc(tile_bytes);
    float *b_tile = (float *)rt_ldm_malloc(tile_bytes);
    float *c_tile = (float *)rt_ldm_malloc(tile_bytes);
    if (!a_tile || !b_tile || !c_tile) {
        if (a_tile) rt_ldm_free(a_tile);
        if (b_tile) rt_ldm_free(b_tile);
        if (c_tile) rt_ldm_free(c_tile);
        return;
    }

    // 3. DMA 加载
    rt_dma_get(a_tile, (void *)(a_f + start), tile_bytes);
    rt_dma_get(b_tile, (void *)(b_f + start), tile_bytes);

    // 4. 调用 SIMD device 函数
    vec_add_impl(a_tile, b_tile, c_tile, cur);

    // 5. DMA 写回
    rt_dma_put((void *)(c_f + start), c_tile, tile_bytes);

    // 6. 释放 LDM
    rt_ldm_free(c_tile);
    rt_ldm_free(b_tile);
    rt_ldm_free(a_tile);
}

/* ================================================================
 *  Host Test Driver — torch I/O 模式
 *  从 SDAA_TORCH_DATA_DIR 读取输入 → 跑 kernel → 写 device_out.bin
 *  torch_verify.py 负责 PyTorch golden 生成与最终对比
 * ================================================================ */

int <op_name>_test_kernel(void) {
    const char *data_dir = torch_data_dir();
    if (!data_dir) {
        printf("SDAA_TORCH_DATA_DIR not set\n");
        return 1;
    }

    constexpr int N = 8192;
    const size_t num = (size_t)N;

    float *h_a = (float *)malloc(num * sizeof(float));
    float *h_b = (float *)malloc(num * sizeof(float));
    float *h_c = (float *)malloc(num * sizeof(float));
    if (!h_a || !h_b || !h_c) {
        printf("host malloc failed\n");
        free(h_a); free(h_b); free(h_c);
        return 1;
    }

    if (torch_load_f32(data_dir, "a.bin", h_a, num) != 0) goto cleanup;
    if (torch_load_f32(data_dir, "b.bin", h_b, num) != 0) goto cleanup;

    void *d_a = nullptr;
    void *d_b = nullptr;
    void *d_c = nullptr;
    sdaaMalloc(&d_a, num * sizeof(float));
    sdaaMalloc(&d_b, num * sizeof(float));
    sdaaMalloc(&d_c, num * sizeof(float));
    sdaaMemcpy(d_a, h_a, num * sizeof(float), sdaaMemcpyHostToDevice);
    sdaaMemcpy(d_b, h_b, num * sizeof(float), sdaaMemcpyHostToDevice);
    sdaaMemset(d_c, 0, num * sizeof(float));

    teco_slave_<op_name><<<1>>>(32, N, d_a, d_b, d_c);
    sdaaDeviceSynchronize();

    sdaaMemcpy(h_c, d_c, num * sizeof(float), sdaaMemcpyDeviceToHost);

    torch_save_f32(data_dir, "device_out.bin", h_c, num);

    if (d_c) sdaaFree(d_c);
    if (d_b) sdaaFree(d_b);
    if (d_a) sdaaFree(d_a);
cleanup:
    free(h_c); free(h_b); free(h_a);
    return 0;
}