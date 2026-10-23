---
id: doc-tecolibrt-user-manual-v1-2-0
title: "TecoLIBRT 用户手册 v1.2.0"
type: source-doc
source_category: official-doc
product_version: "v1.2.0"
published_at: "2026-07-02"
created_at: "2026-07-02"
captured_at: "2026-07-02"
author: "docs.tecorigin.net"
doc_kind: device-runtime-library-manual
source_file: "external/文档/TecoLIBRT用户手册-v1.2.0.md"
raw_text: "sources/docs/raw/TecoLIBRT用户手册_v1.2.0.txt"
architectures: [sdaa, teco-t1]
tags: [tecolibrt, rt, device-runtime, slave-core, ace, matmul, dma, rma, broadcast, ibcast, hardware-broadcast, col-ibcast-stride, row-ibcast-stride, count-register, spm, ldm, spe-sync, sdaa]
languages: [sdaa-c, sdaa-cpp, tecocc, zh-cn]
confidence: verified
---

# TecoLIBRT 用户手册 v1.2.0

> TecoLIBRT（rt.h）：SDAA 设备端（从核/SPE）运行时库——SPM(LDM) 管理、ACE 矩阵乘接口（load_north/west/writeback + 完成计数寄存器 north/west_count + wait）、SPE 间同步、SPE 间通信 RMA（get/put/bcast/mcast/reduce）、设备内存访问 DMA（get/put/stride/phy/trans）、以及硬件广播 DMA（ibcast / col_ibcast_stride / row_ibcast_stride，DMA 引擎 fan-out、非阻塞、回复计数器）。

这是《TecoLIBRT 用户手册 v1.2.0》的**索引页**。完整、无损的正文按章节切分在下方 `part` 子页中（共 7 部分），每个 part 保留原文全部 API 签名/参数表/约束/掩码/跨步/代码示例。原始 markdown 全文存于 `raw_text`，可逐行追溯。

## 文档元信息

- 标题：TecoLIBRT 用户手册
- 版本：v1.2.0
- 定位：SDAA **设备端从核（SPE）运行时库** rt.h（vendor 内核 `#include "tecolibrt/include/rt.h"` 所用）
- 原始文档：`external/文档/TecoLIBRT用户手册-v1.2.0.md`
- 原始全文：`sources/docs/raw/TecoLIBRT用户手册_v1.2.0.txt`（markdown，完整无删减，7565 行）
- 共 145 节 API 参考。

## 与 GEMM 单 SPA 优化的关联（为何重要）

vendor 单 SPA GEMM 41T 的关键原语全部文档化于此手册：
- **硬件广播**（第 108–123 章）：`rt_dma_col_ibcast_stride` / `rt_dma_row_ibcast_stride`（DMA 引擎 fan-out，一发写整列/整行 SPE 的 LDM，非阻塞 + 回复计数器）——公开 `sdaa::broadcast` 无此能力。
- **ACE 完成计数门控**（第 30–33 章）：`rt_ace_north_count` / `rt_ace_west_count` / `rt_wait_north` / `rt_wait_west`——非阻塞 depth-3 DMA/ACE 重叠的门控。
- **ACE 计算**（第 25–29 章）：`rt_ace_config_kernel` / `load_north` / `load_west` / `writeback` / `barrier_kernel`。
- **DMA/SPM/同步**（第 9–23、78–107 章）：`rt_ldm_malloc`、`rt_dma_iget_stride`、`rt_dma_wait_value`、`rt_synchronized_*`。

## 完整内容分卷（part 子页）

| Part | 覆盖章节 | 原文行范围 | 主题 | 页面 |
|------|---------|-----------|------|------|
| p01 | ch1-13 | 154-809 | 概述/核心概念/命名/快速入门/预定义变量(rt_tid/rid/cid)/SPM 管理(rt_ldm_malloc) | `doc-tecolibrt-user-manual-v1-2-0-p01` |
| p02 | ch14-33 | 810-1475 | 计算接口(ACE matmul): config/load_north/load_west/writeback/barrier + north/west_count + wait + SPE 间同步 | `doc-tecolibrt-user-manual-v1-2-0-p02` |
| p03 | ch34-60 | 1476-2754 | 远程访问 SPM + SPE 间通信 RMA: rt_rma/get/put + 广播 bcast/ibcast/col_ibcast | `doc-tecolibrt-user-manual-v1-2-0-p03` |
| p04 | ch61-77 | 2755-3797 | RMA 广播(不接收) + 行/列多播 mcast | `doc-tecolibrt-user-manual-v1-2-0-p04` |
| p05 | ch78-107 | 3798-5509 | 设备内存访问 DMA: rt_dma/get/put/stride/phy/trans/unaligned | `doc-tecolibrt-user-manual-v1-2-0-p05` |
| p06 | ch108-123 | 5510-6321 | **硬件广播 DMA: ibcast / col_ibcast_stride / row_ibcast_stride** | `doc-tecolibrt-user-manual-v1-2-0-p06` |
| p07 | ch124-145 | 6322-7565 | 规约 reduce/allreduce + 检查(align/equal) + 打印(log/warning) + 常见问题 | `doc-tecolibrt-user-manual-v1-2-0-p07` |

## 章节目录（原文，145 节）

  - 1. TecoLIBRT用户手册
  - 2. 什么是TecoLIBRT
  - 3. 核心概念
  - 4. 命名规则
  - 5. 最新动态
  - 6. 快速入门
  - 7. 功能特性
  - 8. 预定义变量
  - 9. SPM管理
  - 10. rt_ldm_malloc()
  - 11. rt_ldm_malloc_try_left()
  - 12. rt_ldm_malloc_try_right()
  - 13. rt_ldm_free()
  - 14. 计算接口
  - 15. SPE间同步
  - 16. rt_synchronized_array()
  - 17. rt_synchronized_col()
  - 18. rt_synchronized_row()
  - 19. rt_synchronized_peer()
  - 20. rt_synchronized_col_p2p()
  - 21. rt_synchronized_row_p2p()
  - 22. rt_synchronized_col_lefthalf()
  - 23. rt_synchronized_col_righthalf()
  - 24. 矩阵乘法
  - 25. rt_ace_config_kernel()
  - 26. rt_ace_load_north()
  - 27. rt_ace_load_west()
  - 28. rt_ace_writeback()
  - 29. rt_ace_barrier_kernel()
  - 30. rt_ace_north_count()
  - 31. rt_ace_west_count()
  - 32. rt_wait_north()
  - 33. rt_wait_west()
  - 34. 远程访问SPM
  - 35. rt_remote_load()
  - 36. rt_remote_store()
  - 37. 时间统计
  - 38. rt_time_cycle()
  - 39. SPE间通信
  - 40. 通用接口
  - 41. rt_rma()
  - 42. rt_rma_wait_value()
  - 43. rt_memcpy()
  - 44. rt_memmove()
  - 45. 数据读取
  - 46. rt_rma_get()
  - 47. rt_rma_iget()
  - 48. 数据写出
  - 49. rt_rma_put()
  - 50. rt_rma_iput()
  - 51. 广播操作
  - 52. 广播发起的SPE接收广播数据
  - 53. rt_rma_bcast()
  - 54. rt_rma_ibcast()
  - 55. rt_rma_col_bcast()
  - 56. rt_rma_col_ibcast()
  - 57. rt_rma_row_bcast()
  - 58. rt_rma_row_ibcast()
  - 59. rt_rma_col_bcast_coll()
  - 60. rt_rma_row_bcast_coll()
  - 61. 广播发起的SPE不接收广播数据
  - 62. rt_rma_bcast_other()
  - 63. rt_rma_col_bcast_other()
  - 64. rt_rma_col_ibcast_other()
  - 65. rt_rma_row_bcast_other()
  - 66. rt_rma_row_ibcast_other()
  - 67. rt_rma_col_bcast_coll_other()
  - 68. rt_rma_row_bcast_coll_other()
  - 69. 行/列多播
  - 70. rt_rma_col_mcast()
  - 71. rt_rma_col_imcast()
  - 72. rt_rma_col_mcast_other()
  - 73. rt_rma_col_imcast_other()
  - 74. rt_rma_row_mcast()
  - 75. rt_rma_row_imcast()
  - 76. rt_rma_row_mcast_other()
  - 77. rt_rma_row_imcast_other()
  - 78. 设备内存访问
  - 79. 通用接口
  - 80. rt_dma()
  - 81. rt_dma_wait_value()
  - 82. 数据读取
  - 83. rt_dma_get()
  - 84. rt_dma_iget()
  - 85. rt_dma_get_stride()
  - 86. rt_dma_iget_stride()
  - 87. rt_dma_phy_get()
  - 88. rt_dma_phy_iget()
  - 89. rt_dma_phy_get_stride()
  - 90. rt_dma_phy_iget_stride()
  - 91. rt_h_dma_trans_get()
  - 92. rt_h_dma_trans_iget()
  - 93. rt_s_dma_trans_get()
  - 94. rt_s_dma_trans_iget()
  - 95. rt_unaligned_dma_get()
  - 96. rt_unaligned_dma_get_stride()
  - 97. 数据写出
  - 98. rt_dma_put()
  - 99. rt_dma_iput()
  - 100. rt_dma_put_stride()
  - 101. rt_dma_iput_stride()
  - 102. rt_dma_phy_put()
  - 103. rt_dma_phy_iput()
  - 104. rt_dma_phy_put_stride()
  - 105. rt_dma_phy_iput_stride()
  - 106. rt_unaligned_dma_put()
  - 107. rt_unaligned_dma_put_stride()
  - 108. 广播操作
  - 109. 全广播
  - 110. rt_dma_ibcast()
  - 111. rt_dma_ibcast_stride()
  - 112. rt_h_dma_trans_ibcast()
  - 113. rt_s_dma_trans_ibcast()
  - 114. 列广播
  - 115. rt_dma_col_ibcast()
  - 116. rt_dma_col_ibcast_stride()
  - 117. rt_h_dma_trans_col_ibcast()
  - 118. rt_s_dma_trans_col_ibcast()
  - 119. 行广播
  - 120. rt_dma_row_ibcast()
  - 121. rt_dma_row_ibcast_stride()
  - 122. rt_h_dma_trans_row_ibcast()
  - 123. rt_s_dma_trans_row_ibcast()
  - 124. 规约操作
  - 125. rt_rma_allreduce()
  - 126. rt_rma_reduce()
  - 127. rt_rma_allreduce_to()
  - 128. rt_rma_col_reduce()
  - 129. rt_rma_col_reduce_to()
  - 130. rt_rma_row_reduce()
  - 131. rt_rma_row_reduce_to()
  - 132. 检查与打印
  - 133. 检查接口
  - 134. rt_align_n()
  - 135. rt_equal_f()
  - 136. rt_nequal_f()
  - 137. rt_equal_zero_f()
  - 138. rt_nequal_zero_f()
  - 139. 打印接口
  - 140. rt_log()
  - 141. rt_log_if()
  - 142. rt_warning()
  - 143. rt_warning_if()
  - 144. 常见问题
  - 145. 版权声明
