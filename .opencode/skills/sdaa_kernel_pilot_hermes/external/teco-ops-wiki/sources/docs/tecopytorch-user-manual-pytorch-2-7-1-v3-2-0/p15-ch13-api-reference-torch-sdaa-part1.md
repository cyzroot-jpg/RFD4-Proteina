---
id: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0-p15
title: "TecoPyTorch 用户手册（适配 PyTorch 2.7.1）v3.2.0 — 第15部分 (ch13-api-reference-torch-sdaa-part1)"
type: source-doc-part
parent_doc: doc-tecopytorch-user-manual-pytorch-2-7-1-v3-2-0
product_version: "v3.2.0"
source_file: "external/文档/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.pdf"
raw_text: "sources/docs/raw/TecoPyTorch用户手册（适配PyTorch 2.7.1）_v3.2.0.txt"
raw_line_range: "17001-19000"
architectures: [sdaa, teco-t1]
confidence: verified
tags: [tecopytorch, pytorch, torch-sdaa, sdaa, teco-t1, api-reference, torch-sdaa, cuda-compatibility]
---

# TecoPyTorch 用户手册 v3.2.0（第15部分）

> 原文行范围：`17001-19000`。本页按 `pdftotext -layout` 抽取结果逐行保留该范围内全部文本，未做内容删减。

 torch.Tensor.H         是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.half      是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.has_n                  bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 ames                                float16, float32, float16, float64

 torch.Tensor.histc     是            float32, int64                                                        无

 torch.Tensor.hsplit    是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无

 torch.Tensor.i0        是            float16, float32, float16, float64                                    无

 torch.Tensor.i0_       是            float16, float32, float16, float64                                    无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                    256

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         API 参考




                                                                                                           限
 算子类API名称                是否支持        支持的数据类型
                                                                                                           制

 torch.Tensor.imag       是           float16, float32, float64, bool, uint8, int8, int16, int32, int64     无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.int        是                                                                                 无
                                     float16, float32, float16, float64

 torch.Tensor.is_co                  bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                         是                                                                                 无
 mplex                               float16, float32, float16, float64

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.is_conj    是                                                                                 无
                                     float16, float32, float16, float64

 torch.Tensor.is_distr               bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                         是                                                                                 无
 ibuted                              float16, float32, float16, float64

 torch.Tensor.is_floa                bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                         是                                                                                 无
 ting_point                          float16, float32, float16, float64

 torch.Tensor.is_infer               bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                         是                                                                                 无
 ence                                float16, float32, float16, float64

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.is_neg     是                                                                                 无
                                     float16, float32, float16, float64

 torch.Tensor.is_sign                bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                         是                                                                                 无
 ed                                  float16, float32, float16, float64

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.isfinite   是                                                                                 无
                                     float16, float32, float16, float64

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.isinf      是                                                                                 无
                                     float16, float32, float16, float64

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.isnan      是                                                                                 无
                                     float16, float32, float16, float64

 torch.Tensor.isnegin                bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                         是                                                                                 无
 f                                   float16, float32, float16, float64

 torch.Tensor.isposin                bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                         是                                                                                 无
 f                                   float16, float32, float16, float64

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.isreal     是                                                                                 无
                                     float16, float32, float16, float64

 torch.Tensor.le         是           float16, float32, float64, bool, int8 int16, int32, int64             无



文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                    257

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                       API 参考




                                                                                                         限
 算子类API名称               是否支持         支持的数据类型
                                                                                                         制

 torch.Tensor.less      是            float16, float32, float64, bfloat16, bool, int8 int16, int32        无

 torch.Tensor.lgamm
                        是            float16, float32, float16, float64                                  无
 a

 torch.Tensor.lgamm
                        是            float16, float32, float16, float64                                  无
 a_

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.log       是                                                                                无
                                     float16, float32, float16, float64

 torch.Tensor.log_      是            float16, float32, float16, float64                                  无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.log10     是                                                                                无
                                     float16, float32, float16, float64

 torch.Tensor.log10_    是            float16, float32, float16, float64                                  无

 torch.Tensor.log1p     是            float16, float32, float16, float64                                  无

 torch.Tensor.log1p_    是            float16, float32, float16, float64                                  无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.log2      是                                                                                无
                                     float16, float32, float16, float64

 torch.Tensor.log2_     是            float16, float32, float16, float64                                  无

 torch.Tensor.logical                bool, uint8, int8, int16, int32, int64, float16, float32,
                        是                                                                                无
 _not                                float16, float64

 torch.Tensor.logical                bool, uint8, int8, int16, int32, int64, float16, float32,
                        是                                                                                无
 _not_                               float16, float64

 torch.Tensor.logit     是            float16, float32, float64, bfloat16                                 无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.long      是                                                                                无
                                     float16, float32, float16, float64

 torch.Tensor.lt        是            float16, float32, float64, bfloat16, bool, int8 int16, int32        无

 torch.Tensor.lt_       是            float16, float32, float64, bfloat16, bool, int8 int16, int32        无

 torch.Tensor.maske
                        是            float16, float32, bfloat16, int8, int64                             无
 d_fill




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                  258

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         API 参考




                                                                                                           限
 算子类API名称               是否支持         支持的数据类型
                                                                                                           制

 torch.Tensor.maske
                        是            float16, float32, bfloat16, int8, int64                               无
 d_fill_

 torch.Tensor.maske
                        是            float16, float32                                                      无
 d_scatter

 torch.Tensor.maske
                        是            float16, float32                                                      无
 d_scatter_

 torch.Tensor.maske
                        是            float16, float32, int64                                               无
 d_select

 torch.Tensor.matm
                        是            float16, float32                                                      无
 ul

 torch.Tensor.matrix
                        是            float16, float32, float16, float64                                    无
 _exp

                                     bool, uint8, int8, int16, int32, int64, float16, float32,
 torch.Tensor.max       是                                                                                  无
                                     float16, float64

 torch.Tensor.maxim
                        是            float16, float32                                                      无
 um

 torch.Tensor.mean      是            float16, float32                                                      无

 torch.Tensor.media                  bool, uint8, int8, int16, int32, int64, float16, float32,
                        是                                                                                  无
 n                                   float16, float64

 torch.Tensor.mH        是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无

                                     bool, uint8, int8, int16, int32, int64, float16, float32,
 torch.Tensor.min       是                                                                                  无
                                     float16, float64

 torch.Tensor.minim
                        是            float16, float32, int32, int64                                        无
 um

 torch.Tensor.mm        是            float16, float32                                                      无

 torch.Tensor.moved
                        是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无
 im

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.msort     是                                                                                  无
                                     float16, float32, float16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                    259

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         API 参考




                                                                                                           限
 算子类API名称               是否支持         支持的数据类型
                                                                                                           制

 torch.Tensor.mT        是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无

 torch.Tensor.mul       是            float16, float32, float64, bool, int8, int16, int32, int64, uint8     无

 torch.Tensor.mul_      是            float16, float32, float64, bool, int8, int16, int32, int64, uint8     无

 torch.Tensor.nanme                  bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 dian                                float16, float32, float16, float64

 torch.Tensor.narrow    是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无

 torch.Tensor.ndime                  bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 nsion                               float16, float32, float16, float64

                                     uint8, int8, int16, int32, int64, float16, float32, float16,
 torch.Tensor.neg       是                                                                                  无
                                     float64

                                     uint8, int8, int16, int32, int64, float16, float32, float16,
 torch.Tensor.neg_      是                                                                                  无
                                     float64

 torch.Tensor.negati                 uint8, int8, int16, int32, int64, float16, float32, float16,
                        是                                                                                  无
 ve                                  float64

 torch.Tensor.negati                 uint8, int8, int16, int32, int64, float16, float32, float16,
                        是                                                                                  无
 ve_                                 float64

 torch.Tensor.nelem                  bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 ent                                 float16, float32, float16, float64

 torch.Tensor.nonzer
                        是            float16, float32, bool, int16, int32, int64, uint8                    无
 o

 torch.Tensor.norm      是            float16, float32, float64, bfloat16                                   无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.numel     是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.permut
                        是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无
 e

 torch.Tensor.positiv                uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 e                                   float16, float32, float16, float64

 torch.Tensor.pow       是            float16, float32, float64                                             无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                    260

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         API 参考




                                                                                                           限
 算子类API名称               是否支持         支持的数据类型
                                                                                                           制

 torch.Tensor.pow_      是            float16, float32, float64                                             无

 torch.Tensor.prod      是            float16, float32, float64, int32, int64                               无

 torch.Tensor.rad2de                 bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 g                                   float16, float32, float16, float64

 torch.Tensor.rad2de                 bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 g_                                  float16, float32, float16, float64

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.ravel     是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.real      是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无

 torch.Tensor.recipro                bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 cal                                 float16, float32, float16, float64

 torch.Tensor.recipro
                        是            float16, float32, float16, float64                                    无
 cal_

                                     uint8, int8, int16, int32, int64, float16, float32, float16,
 torch.Tensor.relu      是                                                                                  无
                                     float64

                                     uint8, int8, int16, int32, int64, float16, float32, float16,
 torch.Tensor.relu_     是                                                                                  无
                                     float64

 torch.Tensor.remain
                        是            float16, float32                                                      无
 der

 torch.Tensor.remain
                        是            float16, float32                                                      无
 der_

 torch.Tensor.repeat    是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无

 torch.Tensor.reshap
                        是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无
 e

 torch.Tensor.reshap
                        是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无
 e_as

 torch.Tensor.resolve                bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 _conj                               float16, float32, float16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                     261

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         API 参考




                                                                                                           限
 算子类API名称               是否支持         支持的数据类型
                                                                                                           制

 torch.Tensor.resolve                bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 _neg                                float16, float32, float16, float64

                                     float16, float32, float64, bfloat16, bool, uint8, int8, int16,
 torch.Tensor.roll      是                                                                                  无
                                     int32, int64

 torch.Tensor.round     是            float16, float32, float16, float64                                    无

 torch.Tensor.round_    是            float16, float32, float16, float64                                    无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.rsqrt     是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.rsqrt_    是            float16, float32, float16, float64                                    无

 torch.Tensor.scatter
                        是            float32                                                               无
 _add

 torch.Tensor.scatter
                        是            float32                                                               无
 _add_

 torch.Tensor.select    是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无

 torch.Tensor.sgn       是            bool, int16, int32, int64, float16, float32, float16, float64         无

 torch.Tensor.sgn_      是            bool, int16, int32, int64, float16, float32, float16, float64         无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.short     是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.sigmoi                 bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 d                                   float16, float32, float16, float64

 torch.Tensor.sigmoi
                        是            float16, float32, float16, float64                                    无
 d_

 torch.Tensor.sign      是            bool, int16, int32, int64, float16, float32, float16, float64         无

 torch.Tensor.sign_     是            bool, int16, int32, int64, float16, float32, float16, float64         无

                                     bool, uint8, int8, int16, int32, int64, float16, float32,
 torch.Tensor.signbit   是                                                                                  无
                                     float16, float64

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.sin       是                                                                                  无
                                     float16, float32, float16, float64




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                    262

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         API 参考




                                                                                                           限
 算子类API名称               是否支持         支持的数据类型
                                                                                                           制

 torch.Tensor.sin_      是            float16, float32, float16, float64                                    无

 torch.Tensor.sinc      是            float16, float32, float16, float64                                    无

 torch.Tensor.sinc_     是            float16, float32, float16, float64                                    无

 torch.Tensor.sinh      是            float16, float32, float16, float64                                    无

 torch.Tensor.sinh_     是            float16, float32, float16, float64                                    无

 torch.Tensor.softma
                        是            float16, float32, bfloat16                                            无
 x

 torch.Tensor.sparse                 bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 _dim                                float16, float32, float16, float64

 torch.Tensor.split     是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无

 torch.Tensor.split_w
                        是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无
 ith_sizes

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.sqrt      是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.sqrt_     是            float16, float32, float16, float64                                    无

                                     bool, uint8, int8, int16, int32, int64, float16, float32,
 torch.Tensor.square    是                                                                                  无
                                     float16, float64

 torch.Tensor.square                 uint8, int8, int16, int32, int64, float16, float32, float16,
                        是                                                                                  无
 _                                   float64

 torch.Tensor.squeez                 bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 e                                   float16, float32, float16, float64

 torch.Tensor.squeez                 bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 e_                                  float16, float32, float16, float64

 torch.Tensor.storag                 bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 e_offset                            float16, float32, float16, float64

 torch.Tensor.storag                 bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                        是                                                                                  无
 e_type                              float16, float32, float16, float64

 torch.Tensor.sub       是            float16, float32, float64, int8, int16, int32, int64, uint8           无




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                    263

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                         API 参考




                                                                                                           限
 算子类API名称               是否支持         支持的数据类型
                                                                                                           制

 torch.Tensor.sub_      是            float16, float32, float64, int8, int16, int32, int64, uint8           无

 torch.Tensor.sum       是            float16, float32, float64, bfloat16, int32, int64, bool               无

 torch.Tensor.swapa
                        是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无
 xes

 torch.Tensor.swapdi
                        是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无
 ms

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.tan       是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.tan_      是            float16, float32, float16, float64                                    无

                                     bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.tanh      是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.tanh_     是            float16, float32, float16, float64                                    无

 torch.Tensor.tensor
                        是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无
 _split

 torch.Tensor.transp                 float16, float32, float64, bfloat16, bool, uint8, int8, int16,
                        是                                                                                  无
 ose                                 int32, int64

 torch.Tensor.tril      是            float16, float32, float64, bfloat16                                   无

                                     uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.trunc     是                                                                                  无
                                     float16, float32, float16, float64

                                     uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.trunc_    是                                                                                  无
                                     float16, float32, float16, float64

 torch.Tensor.unbind    是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无

 torch.Tensor.unflatt
                        是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无
 en

 torch.Tensor.unfold    是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无

 torch.Tensor.unique    是            int64                                                                 无

 torch.Tensor.unsqu
                        是            float16, float32, float64, bool, uint8, int8, int16, int32, int64     无
 eeze




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                    264

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                                           API 参考




                                                                                                             限
 算子类API名称                是否支持          支持的数据类型
                                                                                                             制

 torch.Tensor.untype                   bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
                         是                                                                                   无
 d_storage                             float16, float32, float16, float64

 torch.Tensor.view       是             float16, float32, float64, bool, uint8, int8, int16, int32, int64     无

 torch.Tensor.view_a
                         是             float16, float32, float64, bool, uint8, int8, int16, int32, int64     无
 s

 torch.Tensor.view_a
                         是             float16, float32, float64, bool, uint8, int8, int16, int32, int64     无
 s_real

 torch.Tensor.vsplit     是             float16, float32, float64, bool, uint8, int8, int16, int32, int64     无

 torch.Tensor.where      是             float16, bfloat16, int32                                              无

 torch.Tensor.xlogy      是             float16, float32                                                      无

 torch.Tensor.xlogy_     是             float16, float32                                                      无

                                       bool, uint8, uint16, uint32, uint64, int8, int16, int32, int64,
 torch.Tensor.zero_      是                                                                                   无
                                       float16, float32, float16, float64




13.1.5 torch.distributions

 算子类API名称                          是否支持         支持的数据类型                     限制

 torch.distributions.normal.Nor                 float16, float32,
                                   是                                        无
 mal                                            bfloat16

 torch.distributions.log_norma                  float16, float32,
                                   是                                        无
 l.LogNormal                                    bfloat16

 torch.distributions.exponentia                 float16, float32,
                                   是                                        无
 l.Exponential                                  bfloat16

 torch.distributions.uniform.Uni                float16, float32,
                                   是                                        无
 form                                           bfloat16

 torch.distributions.cauchy.Ca                  float16, float32,
                                   是                                        无
 uchy                                           bfloat16




文档版本：v3.2.0                        版权所有 © 太初(无锡)电子科技有限公司                                                      265

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                          API 参考




 算子类API名称                              是否支持           支持的数据类型                  限制

 torch.distributions.geometric.                       float16, float32,
                                       是                                       无
 Geometric                                            bfloat16

 torch.distributions.bernoulli.B                      float16, float32,
                                       是                                       无
 ernoulli                                             bfloat16




13.1.6 torch.random

 算子类API名称               是否支持               支持的数据类型                        限制

 torch.random.fork
                        是                  float16, float32               无
 _rng




13.1.7 torch.cuda

 算子类API名称                          是否支持                 支持的数据类型               限制

 torch.cuda.comm.broadc
                                   否                    N/A                   N/A
 ast_coalesced



13.1.8 torch.jit

 算子类API名称                  是否支持                                  支持的数据类型            限制

 torch.jit.script          否                                     N/A                N/A



13.2 TecoPyTorch与PyTorch CUDA的功能性API比对
本文主要介绍TecoPyTorch中与设备（SDAA）相关的功能性API与原生PyTorch设备（CUDA）相关的功能性API的
差异。




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                                 266

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                 API 参考




                                                                   是否支   是否语
                                   torch_sdaa接口                                备注
 torch.cuda接口                                                      持     义对齐


 torch.cuda.set_device             torch.sdaa.set_device           支持    对齐    一个
                                                                               SDAA设
                                                                               备对应
 torch.cuda.current_device         torch.sdaa.current_device       支持    对齐
                                                                               一个计
                                                                               算核心
 torch.cuda.device_count           torch.sdaa.device_count         支持    对齐    阵列SPA

 torch.cuda.init                   torch.sdaa.init                 支持    对齐    N/A

 torch.cuda.is_initialized         torch.sdaa.is_initialized       支持    对齐    N/A

 torch.cuda.synchronize            torch.sdaa.synchronize          支持    对齐    N/A

 torch.cuda.set_rng_state          torch.sdaa.set_rng_state        支持    对齐    N/A

 torch.cuda.get_rng_state          torch.sdaa.get_rng_state        支持    对齐    N/A

 torch.cuda.manual_seed            torch.sdaa.manual_seed          支持    对齐    N/A

 torch.cuda.manual_seed_a
                                   torch.sdaa.manual_seed_all      支持    对齐    N/A
 ll

 torch.cuda.default_generat
                                   torch.sdaa.default_generators   支持    对齐    N/A
 ors

 torch.cuda.Stream                 torch.sdaa.Stream               支持    对齐    N/A

 torch.cuda.current_stream         torch.sdaa.current_stream       支持    对齐    N/A

 torch.cuda.default_stream         torch.sdaa.default_stream       支持    对齐    N/A

 torch.cuda.Event                  torch.sdaa.Event                支持    对齐    N/A

 torch.cuda.empty_cache            torch.sdaa.empty_cache          支持    对齐    N/A

 torch.cuda.memory_allocat
                                   torch.sdaa.memory_allocated     支持    对齐    N/A
 ed

 torch.cuda.max_memory_            torch.sdaa.max_memory_alloca
                                                                   支持    对齐    N/A
 allocated                         ted

 torch.cuda.reset_max_me           torch.sdaa.reset_max_memory
                                                                   支持    对齐    N/A
 mory_allocated                    _allocated




文档版本：v3.2.0                          版权所有 © 太初(无锡)电子科技有限公司                           267

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                     API 参考




                                                                     是否支   是否语
                                   torch_sdaa接口                                  备注
 torch.cuda接口                                                        持     义对齐

 torch.cuda.memory_cache
                                   torch.sdaa.memory_cached          支持    对齐    N/A
 d

 torch.cuda.max_memory_c           torch.sdaa.max_memory_cache
                                                                     支持    对齐    N/A
 ached                             d

 torch.cuda.reset_max_me           torch.sdaa.reset_max_memory
                                                                     支持    对齐    N/A
 mory_cached                       _cached

 torch.cuda.memory_stats           torch.sdaa.memory_stats           支持    对齐    N/A

 torch.cuda.reset_peak_me          torch.sdaa.reset_peak_memory
                                                                     支持    对齐    N/A
 mory_stats                        _stats

 torch.cuda.memory_reserv
                                   torch.sdaa.memory_reserved        支持    对齐    N/A
 ed

 torch.cuda.max_memory_r           torch.sdaa.max_memory_reserv
                                                                     支持    对齐    N/A
 eserved                           ed

                                                                                 以
                                                                                 PyTorc
 torch.cuda.memory._record         torch.sdaa.memory.record_me
                                                                     支持    对齐    h2.1+版
 _memory_history                   mory_history
                                                                                 本为基
                                                                                 准

                                                                                 以
                                                                                 PyTorc
 torch.cuda.memory._snaps
                                   torch.sdaa.memory.snapshot        支持    对齐    h2.1+版
 hot
                                                                                 本为基
                                                                                 准

                                                                                 以
                                                                                 PyTorc
 torch.cuda.memory._dump           torch.sdaa.memory.dump_snap
                                                                     支持    对齐    h2.1+版
 _snapshot                         shot
                                                                                 本为基
                                                                                 准

 torch.cuda.get_device_na
                                   torch.sdaa.get_device_name        支持    对齐    N/A
 me

 torch.cuda.get_device_pro         torch.sdaa.get_device_propertie
                                                                     支持    对齐    N/A
 perties                           s




文档版本：v3.2.0                            版权所有 © 太初(无锡)电子科技有限公司                              268

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                API 参考




                                                                  是否支   是否语
                                   torch_sdaa接口                               备注
 torch.cuda接口                                                     持     义对齐

 torch.cuda.is_bf16_support
                                   torch.sdaa.is_bf16_supported   支持    对齐    N/A
 ed

 torch.cuda.get_device_cap
                                   N/A                            不支持   不对齐   N/A
 ability

 torch.cuda.amp                    torch.sdaa.amp                 支持    对齐    N/A

 torch.cuda.is_available           torch.sdaa.is_available        支持    对齐    N/A

 torch.cuda.nvtx                   torch.sdaa.tcpx                支持    对齐    N/A

 torch.cuda._lazy_call             N/A                            不支持   不对齐   N/A

 torch.cuda.BFloat16Tensor         N/A                            不支持   不对齐   N/A

 torch.cuda.BoolTensor             torch.sdaa.BoolTensor          支持    对齐    N/A




文档版本：v3.2.0                          版权所有 © 太初(无锡)电子科技有限公司                          269

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                          API 参考




                                                             是否支   是否语
                                   torch_sdaa接口                          备注
 torch.cuda接口                                                持     义对齐

                                                                         不支持
                                                                         以下接
                                                                         口混合
                                                                         计算：
 torch.cuda.ByteTensor             torch.sdaa.ByteTensor     支持    对齐
                                                                              tor
                                                                              ch.
                                                                              sda
                                                                              a.B
                                                                              yte
                                                                              Ten
                                                                              sor

 torch.cuda.DoubleTensor           torch.sdaa.DoubleTensor   支持    对齐         tor
                                                                              ch.
                                                                              sda
                                                                              a.D
                                                                              ou
                                                                              ble
                                                                              Ten
                                                                              sor

                                                                              tor
 torch.cuda.FloatTensor            torch.sdaa.FloatTensor    支持    对齐
                                                                              ch.
                                                                              sda
                                                                              a.Fl
                                                                              oat
                                                                              Ten
                                                                              sor

                                                                              tor
                                                                              ch.
 torch.cuda.HalfTensor             torch.sdaa.HalfTensor     支持    对齐
                                                                              sda
                                                                              a.H
                                                                              alfT
                                                                              ens
                                                                              or

                                                                              tor
                                                                              ch.
                                                                              sda
                                                                              a.In
                                                                              tTe
                                                                              nso
                                                                              r



文档版本：v3.2.0                          版权所有 © 太初(无锡)电子科技有限公司                          270

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                          API 参考




                                                             是否支   是否语
                                   torch_sdaa接口                          备注
 torch.cuda接口                                                持     义对齐

                                                                              tor
                                                                              ch.
                                                                              sda
                                                                              a.L
 torch.cuda.IntTensor              torch.sdaa.IntTensor      支持    对齐         on
                                                                              gTe
                                                                              nso
                                                                              r




 torch.cuda.LongTensor             torch.sdaa.LongTensor     支持    对齐




13.3 torch.sdaa
13.3.1 torch.sdaa.is_available

   torch.sdaa.is_available()




 功能介绍

查询当前机器上是否有可用的SDAA设备。

 参数解释

无。

 返回值

 名称              类型            说明

                               当前机器上是否有可用的SDAA设备。
                                     True：有可用的SDAA设备。
 ret             bool
                                     False：没有可用的SDAA设备。




文档版本：v3.2.0                          版权所有 © 太初(无锡)电子科技有限公司                          271

TecoPyTorch用户手册（适配PyTorch 2.7.1）                            API 参考




 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> torch.sdaa.is_available()
   True




13.3.2 torch.sdaa.device_count

   torch.sdaa.device_count()




 功能介绍

获取当前程序可用的SDAA设备的数量。

 参数解释

无。

 返回值

 名称               类型               说明

 ret              int              当前程序可用的SDAA设备的数量。


 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> torch.sdaa.device_count()
   4




13.3.3 torch.sdaa.set_device

   torch.sdaa.set_device(device)




 功能介绍

设置后续计算使用的默认SDAA设备。

 参数解释




文档版本：v3.2.0                         版权所有 © 太初(无锡)电子科技有限公司      272

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                              API 参考




 名称             类型                               说明

 device         torch.device | int | str         SDAA设备，通过此参数设置程序后续默认使用的SDAA设备。


 返回值

无。

 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> torch.sdaa.current_device()
   0
   >>> torch.sdaa.set_device(2)
   >>> torch.sdaa.current_device()
   2




13.3.4 torch.sdaa.device

   _class_ torch.sdaa.device(device: Any)




 功能介绍

SDAA设备上下文管理器，进入时设定当前设备为给定的计算设备，退出时还原到进入前的计算设备。


 参数解释

 名称                   类型                                       说明

 device               torch.device | str | int                 选定的SDAA设备编号。


 返回值

无。

 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> with torch.device(device=0): torch.sdaa.synchronize()




文档版本：v3.2.0                                版权所有 © 太初(无锡)电子科技有限公司                  273

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                  API 参考




13.3.5 torch.sdaa.current_device

   torch.sdaa.current_device()




 功能介绍

获取当前程序运行的SDAA设备编号。

 参数解释

无。

 返回值

 名称           类型             说明

 ret          int            SDAA设备编号，表示当前程序运行的SDAA设备。


 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> torch.sdaa.current_device()
   0
   >>> torch.sdaa.set_device(2)
   >>> torch.sdaa.current_device()
   2




13.3.6 torch.sdaa.synchronize

   torch.sdaa.synchronize(device_index=-1)




 功能介绍

等待目标SDAA设备上的任务全部完成。

 参数解释

 名称                    类型                    说明

                                             SDAA设备编号。
 device_index          int
                                             默认值为-1，表示当前SDAA设备。




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司          274

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                   API 参考




 返回值

无。

 使用示例

   >>> import torch_sdaa
   >>> import torch
   >>> torch.sdaa.synchronize()
   >>> torch.sdaa.synchronize(0)
   >>> torch.sdaa.synchronize('sdaa:0')
   >>> torch.sdaa.synchronize('sdaa')
   >>> torch.sdaa.synchronize(torch.device('sdaa:0'))




13.3.7 torch.sdaa.current_stream

   torch.sdaa.current_stream(device: Union[torch.device, str, int, None] = None)




 功能介绍

获取目标SDAA设备当前正在使用的流。

 参数解释

 名称             类型                              说明

                                                待查询的SDAA设备。
 device         torch.device | str | int
                                                默认值为 None，表示当前程序运行的SDAA设备。


 返回值

 名称             类型                                      说明

 ret            torch.sdaa.Stream                       目标SDAA设备当前使用的流。


 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> stream = torch.sdaa.current_stream()
   >>> stream
   <torch_sdaa.backend.Stream device=sdaa:0 sdaa_stream=0x0>




13.3.8 torch.sdaa.default_stream

文档版本：v3.2.0                                版权所有 © 太初(无锡)电子科技有限公司                      275

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                     API 参考




     torch.sdaa.default_stream(device: Union[torch.device, str, int, None] = None)




 功能介绍

获取SDAA设备默认使用的流。

 参数解释

 名称               类型                              说明

                                                  待查询的SDAA设备。
 device           torch.device | str | int
                                                  默认值为 None，表示当前程序运行的SDAA设备。


 返回值

 名称                类型                                        说明

 ret               torch.sdaa.Stream                         SDAA设备默认使用的流。


 使用示例

     >>> import torch
     >>> import torch_sdaa
     >>> stream=torch.sdaa.default_stream()
     >>> stream
     <torch_sdaa.backend.Stream device=sdaa:0 sdaa_stream=0x0>




13.3.9 torch.sdaa.stream

     torch.sdaa.stream(s: Optional[torch.sdaa.Stream])




 功能介绍

获取目标流的上下文管理器。

 参数解释

 名称               类型                                      说明

                                                          带查询的流。
 s                torch.sdaa.Stream
                                                          默认值为None，表示默认流。




文档版本：v3.2.0                                  版权所有 © 太初(无锡)电子科技有限公司                      276

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                        API 参考




 返回值

 名称            类型                                          说明

 ret           torch.sdaa.StreamContext                    构造的上下文管理器。


 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> s = torch.sdaa.Stream(device='sdaa')
   >>> with torch.sdaa.stream(s):
   ...      x = torch.randn(2, 2, device='sdaa')




13.3.10 torch.sdaa.set_stream

   torch.sdaa.set_stream(stream: torch.sdaa.Stream)




 功能介绍

设置目标流为该程序后续默认使用的流。

 参数解释

 名称                   类型                              说明

                                                      待设置的流。
 stream               torch.sdaa.Stream
                                                      默认值为None，表示默认流。


 返回值

无。

 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> s = torch.sdaa.Stream()
   >>> torch.sdaa.set_stream(s)




13.3.11 torch.sdaa.is_bf16_supported




文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司                277

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                         API 参考




     torch.sdaa.is_bf16_supported()




 功能介绍

查询SDAA设备是否支持BF16数据类型。

 参数解释

无。

 返回值

 名称                     类型                 说明

                                           SDAA设备是否支持BF16数据类型。

                                                 True：支持BF16数据类型。
 ret                    bool
                                                 False：不支持BF16数据类型。



 使用示例

     >>> import torch
     >>> import torch_sdaa
     >>> print(torch.sdaa.is_bf16_supported())
     True




13.3.12 torch.sdaa.Generator

     _class_ torch.sdaa.Generator()




 功能介绍

创建一个SDAA设备的随机数管理器。

 参数解释

无。

 返回值

 名称              类型                                     说明

 g               torch._C.Generator                     SDAA设备的随机数管理器。




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司               278

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                           API 参考




 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> torch.sdaa.Generator()
   <torch._C.Generator object at 0x7f4d942596d0>




13.3.13 torch.sdaa.random_align_nv_device

   torch.sdaa.random_align_nv_device()




 功能介绍

查看当前使用的随机数管理器的行为是否与CUDA的V100/A100版本对齐。

 参数解释

无。

 返回值

 名称            类型               说明

                                随机数管理器的行为是否与CUDA的V100/A100版本对齐。
                                     True：当前使用的随机数管理器的行为与CUDA的V100/A100版本对齐。
 ret           bool
                                     False：当前使用的随机数管理器的行为未与CUDA的V100/A100版本对齐。



 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> torch.sdaa.random_align_nv_device()
   False




   export TORCH_SDAA_ALIGN_NV_DEVICE=v100
   >>> import torch
   >>> import torch_sdaa
   >>> torch.sdaa.random_align_nv_device()
   True




13.3.14 torch.sdaa.manual_seed



文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                 279

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                  API 参考




   torch.sdaa.manual_seed(seed)




 功能介绍

为当前SDAA设备上的默认随机数管理器设置随机数种子。


     说明：

     如果程序运行在多个SDAA设备上，可以使用torch.sdaa.manual_seed_all(seed)为全部SDAA设备的默
     认随机数管理器设置随机数种子。


 参数解释

 名称                        类型               说明

 seed                      int              设置的随机数种子。


 返回值

无。

 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> torch.sdaa.manual_seed(211)




13.3.15 torch.sdaa.manual_seed_all

   torch.sdaa.manual_seed_all(seed: int)




 功能介绍

为全部SDAA设备的默认随机数管理器设置随机数种子。

 参数解释

 名称                        类型               说明

 seed                      int              设置的随机数种子。


 返回值


文档版本：v3.2.0                           版权所有 © 太初(无锡)电子科技有限公司          280

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                 API 参考




无。

 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> torch.sdaa.manual_seed_all(211)




13.3.16 torch.sdaa.seed

   torch.sdaa.seed()




 功能介绍

为当前SDAA设备上的默认随机数管理器设置随机数种子。


     说明：

          与torch.sdaa.manual_seed相比，该函数不需要手动指定随机数种子，而是使用框架默认的随机数
          种子，该随机数种子由框架随机产生。
          如果程序运行在多个SDAA设备上，可以使用torch.sdaa.seed_all()为全部SDAA设备的默认随机数管
          理器设置随机数种子。



 参数解释

无。

 返回值

 名称                            类型                    说明

 seed                          int                   随机数种子。


 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> torch.sdaa.seed()
   4435394894954098




13.3.17 torch.sdaa.seed_all



文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司         281

TecoPyTorch用户手册（适配PyTorch 2.7.1）                             API 参考




   torch.sdaa.seed_all()




 功能介绍

为全部SDAA设备的默认随机数管理器设置随机数种子。


     说明：

     与torch.sdaa.manual_seed_all相比，该函数不需要手动指定随机数种子，而是使用框架默认的随机数
     种子，该随机数种子由框架随机产生。


 参数解释

无。

 返回值

 名称                            类型                说明

 seed                          int               随机数种子。


 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> torch.sdaa.seed_all()
   2448843944740572




13.3.18 torch.sdaa.initial_seed

   torch.sdaa.initial_seed()




 功能介绍

返回当前SDAA设备上的默认随机数管理器的随机数种子。

 参数解释

无。

 返回值




文档版本：v3.2.0                          版权所有 © 太初(无锡)电子科技有限公司        282

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                        API 参考




 名称           类型            说明

 seed         int           当前SDAA设备上的默认随机数管理器使用的随机数种子。


 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> torch.sdaa.manual_seed(10)
   >>> torch.sdaa.initial_seed()
   10




13.3.19 torch.sdaa.get_rng_state

   torch.sdaa.get_rng_state(device=None)




 功能介绍

返回指定SDAA设备的默认随机数管理器的状态。


        说明：

        如果程序运行在多个SDAA设备上，可以使用torch.sdaa.get_rng_state_all(seed)返回全部SDAA设备
        的默认随机数管理器的状态。


 参数解释

 名称                 类型                                 说明

 device             torch.device | str | int | None    指定的SDAA设备。


 返回值

 名称           类型                             说明

 state        torch.ByteTensor               选定的SDAA设备对应的默认随机数管理器的状态。


 使用示例




文档版本：v3.2.0                             版权所有 © 太初(无锡)电子科技有限公司               283

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                                     API 参考




    >>> import torch
    >>> import torch_sdaa
    >>> torch.sdaa.get_rng_state()
    tensor([255, 255, 255, 255, 255, ……, 0,    0,    0,    0], dtype=torch.uint8)




13.3.20 torch.sdaa.get_rng_state_all

    torch.sdaa.get_rng_state_all()




 功能介绍

返回全部SDAA设备的默认随机数管理器的状态。

 参数解释

无

 返回值

 名称              类型                                  说明

 states          torch.ByteTensor[]                  全部SDAA设备的默认随机数管理器的状态。


 使用示例

    >>> import torch
    >>> import torch_sdaa
    >>> torch.sdaa.get_rng_state_all()
    [tensor([255, 255, 255, 255, 255, ……, 0,    0,    0,   0], dtype=torch.uint8)]




13.3.21 torch.sdaa.set_rng_state

    torch.sdaa.set_rng_state(new_state, device=None)




 功能介绍

设置指定SDAA设备的默认随机数管理器的状态。


      说明：

      如果程序运行在多个SDAA设备上，可以使用torch.sdaa.set_rng_state_all(new_states)设置全部
      SDAA设备的默认随机数管理器的状态。




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                          284

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                               API 参考




 参数解释

 名称                          类型                                 说明

 new_state                   torch.ByteTensor                   随机数管理器的状态。

 device                      torch.device | str | int | None    指定的SDAA设备。


 返回值

无。

 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> state = torch.sdaa.get_rng_state()
   >>> torch.sdaa.set_rng_state(state)




13.3.22 torch.sdaa.set_rng_state_all

   torch.sdaa.set_rng_state_all(new_states)




 功能介绍

设置全部SDAA设备的默认随机数管理器的状态。

 参数解释

 名称                        类型                                  说明

 new_states                torch.ByteTensor[]                  指定的随机数管理器的状态。


 返回值

无。

 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> states = torch.sdaa.get_rng_state_all()
   >>> torch.sdaa.set_rng_state_all(states)




文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                    285

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                           API 参考




13.3.23 torch.sdaa.StreamContext

   _class_ torch.sdaa.StreamContext(stream: Optional[torch.sdaa.Stream])




 功能介绍

在目标流上创建上下文管理器。

 参数解释

 名称            类型                 说明

                                  待创建上下文管理器的SDAA Stream。


               torch.sdaa.S              说明：
 stream
               tream
                                         在该上下文管理器中派发的所有任务都会被调度到其对应的SDAA
                                         Stream上。



 返回值

无。

 使用示例

   >>> import torch
   >>> import torch_sdaa
   >>> s = torch.sdaa.Stream(0)
   >>> s
   <torch_sdaa.backend.Stream device=sdaa:0 sdaa_stream=0x555a5483a400>
   >>> with torch.sdaa.StreamContext(s):
   ...     torch.sdaa.current_stream()
   …
   <torch_sdaa.backend.Stream device=sdaa:0 sdaa_stream=0x555a5483a400>




13.3.24 torch.sdaa.device_memory_used

   torch.sdaa.device_memory_used(device=None)




 功能介绍

获取指定SDAA设备已使用的内存大小。

 参数解释


文档版本：v3.2.0                              版权所有 © 太初(无锡)电子科技有限公司                286

TecoPyTorch用户手册（适配PyTorch 2.7.1）                                      API 参考




 名称            类型                   说明

 device        torch.device | int   SDAA设备编号。如果不指定设备，则返回当前SDAA设备已使用的内存大小。


 返回值

 名称                 类型              说明

 ret                int             返回指定SDAA设备已使用的内存大小。


 使用示例

   >>> import torch
   >>> torch.sdaa.device_memory_used(0)
   606076928




13.4 torch.sdaa.Stream

   _class_ torch.sdaa.Stream(device=None, priority=0)




 功能介绍

获取目标SDAA设备的一个流的句柄。

 参数解释

 名称                 类型                     说明
