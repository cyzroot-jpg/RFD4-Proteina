# 样例：rmsnorm_forward（fp16 norm 族）

基于一次真实 Agent 跑测沉淀：fp16 RMSNorm forward、非沙箱上卡、CMake 4.x 链接修复。

## 1. 脚手架（推荐）

```bash
python3 ops/sdaa-op-template/scripts/scaffold_op.py \
  --op rmsnorm_forward \
  --family norm \
  --smoke \
  --patch-runsh \
  --upgrade-common
```

生成物（与手写实现对齐的命名约定）：

| 文件 | 说明 |
|------|------|
| `src/rmsnorm_forward/rmsnorm_forward_fp16.hpp` | device kernel（模板含 TODO + API 提示） |
| `src/rmsnorm_forward/rmsnorm_forward_demo.swcu` | fp16 I/O demo，`rmsnorm_forward_fp16_test_kernel` |
| `src/rmsnorm_forward/rmsnorm_forward_torch_golden.py` | PyTorch golden（`x.bin`/`w.bin` f16，`ref.bin` f32） |
| `common/ual/args/rmsnorm_forward_args.h` | `RmsnormForwardFwdArgs` |
| `common/torch_io.h` | 含 `torch_load_f16` / `torch_save_f32` |

默认 smoke shape：`N=4,H=4,W=8,C=8192`（8KB half tile 对齐）。

## 2. 实现要点（device）

- **存储**：HBM/LDM 主通路 `half`；统计与归一化 `float` 累加
- **原生 API**：`batch_H2S`、`batch_Smul`、`reduce_Ssum`、`batch_Smul_a`、`batch_S2H`
- **访存**：4096 half/ tile 双缓冲 x/y；weight 按列 tile 复用
- **参考实现**：`swdnn_test_ops/src/rmsnorm_forward/rmsnorm_forward_fp16.hpp`（已跑通）

## 3. 验收（宿主机，非沙箱）

```bash
python3 ops/sdaa-op-template/scripts/torch_verify.py \
  --op rmsnorm_forward \
  --demo-root ./swdnn_test_ops \
  --build-dir build_rmsnorm_forward \
  --scope-cmake \
  --restore-cmake \
  --json
```

`torch_verify.py` 会自动：

- `scope_cmake_op` 单算子编译 + **cmake baseline**（3.10 / tecocc / LINK_FLAGS）
- 设置 `LD_LIBRARY_PATH=<build_dir>`
- `--compare` 走 golden 脚本的 `--json`（norm 族对比 `y` + `inv_rms`）

## 4. 本次跑测踩坑 → 模板已吸收

| 现象 | 处理 |
|------|------|
| `common/torch_io.h` / `verify_sanity.h` 缺失 | `scaffold_op --upgrade-common` |
| CMake `< 3.5` / 误用系统 g++ | `cmake_baseline.py` / scope 时自动 patch |
| `.swcu.o` `file format not recognized` | target `LINK_FLAGS` + `--sdaa-link` |
| 兄弟算子 .swcu 阻断链接 | `--scope-cmake --restore-cmake` |
| norm 需多 tensor golden | `torch_golden_lib.prepare_norm_fp16_case` |

## 5. 精度预期（fp16 I/O）

- `y`：atol=3e-3, rtol=2e-2（约 1 ULP @ fp16）
- `inv_rms`：atol=5e-4, rtol=5e-3

跑通参考：`success_rate=1.0`，`max_abs_err=0.001953125`（y）。
