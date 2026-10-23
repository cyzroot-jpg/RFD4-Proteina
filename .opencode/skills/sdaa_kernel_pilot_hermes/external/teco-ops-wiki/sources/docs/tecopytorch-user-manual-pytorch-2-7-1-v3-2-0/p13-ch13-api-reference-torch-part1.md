---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p13
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第13部分 (ch13-api-reference-torch-part1)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "13228-15000"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, api-reference, torch, operator-support]
---

# TecoPyTorch 用户手册 v3.2.0（第13部分）

> 原文行范围：`13228-15000`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

13. API参考
13.1 原生PyTorch算子类API支持说明
13.1.1 torch

                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._adaptive_avg_pool2d        是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch._adaptive_avg_pool3d        是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._add_batch_dim              是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch._add_relu                   是        int8, int16, int32, int64, float32, float64             无

 torch._add_relu_                  是        int8, int16, int32, int64, float32, float64             无

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch._addmm_activation           是                                                                无
                                            bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch._aminmax                    是                                                                无
                                            float32, bfloat16, float64

 torch._amp_foreach_non_finit
                                   是        float32                                                 无
 e_check_and_unscale_

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._C._has_torch_function      是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch._C._has_torch_function_              bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                                无
 unary                                      int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._copy_from_and_resize       是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch._euclidean_dist             是        float16, float32, bfloat16, float64                     无

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch._foreach_abs                是                                                                无
                                            bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch._foreach_abs_               是                                                                无
                                            bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                             202

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                 API 参考




                                                                                                   限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                   制

 torch._foreach_acos               是        float16, float32, bfloat16, float64                    无

 torch._foreach_acos_              是        float16, float32, bfloat16, float64                    无

 torch._foreach_asin               是        float16, float32, bfloat16, float64                    无

 torch._foreach_asin_              是        float16, float32, bfloat16, float64                    无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._foreach_atan               是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch._foreach_atan_              是        float16, float32, bfloat16, float64                    无

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
 torch._foreach_ceil               是                                                               无
                                            int64, float16, float32, bfloat16, float64

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
 torch._foreach_ceil_              是                                                               无
                                            int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._foreach_cos                是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch._foreach_cos_               是        float16, float32, bfloat16, float64                    无

 torch._foreach_cosh               是        float16, float32, bfloat16, float64                    无

 torch._foreach_cosh_              是        float16, float32, bfloat16, float64                    无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._foreach_erf                是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch._foreach_erf_               是        float16, float32, bfloat16, float64                    无

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
 torch._foreach_erfc               是                                                               无
                                            int64, float16, float32, bfloat16, float64

 torch._foreach_erfc_              是        float16, float32, bfloat16, float64                    无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._foreach_exp                是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch._foreach_exp_               是        float16, float32, bfloat16, float64                    无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._foreach_expm1              是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                            203

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

 torch._foreach_expm1_             是        float16, float32, bfloat16, float64                     无

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
 torch._foreach_floor              是                                                                无
                                            int64, float16, float32, bfloat16, float64

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
 torch._foreach_floor_             是                                                                无
                                            int64, float16, float32, bfloat16, float64

 torch._foreach_frac               是        float16, float32, bfloat16, float64                     无

 torch._foreach_frac_              是        float16, float32, bfloat16, float64                     无

 torch._foreach_lgamma             是        float16, float32, bfloat16, float64                     无

 torch._foreach_lgamma_            是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._foreach_log                是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch._foreach_log_               是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._foreach_log10              是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch._foreach_log10_             是        float16, float32, bfloat16, float64                     无

 torch._foreach_log1p              是        float16, float32, bfloat16, float64                     无

 torch._foreach_log1p_             是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._foreach_log2               是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch._foreach_log2_              是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch._foreach_max                是                                                                无
                                            float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch._foreach_neg                是                                                                无
                                            bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch._foreach_neg_               是                                                                无
                                            bfloat16, float64

 torch._foreach_norm               是        float16, float32, bfloat16, float64                     无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                             204

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                 API 参考




                                                                                                   限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                   制

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._foreach_reciprocal         是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch._foreach_reciprocal_        是        float16, float32, bfloat16, float64                    无

 torch._foreach_round              是        float16, float32, bfloat16, float64                    无

 torch._foreach_round_             是        float16, float32, bfloat16, float64                    无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._foreach_sigmoid            是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch._foreach_sigmoid_           是        float16, float32, bfloat16, float64                    无

                                            bool, int16, int32, int64, float16, float32,
 torch._foreach_sign               是                                                               无
                                            bfloat16, float64

                                            bool, int16, int32, int64, float16, float32,
 torch._foreach_sign_              是                                                               无
                                            bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._foreach_sin                是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch._foreach_sin_               是        float16, float32, bfloat16, float64                    无

 torch._foreach_sinh               是        float16, float32, bfloat16, float64                    无

 torch._foreach_sinh_              是        float16, float32, bfloat16, float64                    无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._foreach_sqrt               是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch._foreach_sqrt_              是        float16, float32, bfloat16, float64                    无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._foreach_tan                是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch._foreach_tan_               是        float16, float32, bfloat16, float64                    无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._foreach_tanh               是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch._foreach_tanh_              是        float16, float32, bfloat16, float64                    无

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
 torch._foreach_trunc              是                                                               无
                                            int64, float16, float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                            205

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                    API 参考




                                                                                                      限
 算子类API名称                           是否支持     支持的数据类型
                                                                                                      制

                                             uint8, uint16, uint32, uint64, int8, int16, int32,
 torch._foreach_trunc_              是                                                                 无
                                             int64, float16, float32, bfloat16, float64

                                             bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._foreach_zero_               是                                                                 无
                                             int32, int64, float16, float32, bfloat16, float64

 torch._has_compatible_shallo                bool, uint8, uint16, uint32, uint64, int8, int16,
                                    是                                                                 无
 w_copy_type                                 int32, int64, float16, float32, bfloat16, float64

                                             bool, uint8, int8, int16, int32, int64, float16,
 torch._prelu_kernel                是                                                                 无
                                             float32, bfloat16, float64

 torch._standard_gamma_gra
                                    是        float16, float32, bfloat16, float64                      无
 d

                                             bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._sym_sqrt                    是                                                                 无
                                             int32, int64, float16, float32, bfloat16, float64

 torch._tensor_str.set_printoptio            bool, uint8, uint16, uint32, uint64, int8, int16,
                                    是                                                                 无
 ns                                          int32, int64, float16, float32, bfloat16, float64

                                             bool, uint8, uint16, uint32, uint64, int8, int16,
 torch._test_functorch_fallback     是                                                                 无
                                             int32, int64, float16, float32, bfloat16, float64

 torch._test_serialization_subc              uint8, int8, int16, int32, int64, float16, float32,
                                    是                                                                 无
 mul                                         bfloat16, float64

 torch._utils_internal.get_file_p            bool, uint8, uint16, uint32, uint64, int8, int16,
                                    是                                                                 无
 ath                                         int32, int64, float16, float32, bfloat16, float64

                                             uint8, int8, int16, int32, int64, float16, float32,
 torch.abs                          是        bfloat16, float64, uint8, int8, int16, int32, int64,     无
                                             float16, float32, bfloat16, float64

                                             bool, uint8, int8, int16, int32, int64, float16,
 torch.add                          是                                                                 无
                                             float32, bfloat16, float64

                                             uint8, int8, int16, int32, int64, float16, float32,
 torch.addbmm                       是                                                                 无
                                             bfloat16, float64

                                             bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.addcdiv                      是                                                                 无
                                             int32, int64, float16, float32, bfloat16, float64

                                             uint8, int8, int16, int32, int64, float16, float32,
 torch.addcmul                      是                                                                 无
                                             bfloat16, float64




文档版本：v3.2.0                         版权所有 © 太初(无锡)电子科技有限公司                                              206

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.addmm                       是                                                                无
                                            bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.addmv                       是                                                                无
                                            bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.addmv_                      是                                                                无
                                            bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.addr                        是                                                                无
                                            float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.affine_grid_generator       是                                                                无
                                            bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.alias_copy                  是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.all                         是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.allclose                    是        int32, int64, float16, float32, bfloat16, float64,      无
                                            float16, float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.alpha_dropout               是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.alpha_dropout_              是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
                                            float32, bfloat16, float64, bool, uint8, int8,
 torch.amax                        是                                                                无
                                            int16, int32, int64, float16, float32, bfloat16,
                                            float64

                                            bool, uint8, int8, int16, int32, int64, float16,
                                            float32, bfloat16, float64, bool, uint8, int8,
 torch.amin                        是                                                                无
                                            int16, int32, int64, float16, float32, bfloat16,
                                            float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.aminmax                     是                                                                无
                                            float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                             207

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

 torch.angle                       是        float32, float64                                        无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.any                         是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.arange                      是                                                                无
                                            bfloat16, float64

 torch.arccos                      是        float16, float32, bfloat16, float64                     无

 torch.arccos_                     是        float16, float32, bfloat16, float64                     无

 torch.arccosh                     是        float16, float32, bfloat16, float64                     无

 torch.arccosh_                    是        float16, float32, bfloat16, float64                     无

 torch.arcsin                      是        float16, float32, bfloat16, float64                     无

 torch.arcsin_                     是        float16, float32, bfloat16, float64                     无

 torch.arcsinh                     是        float16, float32, bfloat16, float64                     无

 torch.arcsinh_                    是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.arctan                      是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.arctan_                     是        float16, float32, bfloat16, float64                     无

 torch.arctan2                     是        float16, float32, bfloat16, float64                     无

 torch.arctanh                     是        float16, float32, bfloat16, float64                     无

 torch.arctanh_                    是        float16, float32, bfloat16, float64                     无

 torch.are_deterministic_algorit            bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                                无
 hms_enabled                                int32, int64, float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.argmax                      是                                                                无
                                            float64, bfloat16

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.argmin                      是                                                                无
                                            float64, bfloat16




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                             208

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                 API 参考




                                                                                                   限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                   制

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64,
 torch.argsort                     是                                                               无
                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64,
 torch.as_strided                  是                                                               无
                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64,
 torch.as_strided_                 是                                                               无
                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.as_strided_copy             是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.as_strided_scatter          是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.as_tensor                   是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.asarray                     是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.asin                        是        float16, float32, bfloat16, float64                    无

 torch.asin_                       是        float16, float32, bfloat16, float64                    无

 torch.asinh                       是        float16, float32, bfloat16, float64                    无

 torch.asinh_                      是        float16, float32, bfloat16, float64                    无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.atan                        是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.atan_                       是        float16, float32, bfloat16, float64                    无

 torch.atan2                       是        float16, float32, bfloat16, float64                    无

 torch.atanh                       是        float16, float32, bfloat16, float64                    无

 torch.atanh_                      是        float16, float32, bfloat16, float64                    无



文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                            209

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                   API 参考




                                                                                                     限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                     制

 torch.autocast_decrement_ne                bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                                 无
 sting                                      int32, int64, float16, float32, bfloat16, float64

 torch.autocast_increment_nes               bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                                 无
 ting                                       int32, int64, float16, float32, bfloat16, float64

 torch.avg_pool1d                  是        int64, float16, float32, bfloat16, float64               无

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.baddbmm                     是                                                                 无
                                            float64

 torch.bartlett_window             是        float16, float32, bfloat16, float64                      无

 torch.batch_norm                  是        float16, float32                                         无

 torch.bernoulli                   是        float16, float32, bfloat16, float64                      无

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.bilinear                    是                                                                 无
                                            bfloat16, float64

 torch.binary_cross_entropy_wi
                                   是        float16, float32, bfloat16, float64                      无
 th_logits

 torch.binomial                    是        float32, float64                                         无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.bitwise_and                 是                                                                 无
                                            int32, int64

 torch.bitwise_left_shift          是        uint8, int8, int16, int32, int64                         无

                                            bool, uint8, int8, int16, int32, int64, bool, uint8,
 torch.bitwise_not                 是                                                                 无
                                            int8, int16, int32, int64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.bitwise_or                  是                                                                 无
                                            int32, int64

 torch.bitwise_right_shift         是        uint8, int8, int16, int32, int64                         无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.bitwise_xor                 是                                                                 无
                                            int32, int64

 torch.blackman_window             是        float16, float32, bfloat16, float64                      无

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.bmm                         是                                                                 无
                                            bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                               210

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.broadcast_to                是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.bucketize                   是                                                                无
                                            bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.can_cast                    是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64,
 torch.cat                         是                                                                无
                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
                                            int64, float16, float32, bfloat16, float64, uint8,
 torch.ceil                        是                                                                无
                                            uint16, uint32, uint64, int8, int16, int32, int64,
                                            float16, float32, bfloat16, float64

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
                                            int64, float16, float32, bfloat16, float64, uint8,
 torch.ceil_                       是                                                                无
                                            uint16, uint32, uint64, int8, int16, int32, int64,
                                            float16, float32, bfloat16, float64

 torch.celu                        是        float16, float32                                        无

 torch.celu_                       是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.channel_shuffle             是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.chunk                       是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.clamp                       是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.clamp_                      是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.clamp_max                   是                                                                无
                                            float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                              211

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.clamp_max_                  是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.clamp_min                   是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.clamp_min_                  是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.clear_autocast_cache        是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.column_stack                是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.combinations                是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.concat                      是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.concatenate                 是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
 torch.cond                        是                                                                无
                                            int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.constant_pad_nd             是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.conv_tbc                    是                                                                无
                                            bfloat16, float64

 torch.conv_transpose1d            是        int64, float16, float32, bfloat16, float64              无

 torch.conv_transpose2d            是        int64, float16, float32, bfloat16, float64              无

 torch.conv_transpose3d            是        int64, float16, float32, bfloat16, float64              无

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.conv1d                      是                                                                无
                                            bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.conv2d                      是                                                                无
                                            bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                              212

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                   API 参考




                                                                                                     限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                     制

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.conv3d                      是                                                                 无
                                            bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.convolution                 是                                                                 无
                                            bfloat16, float64

                                            float16, float32, bfloat16, float64, float16,
 torch.copysign                    是                                                                 无
                                            float32, bfloat16, float64

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
 torch.corrcoef                    是                                                                 无
                                            int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.cos                         是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.cos_                        是        float16, float32, bfloat16, float64                      无

 torch.cosh                        是        float16, float32, bfloat16, float64                      无

 torch.cosh_                       是        float16, float32, bfloat16, float64                      无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.cosine_embedding_loss       是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.count_nonzero               是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
 torch.cov                         是                                                                 无
                                            int64, float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.cross                       是        bfloat16, float64, uint8, int8, int16, int32, int64,     无
                                            float16, float32, bfloat16, float64

 torch.ctc_loss                    是        float32, float64                                         无

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.cummax                      是                                                                 无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.cummin                      是                                                                 无
                                            float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.cumprod                     是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                               213

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.cumsum                      是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.cumulative_trapezoid        是                                                                无
                                            bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.deg2rad                     是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.deg2rad_                    是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.diag                        是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.diag_embed                  是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.diagflat                    是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.diagonal                    是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.diff                        是                                                                无
                                            float32, bfloat16, float64

 torch.dist                        是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.div                         是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.divide                      是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.dot                         是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.dropout                     是        float16, float32, bfloat16, float64                     无

 torch.dropout_                    是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.dsplit                      是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                              214

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                 API 参考




                                                                                                   限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                   制

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.dstack                      是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.embedding                   是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.embedding_bag               是        float16, float32, bfloat16, float64                    无

 torch.embedding_renorm_           是        float16, float32, bfloat16, float64                    无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.empty                       是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64,
 torch.empty_like                  是                                                               无
                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.empty_permuted              是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.empty_strided               是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.eq                          是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.equal                       是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.erf                         是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.erf_                        是        float16, float32, bfloat16, float64                    无

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
 torch.erfc                        是                                                               无
                                            int64, float16, float32, bfloat16, float64

 torch.erfc_                       是        float16, float32, bfloat16, float64                    无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.exp                         是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.exp_                        是        float16, float32, bfloat16, float64                    无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                             215

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                API 参考




                                                                                                  限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                  制

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.exp2                        是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.exp2_                       是        float16, float32, bfloat16, float64                   无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.expand_copy                 是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.expm1                       是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.expm1_                      是        float16, float32, bfloat16, float64                   无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.eye                         是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.fake_quantize_per_chan
                                   是        float16, float32, bfloat16, float64                   无
 nel_affine

 torch.fake_quantize_per_tenso
                                   是        float16, float32, bfloat16, float64                   无
 r_affine

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.feature_alpha_dropout       是                                                              无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.feature_alpha_dropout_      是                                                              无
                                            float32, bfloat16, float64

 torch.feature_dropout             是        float16, float32, bfloat16, float64                   无

 torch.feature_dropout_            是        float16, float32, bfloat16, float64                   无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.fill                        是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.fill_                       是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.flatten                     是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.flip                        是                                                              无
                                            float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                            216

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                   API 参考




                                                                                                     限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                     制

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.float_power                 是                                                                 无
                                            bfloat16, float64

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
 torch.floor                       是                                                                 无
                                            int64, float16, float32, bfloat16, float64

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
 torch.floor_                      是                                                                 无
                                            int64, float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.floor_divide                是                                                                 无
                                            bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.fmax                        是                                                                 无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.fmin                        是                                                                 无
                                            float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.fmod                        是        bfloat16, float64, uint8, int8, int16, int32, int64,     无
                                            float16, float32, bfloat16, float64

 torch.frac                        是        float16, float32, bfloat16, float64                      无

 torch.frac_                       是        float16, float32, bfloat16, float64                      无

 torch.frexp                       是        float16, float32, bfloat16, float64                      无

 torch.frobenius_norm              是        float16, float32, bfloat16, float64                      无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.from_numpy                  是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.frombuffer                  是        bool, uint8, int8, int32, float32                        无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.full                        是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.full_like                   是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.functional.atleast_1d       是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                               217

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.functional.atleast_2d       是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.functional.atleast_3d       是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.functional.block_diag       是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.functional.broadcast_ten             int32, int64, float16, float32, bfloat16, float64,
                                   是                                                                无
 sors                                       bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.functional.cartesian_prod   是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.functional.cdist            是        float16, float32, bfloat16, float64                     无

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.functional.chain_matmul     是                                                                无
                                            bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.functional.einsum           是                                                                无
                                            bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.functional.meshgrid         是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.functional.norm             是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.functional.split            是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.functional.stft             是        float32, float64                                        无

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.functional.tensordot        是                                                                无
                                            bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.functional.unique           是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.functional.unique_consec             bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                                无
 utive                                      int32, int64, float16, float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                              218

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                 API 参考




                                                                                                   限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                   制

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.functional.unravel_index    是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.fused_moving_avg_obs
                                   是        float32                                                无
 _fake_quant

                                            bool, uint8, int8, int16, int64, float16, float32,
 torch.gather                      是                                                               无
                                            bfloat16, float64

 torch.gcd                         是        uint8, int8, int16, int32, int64                       无

 torch.gcd_                        是        uint8, int8, int16, int32, int64                       无

                                            bool, uint8, int8, int16, int32, int64, float16,
                                            float32, bfloat16, float64, bool, uint8, int8,
 torch.ge                          是                                                               无
                                            int16, int32, int64, float16, float32, bfloat16,
                                            float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.ger                         是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.get_autocast_cpu_dtype      是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.get_autocast_dtype          是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.get_autocast_gpu_dtyp                bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                               无
 e                                          int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.get_autocast_ipu_dtype      是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.get_autocast_xla_dtype      是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.get_default_device          是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.get_default_dtype           是                                                               无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.get_deterministic_debug              bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                               无
 _mode                                      int32, int64, float16, float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                             219

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                API 参考




                                                                                                  限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                  制

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.get_device                  是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.get_device_module           是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.get_float32_matmul_pre               bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                              无
 cision                                     int32, int64, float16, float32, bfloat16, float64

 torch.get_num_interop_thread               bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                              无
 s                                          int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.get_num_threads             是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            int8, int16, int32, int64, float16, float32,
 torch.gradient                    是                                                              无
                                            bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
                                            float32, bfloat16, float64, bool, uint8, int8,
 torch.greater                     是                                                              无
                                            int16, int32, int64, float16, float32, bfloat16,
                                            float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.greater_equal               是                                                              无
                                            float32, bfloat16, float64

 torch.grid_sampler                是        float16, float32, bfloat16, float64                   无

 torch.grid_sampler_2d             是        float16, float32, bfloat16, float64                   无

 torch.grid_sampler_3d             是        float16, float32, bfloat16, float64                   无

 torch.group_norm                  是        float16, float32                                      无

 torch.gru_cell                    是        float16, float32, bfloat16, float64                   无

                                            bool, uint8, int8, int16, int32, int64, float16,
                                            float32, bfloat16, float64, bool, uint8, int8,
 torch.gt                          是                                                              无
                                            int16, int32, int64, float16, float32, bfloat16,
                                            float64

 torch.hamming_window              是        float16, float32, bfloat16, float64                   无

 torch.hann_window                 是        float16, float32, bfloat16, float64                   无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                           220

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

 torch.hardshrink                  是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.heaviside                   是                                                                无
                                            float32, bfloat16, float64

 torch.hinge_embedding_loss        是        float16, float32, bfloat16, float64                     无

                                            int64, float16, float32, bfloat16, float64, int64,
 torch.histc                       是                                                                无
                                            float16, float32, bfloat16, float64

 torch.histogram                   是        float32, float64                                        无

 torch.histogramdd                 是        float32, float64                                        无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.hsplit                      是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.hstack                      是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.hypot                       是        float16, float32, bfloat16, float64                     无

 torch.igamma                      是        float32, float64                                        无

 torch.igammac                     是        float32, float64                                        无

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.index_add                   是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.index_copy                  是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.index_fill                  是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.index_put                   是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.index_put_                  是                                                                无
                                            float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.index_reduce                是                                                                无
                                            bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                              221

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.index_select                是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.inner                       是                                                                无
                                            bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.is_neg                      是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.is_same_size                是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.is_signed                   是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.is_tensor                   是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64,
 torch.isclose                     是                                                                无
                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.isfinite                    是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
 torch.isin                        是                                                                无
                                            int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.isnan                       是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.isneginf                    是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.isposinf                    是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.isreal                      是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.kron                        是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                             222

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.kthvalue                    是                                                                无
                                            bfloat16, float64

 torch.lcm                         是        uint8, int8, int16, int32, int64                        无

 torch.lcm_                        是        uint8, int8, int16, int32, int64                        无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.ldexp                       是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.ldexp_                      是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
                                            float32, bfloat16, float64, bool, uint8, int8,
 torch.le                          是                                                                无
                                            int16, int32, int64, float16, float32, bfloat16,
                                            float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.lerp                        是                                                                无
                                            bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.less                        是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.less_equal                  是                                                                无
                                            float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.linspace                    是                                                                无
                                            bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.log                         是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.log_                        是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.log10                       是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.log10_                      是        float16, float32, bfloat16, float64                     无

 torch.log1p                       是        float16, float32, bfloat16, float64                     无

 torch.log1p_                      是        float16, float32, bfloat16, float64                     无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                             223

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.log2                        是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.log2_                       是        float16, float32, bfloat16, float64                     无

 torch.logaddexp                   是        float16, float32, bfloat16, float64                     无

 torch.logaddexp2                  是        float16, float32, bfloat16, float64                     无

 torch.logcumsumexp                是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.logical_and                 是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.logical_not                 是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.logical_or                  是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.logical_xor                 是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.logit                       是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.logit_                      是        float16, float32, bfloat16, float64                     无

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.logspace                    是                                                                无
                                            bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.logsumexp                   是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
                                            float32, bfloat16, float64, bool, uint8, int8,
 torch.lt                          是                                                                无
                                            int16, int32, int64, float16, float32, bfloat16,
                                            float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.lu_unpack                   是                                                                无
                                            float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.margin_ranking_loss         是                                                                无
                                            bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                             224

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                   API 参考




                                                                                                     限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                     制

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.masked_fill                 是                                                                 无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.masked_scatter              是                                                                 无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.masked_select               是                                                                 无
                                            float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
                                            bfloat16, float64, uint8, int8, int16, int32, int64,
 torch.matmul                      是        float16, float32, bfloat16, float64, uint8, int8,        无
                                            int16, int32, int64, float16, float32, bfloat16,
                                            float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.matrix_power                是                                                                 无
                                            bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.max                         是                                                                 无
                                            float32, bfloat16, float64

 torch.max_pool1d                  是        float16, float32, bfloat16, float64                      无

 torch.max_pool1d_with_indices     是        float16, float32, bfloat16, float64                      无

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.max_pool2d                  是                                                                 无
                                            bfloat16, float64

 torch.max_pool3d                  是        float16, float32, bfloat16, float64                      无

                                            bool, uint8, int8, int16, int32, int64, float16,
                                            float32, bfloat16, float64, bool, uint8, int8,
 torch.maximum                     是                                                                 无
                                            int16, int32, int64, float16, float32, bfloat16,
                                            float64

                                            float16, float32, bfloat16, float64, float16,
 torch.mean                        是                                                                 无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.min                         是                                                                 无
                                            float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                              225

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

                                            bool, uint8, int8, int16, int32, int64, float16,
                                            float32, bfloat16, float64, bool, uint8, int8,
 torch.minimum                     是                                                                无
                                            int16, int32, int64, float16, float32, bfloat16,
                                            float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.mm                          是                                                                无
                                            bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
                                            float32, bfloat16, float64, bool, uint8, int8,
 torch.mode                        是                                                                无
                                            int16, int32, int64, float16, float32, bfloat16,
                                            float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.moveaxis                    是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.movedim                     是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64,
 torch.mul                         是                                                                无
                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.multinomial                 是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.multiply                    是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.mv                          是                                                                无
                                            bfloat16, float64

 torch.mvlgamma                    是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.nan_to_num                  是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.nan_to_num_                 是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.nanmean                     是        float16, float32, bfloat16, float64                     无

 torch.nanquantile                 是        float32, float64                                        无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                             226

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.nansum                      是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.narrow                      是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.narrow_copy                 是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.native_batch_norm           是        float16, float32                                        无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.native_channel_shuffle      是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.native_dropout              是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.native_layer_norm           是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64,
 torch.ne                          是                                                                无
                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.neg                         是                                                                无
                                            bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.neg_                        是                                                                无
                                            bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.negative                    是                                                                无
