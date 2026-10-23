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

#ifndef UAL_KERNEL_DEVICE_HPP_
#define UAL_KERNEL_DEVICE_HPP_

// For batch_s2h、batch_h2s function
// load func and store func is aligned or unaligned simd function
// op_func is the operation function, such as simd_vfadds, simd_vfaddh

#define __align_batch(type_1, type_2, vec_type_1, vec_type_2, x, y, len, load_func, store_func, \
                      op_func)                                                                  \
    {                                                                                           \
        vec_type_1 vx0, vx1, vx2, vx3, vx4, vx5, vx6, vx7;                                      \
        vec_type_2 vy0, vy1, vy2, vy3, vy4, vy5, vy6, vy7;                                      \
        int __i = 0;                                                                            \
        type_1 *px = (type_1 *)(x);                                                             \
        type_2 *py = (type_2 *)(y);                                                             \
        for (__i = 0; __i <= len - 128; __i += 128) {                                           \
            load_func(vx0, px);                                                                 \
            load_func(vx1, px + 16);                                                            \
            load_func(vx2, px + 32);                                                            \
            load_func(vx3, px + 48);                                                            \
            load_func(vx4, px + 64);                                                            \
            load_func(vx5, px + 80);                                                            \
            load_func(vx6, px + 96);                                                            \
            load_func(vx7, px + 112);                                                           \
                                                                                                \
            vy0 = op_func(vx0);                                                                 \
            vy1 = op_func(vx1);                                                                 \
            vy2 = op_func(vx2);                                                                 \
            vy3 = op_func(vx3);                                                                 \
            vy4 = op_func(vx4);                                                                 \
            vy5 = op_func(vx5);                                                                 \
            vy6 = op_func(vx6);                                                                 \
            vy7 = op_func(vx7);                                                                 \
                                                                                                \
            store_func(vy0, py);                                                                \
            store_func(vy1, py + 16);                                                           \
            store_func(vy2, py + 32);                                                           \
            store_func(vy3, py + 48);                                                           \
            store_func(vy4, py + 64);                                                           \
            store_func(vy5, py + 80);                                                           \
            store_func(vy6, py + 96);                                                           \
            store_func(vy7, py + 112);                                                          \
                                                                                                \
            px += 128;                                                                          \
            py += 128;                                                                          \
        }                                                                                       \
                                                                                                \
        for (; __i <= len - 64; __i += 64) {                                                    \
            load_func(vx0, px);                                                                 \
            load_func(vx1, px + 16);                                                            \
            load_func(vx2, px + 32);                                                            \
            load_func(vx3, px + 48);                                                            \
                                                                                                \
            vy0 = op_func(vx0);                                                                 \
            vy1 = op_func(vx1);                                                                 \
            vy2 = op_func(vx2);                                                                 \
            vy3 = op_func(vx3);                                                                 \
                                                                                                \
            store_func(vy0, py);                                                                \
            store_func(vy1, py + 16);                                                           \
            store_func(vy2, py + 32);                                                           \
            store_func(vy3, py + 48);                                                           \
                                                                                                \
            px += 64;                                                                           \
            py += 64;                                                                           \
        }                                                                                       \
                                                                                                \
        for (; __i <= len - 16; __i += 16) {                                                    \
            load_func(vx0, px);                                                                 \
            vy0 = op_func(vx0);                                                                 \
            store_func(vy0, py);                                                                \
                                                                                                \
            px += 16;                                                                           \
            py += 16;                                                                           \
        }                                                                                       \
                                                                                                \
        for (; __i < len; __i++) {                                                              \
            *py = *px;                                                                          \
            px++;                                                                               \
            py++;                                                                               \
        }                                                                                       \
    }

#define __batch_unary_ops(name, type_1, type_2, vec_type_1, vec_type_2, op_func)                  \
    static __device__ inline __attribute__((always_inline)) void name(const type_1 *x, type_2 *y, \
                                                                      int len) {                  \
        if (len < 32) {                                                                           \
            for (int i = 0; i < len; i++) {                                                       \
                y[i] = x[i];                                                                      \
            }                                                                                     \
            return;                                                                               \
        }                                                                                         \
        const int align_n1 = sizeof(vec_type_1);                                                  \
        const int align_n2 = sizeof(vec_type_2);                                                  \
        if (((((size_t)x) & (align_n1 - 1)) == 0) && ((((size_t)y) & (align_n2 - 1)) == 0)) {     \
            __align_batch(type_1, type_2, vec_type_1, vec_type_2, x, y, len, simd_load,           \
                          simd_store, op_func);                                                   \
            return;                                                                               \
        } else {                                                                                  \
            int padding_x = ((size_t)(x) & (align_n1 - 1)) / sizeof(type_1);                      \
            int padding_y = ((size_t)(y) & (align_n2 - 1)) / sizeof(type_2);                      \
            if (padding_x == padding_y) {                                                         \
                for (int i = 0; i < 16 - padding_x; i++) {                                        \
                    y[i] = x[i];                                                                  \
                }                                                                                 \
                __align_batch(type_1, type_2, vec_type_1, vec_type_2, x + 16 - padding_x,         \
                              y + 16 - padding_y, len - 16 + padding_x, simd_load, simd_store,    \
                              op_func);                                                           \
                return;                                                                           \
            } else {                                                                              \
                __align_batch(type_1, type_2, vec_type_1, vec_type_2, x, y, len, simd_loadu,      \
                              simd_storeu, op_func);                                              \
                return;                                                                           \
            }                                                                                     \
        }                                                                                         \
    }

__batch_unary_ops(batch_S2H, float, half, floatv16, float16v16, simd_vfcvtsh);
__batch_unary_ops(batch_H2S, half, float, float16v16, floatv16, simd_vfcvths);

#undef __align_batch
#undef __batch_unary_ops

#define is_aligned(x, alignment) (((size_t)(x) & ((alignment)-1)) == 0)

#define unroll_dot(load_func_a, load_func_b, type, type_v) \
    do {                                                   \
        type *px1 = (type *)x1;                            \
        type *px2 = (type *)x2;                            \
        i = 0;                                             \
        int up;                                            \
        type_v a0, a1, a2, a3;                             \
        type_v b0, b1, b2, b3;                             \
        up = len - 64;                                     \
        for (; i <= up; i += 64) {                         \
            load_func_a(a0, px1 + 0);                      \
            load_func_a(a1, px1 + 16);                     \
            load_func_a(a2, px1 + 32);                     \
            load_func_a(a3, px1 + 48);                     \
            load_func_b(b0, px2 + 0);                      \
            load_func_b(b1, px2 + 16);                     \
            load_func_b(b2, px2 + 32);                     \
            load_func_b(b3, px2 + 48);                     \
            ans_v0 += a0 * b0;                             \
            ans_v1 += a1 * b1;                             \
            ans_v2 += a2 * b2;                             \
            ans_v3 += a3 * b3;                             \
            px1 += 64;                                     \
            px2 += 64;                                     \
        }                                                  \
        up = len - 16;                                     \
        for (; i <= up; i += 16) {                         \
            load_func_a(a0, px1 + 0);                      \
            load_func_b(b0, px2 + 0);                      \
            ans_v0 += a0 * b0;                             \
            px1 += 16;                                     \
            px2 += 16;                                     \
        }                                                  \
        ans_v0 += ans_v1;                                  \
        ans_v2 += ans_v3;                                  \
        ans_v0 += ans_v2;                                  \
    } while (0)

#define function_dot(func_name, type, type_v)                                               \
    static __device__ void func_name(const type *x1, const type *x2, int len, float *ans) { \
        int i = 0;                                                                          \
        type_v ans_v0 = 0, ans_v1 = 0, ans_v2 = 0, ans_v3 = 0;                              \
        int align1 = is_aligned(x1, sizeof(type_v));                                        \
        int align2 = is_aligned(x2, sizeof(type_v));                                        \
        if (align1) {                                                                       \
            if (align2)                                                                     \
                unroll_dot(simd_load, simd_load, type, type_v);                             \
            else                                                                            \
                unroll_dot(simd_load, simd_loadu, type, type_v);                            \
        } else {                                                                            \
            if (align2)                                                                     \
                unroll_dot(simd_loadu, simd_load, type, type_v);                            \
            else                                                                            \
                unroll_dot(simd_loadu, simd_loadu, type, type_v);                           \
        }                                                                                   \
                                                                                            \
        float tans = 0;                                                                     \
        floatv16 f_ans_v0;                                                                  \
        f_ans_v0 = ans_v0;                                                                  \
        for (int k = 0; k < 16; ++k) {                                                      \
            tans += ((float *)&f_ans_v0)[k];                                                \
        }                                                                                   \
        for (; i < len; ++i) {                                                              \
            tans += x1[i] * x2[i];                                                          \
        }                                                                                   \
        *ans = tans;                                                                        \
    }

function_dot(reduce_Sdot, float, floatv16);
function_dot(reduce_Hdot, half, float16v16);

#endif  // UAL_KERNEL_DEVICE_HPP_
