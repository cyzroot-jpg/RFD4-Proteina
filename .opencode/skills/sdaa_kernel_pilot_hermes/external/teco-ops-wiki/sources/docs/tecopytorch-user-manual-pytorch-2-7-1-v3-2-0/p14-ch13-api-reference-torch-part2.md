---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p14
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第14部分 (ch13-api-reference-torch-part2)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "15001-17000"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, api-reference, torch, operator-support]
---

# TecoPyTorch 用户手册 v3.2.0（第14部分）

> 原文行范围：`15001-17000`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

                                            bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.negative_                   是                                                                无
                                            bfloat16, float64

 torch.nextafter                   是        float32, bfloat16, float64                              无

                                            bool, uint8, int8, int16, int32, int64, float16,
                                            float32, bfloat16, float64, bool, uint8, int8,
 torch.nonzero                     是                                                                无
                                            int16, int32, int64, float16, float32, bfloat16,
                                            float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.nonzero_static              是                                                                无
                                            float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                             227

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

 torch.norm_except_dim             是        float16, float32, bfloat16, float64                     无

 torch.normal                      是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64,
 torch.not_equal                   是                                                                无
                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.ones                        是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64,
 torch.ones_like                   是                                                                无
                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.outer                       是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.pairwise_distance           是                                                                无
                                            bfloat16, float64

 torch.pdist                       是        float32, float64                                        无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.permute                     是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.permute_copy                是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.pixel_shuffle               是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.pixel_unshuffle             是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.poisson                     是                                                                无
                                            bfloat16, float64

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
 torch.poisson_nll_loss            是                                                                无
                                            int64, float16, float32, bfloat16, float64

 torch.polar                       是        float32, float64                                        无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                             228

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.polygamma                   是                                                                无
                                            bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.pow                         是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.prelu                       是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.prod                        是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.promote_types               是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.put                         是                                                                无
                                            float32, bfloat16, float64

 torch.quantile                    是        float32, float64                                        无

 torch.rand                        是        float16, float32, bfloat16, float64                     无

                                            float16, float32, bfloat16, float64, float16,
 torch.rand_like                   是                                                                无
                                            float32, bfloat16, float64

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
 torch.randint                     是                                                                无
                                            int64, float16, float32, bfloat16, float64

                                            uint8, uint16, uint32, uint64, int8, int16, int32,
 torch.randint_like                是                                                                无
                                            int64, float16, float32, bfloat16, float64

 torch.randn                       是        float16, float32, bfloat16, float64                     无

                                            float16, float32, bfloat16, float64, float16,
 torch.randn_like                  是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.random.get_rng_state        是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.random.seed                 是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.random.set_rng_state        是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                             229

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.randperm                    是                                                                无
                                            bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.range                       是                                                                无
                                            float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.read_vitals                 是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64,
 torch.real                        是                                                                无
                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64,
 torch.reciprocal                  是                                                                无
                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64

 torch.reciprocal_                 是        float16, float32, bfloat16, float64                     无

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.relu                        是                                                                无
                                            bfloat16, float64

                                            int16, int32, int64, float16, float32, bfloat16,
 torch.remainder                   是                                                                无
                                            float64

 torch.renorm                      是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.repeat_interleave           是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.reshape                     是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64,
 torch.resize_as_                  是                                                                无
                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.result_type                 是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.rms_norm                    是        float16, float32, bfloat16, float64                     无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                             230

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                   API 参考




                                                                                                     限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                     制

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.rnn_relu                    是                                                                 无
                                            bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.rnn_relu_cell               是                                                                 无
                                            bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.rnn_tanh                    是                                                                 无
                                            bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.rnn_tanh_cell               是                                                                 无
                                            bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.roll                        是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.rot90                       是                                                                 无
                                            float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.row_stack                   是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.rrelu                       是        float16, float32, bfloat16, float64                      无

 torch.rrelu_                      是        float16, float32, bfloat16, float64                      无

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.rsub                        是        bfloat16, float64, uint8, int8, int16, int32, int64,     无
                                            float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.scalar_tensor               是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.scatter                     是                                                                 无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.scatter_add                 是                                                                 无
                                            float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.scatter_reduce              是                                                                 无
                                            float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.searchsorted                是                                                                 无
                                            bfloat16, float64

 torch.segment_reduce              是        float16, float32, bfloat16, float64                      无



文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                               231

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                API 参考




                                                                                                  限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                  制

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.select                      是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.select_copy                 是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.select_scatter              是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.selu                        是        float16, float32                                      无

 torch.selu_                       是        float16, float32, bfloat16, float64                   无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.serialization.save          是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.set_anomaly_enabled         是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.set_autocast_cache_en                bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                              无
 abled                                      int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.set_autocast_cpu_dtype      是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.set_autocast_cpu_enabl               bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                              无
 ed                                         int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.set_autocast_dtype          是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.set_autocast_enabled        是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.set_autocast_gpu_dtype      是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.set_autocast_ipu_dtype      是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.set_autocast_ipu_enable              bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                              无
 d                                          int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.set_autocast_xla_dtype      是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                           232

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                API 参考




                                                                                                  限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                  制

 torch.set_autocast_xla_enable              bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                              无
 d                                          int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.set_default_device          是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.set_default_dtype           是        float16, float32, bfloat16, float64                   无

 torch.set_default_tensor_type     是        float32, float64                                      无

 torch.set_deterministic_debug              bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                              无
 _mode                                      int32, int64, float16, float32, bfloat16, float64

 torch.set_float32_matmul_pre               bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                              无
 cision                                     int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.set_flush_denormal          是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.set_num_interop_thread
                                   是        bool                                                  无
 s

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.set_num_threads             是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.set_vital                   是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.set_warn_always             是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.sin                         是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.slice_copy                  是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.slice_inverse               是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.slice_scatter               是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.softmax                     是        float16, float32, bfloat16, float64                   无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                           233

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64,
 torch.sort                        是                                                                无
                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.sparse_bsc_tensor           是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.sparse_bsr_tensor           是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.sparse_compressed_ten                bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                                无
 sor                                        int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.sparse_coo_tensor           是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.sparse_csc_tensor           是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.sparse_csr_tensor           是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.split_copy                  是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.split_with_sizes            是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.split_with_sizes_copy       是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.spmm                        是                                                                无
                                            bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.squeeze                     是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.squeeze_copy                是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.stack                       是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.std                         是        float16, float32, bfloat16, float64                     无



文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                             234

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                   API 参考




                                                                                                     限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                     制

 torch.std_mean                    是        float16, float32, bfloat16, float64                      无

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.sub                         是        bfloat16, float64, uint8, int8, int16, int32, int64,     无
                                            float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.subtract                    是                                                                 无
                                            bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64,
 torch.sum                         是                                                                 无
                                            bool, uint8, uint16, uint32, uint64, int8, int16,
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.swapaxes                    是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.swapdims                    是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.sym_constrain_range         是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.sym_constrain_range_fo               bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                                 无
 r_size                                     int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.sym_float                   是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.sym_int                     是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.sym_ite                     是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.sym_max                     是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.sym_min                     是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.sym_not                     是                                                                 无
                                            int32, int64, float16, float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                              235

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.SymBool                     是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.SymFloat                    是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.SymInt                      是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.tensor                      是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.tensor_split                是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.threshold                   是                                                                无
                                            bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.threshold_                  是                                                                无
                                            bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.tile                        是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.topk                        是                                                                无
                                            bfloat16

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.trace                       是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.transpose                   是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.transpose_copy              是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.trapezoid                   是                                                                无
                                            bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.trapz                       是                                                                无
                                            bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.tril                        是                                                                无
                                            float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                             236

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                  API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.tril_indices                是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            uint8, int8, int16, int32, int64, float16, float32,
 torch.triplet_margin_loss         是                                                                无
                                            bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.triu                        是                                                                无
                                            float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.triu_indices                是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.true_divide                 是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.typename                    是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.unbind                      是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.unbind_copy                 是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.unflatten                   是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.unfold_copy                 是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.unsafe_chunk                是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.unsafe_split                是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.unsafe_split_with_sizes     是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.unsqueeze                   是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.unsqueeze_copy              是                                                                无
                                            int32, int64, float16, float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                             237

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                API 参考




                                                                                                  限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                  制

 torch.use_deterministic_algorit            bool, uint8, uint16, uint32, uint64, int8, int16,
                                   是                                                              无
 hms                                        int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.utils.dlpack.from_dlpack    是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.var                         是        float16, float32, bfloat16, float64                   无

 torch.var_mean                    是        float16, float32, bfloat16, float64                   无

 torch.view_as_complex             是        float16, float32, float64                             无

 torch.view_as_complex_copy        是        float16, float32, float64                             无

 torch.view_as_real                是        float16, float32, float64                             无

 torch.view_as_real_copy           是        float16, float32, float64                             无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.view_copy                   是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.vitals_enabled              是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.vsplit                      是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.vstack                      是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, int8, int16, int32, int64, float16,
 torch.where                       是                                                              无
                                            float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.xlogy                       是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

 torch.xlogy_                      是        float16, float32, bfloat16, float64                   无

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.zeros                       是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64

                                            bool, uint8, uint16, uint32, uint64, int8, int16,
 torch.zeros_like                  是                                                              无
                                            int32, int64, float16, float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                           238

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                     API 参考




                                                                                                       限
 算子类API名称                              是否支持   支持的数据类型
                                                                                                       制

 torch_sdaa.nn.functional.cosin
                                       是      float16, float32, bfloat16, float64                      无
 e_similarity

 torch.sgn                             是      float16, float32                                         无

 torch.sqrt                            是      float16, float32, float64                                无

 torch.rsqrt                           是      float16, float32                                         无

 torch.unique                          是      int64                                                    无

 torch.clip                            是      float16, float32, int64                                  无

                                              float16, float32, float64, bool, int8 int16, int32,
 torch.great                           是                                                               无
                                              int64

 torch.norm                            是      float16, float32, float64, bfloat16                      无

 torch.linalg.matmul                   是      float16, float32                                         无

                                              float16, float32, float64, bfloat16, int8, int16,
 torch.index                           是                                                               无
                                              int32, int64

 torch.tanh                            是      float16, float32, bfloat16                               无

 torch.cdist                           是      float32                                                  无

                                              float16, float32, float64, bool, uint8, int8, int16,
 torch.clone                           是                                                               无
                                              int32, int64




13.1.2 torch.nn

                                                                                                      限
 算子类API名称                          是否支持       支持的数据类型
                                                                                                      制

 torch.nn.AdaptiveAvgPool1d        是          float16, float32, bfloat16, float64                     无

 torch.nn.AdaptiveAvgPool2d        是          float16, float32, bfloat16, float64                     无

 torch.nn.AdaptiveAvgPool3d        是          float16, float32, bfloat16, float64                     无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                  239

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                  API 参考




                                                                                   限
 算子类API名称                          是否支持     支持的数据类型
                                                                                   制

 torch.nn.AdaptiveLogSoftma
                                   是        float16, float32, bfloat16, float64    无
 xWithLoss

 torch.nn.AdaptiveMaxPool1d        是        float16, float32, bfloat16, float64    无

 torch.nn.AdaptiveMaxPool2d        是        float16, float32, bfloat16, float64    无

 torch.nn.AdaptiveMaxPool3d        是        float16, float32, bfloat16, float64    无

 torch.nn.AlphaDropout             是        float16, float32, bfloat16, float64    无

 torch.nn.AvgPool1d                是        float16, float32, bfloat16, float64    无

 torch.nn.AvgPool2d                是        float16, float32, bfloat16, float64    无

 torch.nn.AvgPool3d                是        float16, float32, bfloat16, float64    无

 torch.nn.BatchNorm1d              是        float16, float32                       无

 torch.nn.BatchNorm2d              是        float16, float32                       无

 torch.nn.BatchNorm3d              是        float16, float32                       无

 torch.nn.BCELoss                  是        float16, float32                       无

 torch.nn.BCEWithLogitsLoss        是        float16, float32, bfloat16, float64    无

 torch.nn.CELU                     是        float16, float32                       无

 torch.nn.ChannelShuffle           是        float16, float32, bfloat16, float64    无

 torch.nn.CircularPad1d            是        float16, float32, bfloat16, float64    无

 torch.nn.CircularPad2d            是        float16, float32, bfloat16, float64    无

 torch.nn.CircularPad3d            是        float16, float32, bfloat16, float64    无

 torch.nn.ConstantPad1d            是        float16, float32, bfloat16, float64    无

 torch.nn.ConstantPad2d            是        float16, float32, bfloat16, float64    无

 torch.nn.ConstantPad3d            是        float16, float32, bfloat16, float64    无

 torch.nn.Conv1d                   是        float16, float32, bfloat16, float64    无

 torch.nn.Conv2d                   是        float16, float32, bfloat16, float64    无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                               240

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                  API 参考




                                                                                   限
 算子类API名称                          是否支持     支持的数据类型
                                                                                   制

 torch.nn.Conv3d                   是        float16, float32, bfloat16, float64    无

 torch.nn.ConvTranspose1d          是        float16, float32, bfloat16, float64    无

 torch.nn.ConvTranspose2d          是        float16, float32, bfloat16, float64    无

 torch.nn.ConvTranspose3d          是        float16, float32, bfloat16, float64    无

 torch.nn.CosineEmbeddingLo
                                   是        float16, float32, bfloat16, float64    无
 ss

 torch.nn.CosineSimilarity         是        float16, float32, bfloat16, float64    无

 torch.nn.CrossEntropyLoss         是        float16, float32, bfloat16, float64    无

 torch.nn.CrossMapLRN2d            是        float16, float32, bfloat16, float64    无

 torch.nn.CTCLoss                  是        float32, float64                       无

 torch.nn.Dropout                  是        float16, float32, bfloat16, float64    无

 torch.nn.Dropout1d                是        float16, float32, bfloat16, float64    无

 torch.nn.Dropout2d                是        float16, float32, bfloat16, float64    无

 torch.nn.ELU                      是        float16, float32                       无

 torch.nn.Embedding                是        float16, float32, bfloat16             无

 torch.nn.EmbeddingBag             是        float16, float32                       无

 torch.nn.FeatureAlphaDropo
                                   是        float16, float32, bfloat16, float64    无
 ut

 torch.nn.Flatten                  是        float16, float32, bfloat16, float64    无

 torch.nn.Fold                     是        float16, float32, bfloat16, float64    无

 torch.nn.FractionalMaxPool2d      是        float16, float32, bfloat16, float64    无

 torch.nn.FractionalMaxPool3
                                   是        float16, float32, bfloat16, float64    无
 d

 torch.nn.GELU                     是        float16, float32, bfloat16, float64    无

 torch.nn.GLU                      是        float16, float32, bfloat16, float64    无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                               241

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                  API 参考




                                                                                   限
 算子类API名称                          是否支持     支持的数据类型
                                                                                   制

 torch.nn.GroupNorm                是        float16, float32                       无

 torch.nn.GRU                      是        float16, float32, bfloat16, float64    无

 torch.nn.Hardshrink               是        float16, float32, bfloat16, float64    无

 torch.nn.Hardsigmoid              是        float16, float32, bfloat16, float64    无

 torch.nn.Hardswish                是        float16, float32, bfloat16, float64    无

 torch.nn.Hardtanh                 是        float16, float32, bfloat16, float64    无

 torch.nn.HingeEmbeddingLos
                                   是        float16, float32, bfloat16, float64    无
 s

 torch.nn.HuberLoss                是        float16, float32, bfloat16, float64    无

 torch.nn.Identity                 是        float16, float32, bfloat16, float64    无

 torch.nn.InstanceNorm1d           是        float16, float32                       无

 torch.nn.InstanceNorm2d           是        float16, float32                       无

 torch.nn.InstanceNorm3d           是        float16, float32                       无

 torch.nn.KLDivLoss                是        float16, float32, bfloat16, float64    无

 torch.nn.L1Loss                   是        float16, float32, bfloat16, float64    无

 torch.nn.LayerNorm                是        float16, float32, bfloat16, float64    无

 torch.nn.LazyBatchNorm1d          是        float16, float32                       无

 torch.nn.LazyBatchNorm2d          是        float16, float32                       无

 torch.nn.LazyBatchNorm3d          是        float16, float32                       无

 torch.nn.LazyConv1d               是        float16, float32, bfloat16, float64    无

 torch.nn.LazyConv2d               是        float16, float32, bfloat16, float64    无

 torch.nn.LazyConv3d               是        float16, float32, bfloat16, float64    无

 torch.nn.LazyConvTranspose1
                                   是        float16, float32, bfloat16, float64    无
 d




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                               242

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                           API 参考




                                                                                            限
 算子类API名称                          是否支持     支持的数据类型
                                                                                            制

 torch.nn.LazyConvTranspose
                                   是        float16, float32, bfloat16, float64             无
 2d

 torch.nn.LazyConvTranspose
                                   是        float16, float32, bfloat16, float64             无
 3d

 torch.nn.LazyInstanceNorm1d       是        float16, float32                                无

 torch.nn.LazyInstanceNorm2
                                   是        float16, float32                                无
 d

 torch.nn.LazyInstanceNorm3
                                   是        float16, float32                                无
 d

 torch.nn.LazyLinear               是        float16, float32, bfloat16, float64             无

 torch.nn.LeakyReLU                是        float16, float32, bfloat16, float64             无

 torch.nn.Linear                   是        float16, float32, bfloat16, float64             无

 torch.nn.LocalResponseNorm        是        float16, float32, bfloat16, float64             无

 torch.nn.LogSigmoid               是        float16, float32, bfloat16, float64             无

 torch.nn.LogSoftmax               是        float16, float32, bfloat16, float64             无

 torch.nn.LPPool1d                 是        float16, float32, bfloat16, float64             无

 torch.nn.LPPool2d                 是        float16, float32, bfloat16, float64             无

 torch.nn.LPPool3d                 是        float16, float32, bfloat16, float64             无

 torch.nn.LSTM                     是        float16, float32, bfloat16, float64             无

 torch.nn.MarginRankingLoss        是        float16, float32, bfloat16, float64             无

 torch.nn.MaxPool1d                是        float16, float32, bfloat16, float64, float16    无

 torch.nn.MaxPool2d                是        float16, float32, bfloat16, float64, float16    无

 torch.nn.MaxPool3d                是        float16, float32, bfloat16, float64, float16    无

 torch.nn.MaxUnpool1d              是        float16, float32, bfloat16, float64, float16    无

 torch.nn.MaxUnpool2d              是        float16, float32, bfloat16, float64, float16    无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                        243

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                   API 参考




                                                                                                    限
 算子类API名称                          是否支持     支持的数据类型
                                                                                                    制

 torch.nn.MaxUnpool3d              是        float16, float32, bfloat16, float64, float16            无

 torch.nn.Mish                     是        float16, float32, bfloat16, float64                     无

                                            bool, uint8, torch.uint16, uint32, uint64, int8,
                                            int16, int32, int64, float16, float32, bfloat16,
 torch.nn.modules.pooling.Ad
                                   是        float64, bool, uint8, torch.uint16, uint32,             无
 aptiveAvgPool1d
                                            uint64, int8, int16, int32, int64, float16, float32,
                                            bfloat16, float64

 torch.nn.modules.pooling.Ad                float16, float32, bfloat16, float64, float16,
                                   是                                                                无
 aptiveMaxPool1d                            float32, bfloat16, float64

                                            bool, uint8, torch.uint16, uint32, uint64, int8,
 torch.nn.modules.utils._pair      是        int16, int32, int64, float16, float32, bfloat16,        无
                                            float64

                                            bool, uint8, torch.uint16, uint32, uint64, int8,
 torch.nn.modules.utils._singl
                                   是        int16, int32, int64, float16, float32, bfloat16,        无
 e
                                            float64

                                            bool, uint8, torch.uint16, uint32, uint64, int8,
 torch.nn.modules.utils._triple    是        int16, int32, int64, float16, float32, bfloat16,        无
                                            float64

 torch.nn.MSELoss                  是        float16, float32, bfloat16, float64                     无

 torch.nn.MultiheadAttention       是        float16, float32, bfloat16, float64                     无

 torch.nn.MultiLabelMarginLos
                                   是        float16, float32, bfloat16, float64                     无
 s

 torch.nn.MultiLabelSoftMargi
                                   是        float16, float32, bfloat16, float64                     无
 nLoss

 torch.nn.MultiMarginLoss          是        float16, float32, bfloat16, float64                     无

 torch.nn.NLLLoss                  是        float16, float32                                        无

 torch.nn.PairwiseDistance         是        float16, float32, bfloat16, float64                     无

 torch.nn.PixelShuffle             是        float16, float32, bfloat16, float64                     无

 torch.nn.PixelUnshuffle           是        float16, float32, bfloat16, float64                     无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                244

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                  API 参考




                                                                                   限
 算子类API名称                          是否支持     支持的数据类型
                                                                                   制

 torch.nn.PoissonNLLLoss           是        float16, float32, bfloat16, float64    无

 torch.nn.PReLU                    是        float16, float32, bfloat16, float64    无

 torch.nn.ReflectionPad1d          是        float16, float32, bfloat16, float64    无

 torch.nn.ReflectionPad2d          是        float16, float32, bfloat16, float64    无

 torch.nn.ReflectionPad3d          是        float16, float32, bfloat16, float64    无

 torch.nn.ReLU                     是        float16, float32, bfloat16, float64    无

 torch.nn.ReLU6                    是        float16, float32, bfloat16, float64    无

 torch.nn.ReplicationPad1d         是        float16, float32, bfloat16, float64    无

 torch.nn.ReplicationPad2d         是        float16, float32, bfloat16, float64    无

 torch.nn.ReplicationPad3d         是        float16, float32, bfloat16, float64    无

 torch.nn.RMSNorm                  是        float16, float32, bfloat16, float64    无

 torch.nn.RNN                      是        float16, float32, bfloat16, float64    无

 torch.nn.RNNCell                  是        float16, float32, bfloat16, float64    无

 torch.nn.RReLU                    是        float32, bfloat16, float64             无

 torch.nn.SELU                     是        float16, float32                       无

 torch.nn.Sequential               是        float16, float32, bfloat16, float64    无

 torch.nn.Sigmoid                  是        float16, float32, bfloat16, float64    无

 torch.nn.SiLU                     是        float16, float32, bfloat16, float64    无

 torch.nn.SmoothL1Loss             是        float16, float32, bfloat16, float64    无

 torch.nn.SoftMarginLoss           是        float16, float32, bfloat16, float64    无

 torch.nn.Softmax                  是        float16, float32, bfloat16, float64    无

 torch.nn.Softmax2d                是        float16, float32, bfloat16, float64    无

 torch.nn.Softmin                  是        float16, float32, bfloat16, float64    无

 torch.nn.Softplus                 是        float16, float32, bfloat16, float64    无



文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                               245

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                  API 参考




                                                                                   限
 算子类API名称                          是否支持     支持的数据类型
                                                                                   制

 torch.nn.Softshrink               是        float16, float32, bfloat16, float64    无

 torch.nn.Softsign                 是        float16, float32                       无

 torch.nn.Tanh                     是        float16, float32, bfloat16, float64    无

 torch.nn.Tanhshrink               是        float16, float32, bfloat16, float64    无

 torch.nn.Threshold                是        float16, float32, bfloat16, float64    无

 torch.nn.Transformer              是        float16, float32, bfloat16, float64    无

 torch.nn.TransformerDecode
                                   是        float16, float32, bfloat16, float64    无
 rLayer

 torch.nn.TransformerEncoder       是        float16, float32, bfloat16, float64    无

 torch.nn.TransformerEncoder
                                   是        float16, float32, bfloat16, float64    无
 Layer

 torch.nn.TripletMarginLoss        是        float16, float32, bfloat16, float64    无

 torch.nn.TripletMarginWithDis
                                   是        float16, float32, bfloat16, float64    无
 tanceLoss

 torch.nn.Unflatten                是        float16, float32, bfloat16, float64    无

 torch.nn.Unfold                   是        float16, float32, bfloat16, float64    无

 torch.nn.Upsample                 是        float16, float32, bfloat16, float64    无

 torch.nn.UpsamplingBilinear2
                                   是        float16, float32, bfloat16, float64    无
 d

 torch.nn.UpsamplingNearest
                                   是        float16, float32, bfloat16, float64    无
 2d

 torch.nn.ZeroPad1d                是        float16, float32, bfloat16, float64    无

 torch.nn.ZeroPad2d                是        float16, float32, bfloat16, float64    无

 torch.nn.ZeroPad3d                是        float16, float32, bfloat16, float64    无

 torch.nn.Dropout3d                是        float16, float32, bfloat16, float64    无

 torch.nn.GRUCell                  否        N/A                                    无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                               246

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                             API 参考




                                                                                               限
 算子类API名称                          是否支持     支持的数据类型
                                                                                               制

 torch.nn.LSTMCell                 否        N/A                                                无


13.1.3 torch.nn.functional

 算子类API名称                     是否支持        支持的数据类型                               限制

 torch.nn.functional.kl_div   是           float16, float32                      无

 torch.nn.functional.embe
                              是           float16, float32, bfloat16            无
 dding

 torch.nn.functional.max_
                              是           float16, float32                      无
 pool2d

 torch.nn.functional.adapt
                              是           float16, float32                      无
 ive_avg_pool2d

 torch.nn.functional.avg_
                              是           float16, float32                      无
 pool2d

                                                                                使用时，需要替换成
 torch.nn.functional.cosin                                                      torch_sdaa.nn.fun
                              是           float16, float32, bfloat16, float64
 e_similarity                                                                   ctional.cosine_si
                                                                                milarity

 torch.nn.functional.nll_lo
                              是           float16, float32                      无
 ss

 torch.nn.functional.l1_los
                              是           float16, float32                      无
 s

 torch.nn.functional.mse_l
                              是           float16, float32                      无
 oss

 torch.nn.functional.smoot
                              是           float16, float32                      无
 h_l1_loss

 torch.nn.functional.hardsi
                              是           float16, float32                      无
 gmoid

 torch.nn.functional.softpl
                              是           float16, float32                      无
 us

 torch.nn.functional.mish     是           float16, float32                      无



文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                            247

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                         API 参考




 算子类API名称                     是否支持        支持的数据类型                               限制

 torch.nn.functional.gelu     是           float16, float32, bfloat16            无

 torch.nn.functional.glu      是           float16, float32                      无

 torch.nn.functional.leaky
                              是           float16, float32                      无
 _relu

 torch.nn.functional.sigmo
                              是           float16, float32, bfloat16            无
 id

 torch.nn.functional.hardt
                              是           float16, float32                      无
 anhs

 torch.nn.functional.log_s
                              是           float16, float32                      无
 oftmax

 torch.nn.functional.logsig
                              是           float16, float32, bfloat16            无
 moid

 torch.nn.functional.silu     是           float16, float32, bfloat16            无

 torch.nn.functional.upsa                                                       仅支持nearest和
                              是           float16, float32
 mple                                                                           bilinear模式

 torch.nn.functional.layer
                              是           float32, float16, bfloat16            无
 _norm

 torch.nn.functional.batch
                              是           float16, float32                      无
 _norm

 torch.nn.functional.group
                              是           float16, float32                      无
 _norm

 torch.nn.functional.instan
                              是           float16, float32                      无
 ce_norm

 torch.nn.functional.linear   是           float16, float32                      无

 torch.nn.functional.prelu    是           float16, float32                      无

 torch.nn.functional.one_
                              是           int64                                 无
 hot

                                          bool, uint8, uint16, uint32,
 torch.nn.functional._is_in
                              是           uint64, int8, int16, int32, int64,    无
 teger
                                          float16, float32, bfloat16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                      248

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                       API 参考




13.1.4 torch.Tensor

                                                                                                         限
 算子类API名称               是否支持         支持的数据类型
                                                                                                         制

 torch.Tensor._conj_                 bool, uint8, int8, int16, int32, int64, float16, float32,
                        是                                                                                无
 physical                            float16, float64

 torch.Tensor._is_all
                        是            bool                                                                无
 _true

 torch.Tensor._is_an
                        是            bool                                                                无
 y_true

 torch.Tensor._is_vie                bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                无
 w                                   float16, float32, float16, float64

 torch.Tensor._is_zer                bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                无
 otensor                             float16, float32, float16, float64

 torch.Tensor._lazy_                 bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                无
 clone                               float16, float32, float16, float64

 torch.Tensor._neg_                  bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                无
 view                                float16, float32, float16, float64

                                     uint8, int8, int16, int32, int64, float16, float32, float16,
 torch.Tensor.abs       是                                                                                无
                                     float64

                                     uint8, int8, int16, int32, int64, float16, float32, float16,
 torch.Tensor.abs_      是                                                                                无
                                     float64

 torch.Tensor.absolu                 uint8, int8, int16, int32, int64, float16, float32, float16,
                        是                                                                                无
 te                                  float64

 torch.Tensor.absolu                 uint8, int8, int16, int32, int64, float16, float32, float16,
                        是                                                                                无
 te_                                 float64

 torch.Tensor.acos      是            float16, float32, float16, float64                                  无

 torch.Tensor.acos_     是            float16, float32, float16, float64                                  无

 torch.Tensor.acosh     是            float16, float32, float16, float64                                  无

 torch.Tensor.acosh
                        是            float16, float32, float16, float64                                  无
 _




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                  249

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                       API 参考




                                                                                                         限
 算子类API名称               是否支持         支持的数据类型
                                                                                                         制

                                     float16, float32, float64, bfloat16, bool, int8, int16, int32,
 torch.Tensor.add       是                                                                                无
                                     int64, uint8

                                     float16, float32, float64, bfloat16, bool, int8, int16, int32,
 torch.Tensor.add_      是                                                                                无
                                     int64, uint8

 torch.Tensor.addbm
                        是            float16, float32                                                    无
 m

 torch.Tensor.addbm
                        是            float16, float32                                                    无
 m_

 torch.Tensor.addcdi
                        是            float16, float32, int32                                             无
 v

 torch.Tensor.addcdi
                        是            float16, float32, int32                                             无
 v_

 torch.Tensor.addcm
                        是            float16, float32, bfloat16, int32                                   无
 ul

 torch.Tensor.addcm
                        是            float16, float32, bfloat16, int32                                   无
 ul_

 torch.Tensor.addm
                        是            float16, float32, bfloat16                                          无
 m

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.adjoint   是                                                                                无
                                     float16, float32, float16, float64

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.all       是                                                                                无
                                     float16, float32, float16, float64

 torch.Tensor.amax      是            float16, float32, float64, bool, int32, int64                       无

 torch.Tensor.amin      是            float16, float32, float64, bool, int32, int64                       无

 torch.Tensor.angle     是            float32, float64                                                    无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.any       是                                                                                无
                                     float16, float32, float16, float64

 torch.Tensor.arccos    是            float16, float32, float16, float64                                  无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                  250

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         API 参考




                                                                                                           限
 算子类API名称               是否支持         支持的数据类型
                                                                                                           制

 torch.Tensor.arccos
                        是            float16, float32, float16, float64                                    无
 _

 torch.Tensor.arccos
                        是            float16, float32, float16, float64                                    无
 h

 torch.Tensor.arccos
                        是            float16, float32, float16, float64                                    无
 h_

 torch.Tensor.arcsin    是            float16, float32, float16, float64                                    无

 torch.Tensor.arcsin
                        是            float16, float32, float16, float64                                    无
 _

 torch.Tensor.arcsinh   是            float16, float32, float16, float64                                    无

 torch.Tensor.arcsinh
                        是            float16, float32, float16, float64                                    无
 _

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.arctan    是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.arctan
                        是            float16, float32, float16, float64                                    无
 _

 torch.Tensor.arctan
                        是            float16, float32, float16, float64                                    无
 h

 torch.Tensor.arctan
                        是            float16, float32, float16, float64                                    无
 h_

 torch.Tensor.argma
                        是            float16, float32, bfloat16                                            无
 x

 torch.Tensor.argmin    是            float32                                                               无

 torch.Tensor.argwh                  bool, uint8, int8, int16, int32, int64, float16, float32,
                        是                                                                                  无
 ere                                 float16, float64

 torch.Tensor.as_stri
                        是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无
 ded

 torch.Tensor.asin      是            float16, float32, float16, float64                                    无

 torch.Tensor.asin_     是            float16, float32, float16, float64                                    无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                     251

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         API 参考




                                                                                                           限
 算子类API名称               是否支持         支持的数据类型
                                                                                                           制

 torch.Tensor.asinh     是            float16, float32, float16, float64                                    无

 torch.Tensor.asinh_    是            float16, float32, float16, float64                                    无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                                     float16, float32, float16, float64, bool, uint8, uint16,
 torch.Tensor.atan      是                                                                                  无
                                     uint32, uint64, int8, int16, int32, int64, float16, float32,
                                     float16, float64

 torch.Tensor.atan_     是            float16, float32, float16, float64                                    无

 torch.Tensor.atanh     是            float16, float32, float16, float64                                    无

 torch.Tensor.atanh_    是            float16, float32, float16, float64                                    无

 torch.Tensor.baddb
                        是            float16, float32                                                      无
 mm

 torch.Tensor.baddb
                        是            float16, float32                                                      无
 mm_

 torch.Tensor.bitwise
                        是            bool, uint8, int8, int16, int32, int64                                无
 _not

 torch.Tensor.bitwise
                        是            bool, uint8, int8, int16, int32, int64                                无
 _not_

 torch.Tensor.bmm       是            float16, float32                                                      无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.bool      是                                                                                  无
                                     float16, float32, float16, float64

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.byte      是                                                                                  无
                                     float16, float32, float16, float64

                                     uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.ceil      是                                                                                  无
                                     float16, float32, float16, float64

                                     uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.ceil_     是                                                                                  无
                                     float16, float32, float16, float64

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.char      是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.chunk     是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                    252

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         API 参考




                                                                                                           限
 算子类API名称               是否支持         支持的数据类型
                                                                                                           制

 torch.Tensor.clamp     是            float16, float32, bfloat16, int64                                     无

 torch.Tensor.clamp
                        是            float16, float32, bfloat16, int64                                     无
 _

 torch.Tensor.clip      是            float16, float32, int64                                               无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.clone     是                                                                                  无
                                     float16, float32, float16, float64

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.conj      是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.conj_p                 bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 hysical                             float16, float32, float16, float64

 torch.Tensor.conj_p                 bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 hysical_                            float16, float32, float16, float64

 torch.Tensor.contig
                        是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无
 uous

 torch.Tensor.copy_     是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.cos       是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.cos_      是            float16, float32, float16, float64                                    无

 torch.Tensor.cosh      是            float16, float32, float16, float64                                    无

 torch.Tensor.cosh_     是            float16, float32, float16, float64                                    无

 torch.Tensor.data_                  bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 ptr                                 float16, float32, float16, float64

 torch.Tensor.deg2ra                 bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 d                                   float16, float32, float16, float64

 torch.Tensor.deg2ra                 bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 d_                                  float16, float32, float16, float64

 torch.Tensor.dense                  bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 _dim                                float16, float32, float16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                    253

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         API 参考




                                                                                                           限
 算子类API名称               是否支持         支持的数据类型
                                                                                                           制

 torch.Tensor.dequa                  bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 ntize                               float16, float32, float16, float64

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.detach    是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.detach                 bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 _                                   float16, float32, float16, float64

 torch.Tensor.diagon
                        是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无
 al

 torch.Tensor.digam
                        是            float16, float32, float16, float64                                    无
 ma

 torch.Tensor.digam
                        是            float16, float32, float16, float64                                    无
 ma_

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.dim       是                                                                                  无
                                     float16, float32, float16, float64

                                     float16, float32, float64, bfloat16, bool, int8, int16, int32,
 torch.Tensor.div       是                                                                                  无
                                     int64, uint8

                                     float16, float32, float64, bfloat16, bool, int8, int16, int32,
 torch.Tensor.div_      是                                                                                  无
                                     int64, uint8

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.double    是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.eleme                  bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 nt_size                             float16, float32, float16, float64

 torch.Tensor.eq        是            float16, float32, float64, bfloat16, int8 int16, int32, int64         无

 torch.Tensor.eq_       是            float16, float32, float64, bfloat16, int8 int16, int32, int64         无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.erf       是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.erf_      是            float16, float32, float16, float64                                    无

                                     uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.erfc      是                                                                                  无
                                     float16, float32, float16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                    254

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         API 参考




                                                                                                           限
 算子类API名称               是否支持         支持的数据类型
                                                                                                           制

 torch.Tensor.erfc_     是            float16, float32, float16, float64                                    无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.erfinv    是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.erfinv_   是            float16, float32, float16, float64                                    无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.exp       是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.exp_      是            float16, float32, float16, float64                                    无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.exp2      是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.exp2_     是            float16, float32, float16, float64                                    无

 torch.Tensor.expan                  float16, float32, float64, bfloat16, bool, uint8, int8, int16,
                        是                                                                                  无
 d                                   int32, int64

 torch.Tensor.expan
                        是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无
 d_as

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.expm1     是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.expm1
                        是            float16, float32, float16, float64                                    无
 _

                                     float16, float32, bfloat16, int64, bool, uint8, int8, int32,
 torch.Tensor.fill_     是                                                                                  无
                                     int64

                                     uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.fix       是                                                                                  无
                                     float16, float32, float16, float64

                                     uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.fix_      是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.flatten   是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无

 torch.Tensor.flip      是            int32                                                                 无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.fliplr    是                                                                                  无
                                     float16, float32, float16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                    255

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         API 参考




                                                                                                           限
 算子类API名称               是否支持         支持的数据类型
                                                                                                           制

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.flipud    是                                                                                  无
                                     float16, float32, float16, float64

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.float     是                                                                                  无
                                     float16, float32, float16, float64

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.float16   是                                                                                  无
                                     float16, float32, float16, float64

                                     uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.floor     是                                                                                  无
                                     float16, float32, float16, float64

                                     uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.floor_    是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.frac      是            float16, float32, float16, float64                                    无

 torch.Tensor.frac_     是            float16, float32, float16, float64                                    无

 torch.Tensor.frexp     是            float16, float32, float16, float64                                    无

 torch.Tensor.ge        是            float16, float32, bfloat16, int8 int16, int32, int64                  无

 torch.Tensor.get_de                 bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 vice                                float16, float32, float16, float64

 torch.Tensor.gt        是            float16, float32, float64, bool, int8 int16, int32, int64             无

 torch.Tensor.gt_       是            float16, float32, float64, bool, int8 int16, int32, int64             无
