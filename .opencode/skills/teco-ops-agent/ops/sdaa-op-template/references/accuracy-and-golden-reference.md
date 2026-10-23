# 精度保证（PyTorch only）

## 分层验收

| 层 | 工具 | 通过标准 |
|----|------|----------|
| L0 | `torch_verify.py --build-only` | `libswdnn_test.so` |
| L1 | `verify_preflight_sdaa` / `verify_launch_ok` | launch 无错 |
| L2 | `verify_not_all_zero_*` | 输出非全 0 |
| L3 | **`torch_verify.py`** | `compare_result.passed == true` |

**L3 仅 PyTorch**。禁止 C++ `cpu_*_forward` 与 `compare_data_*`。

## PyTorch Golden 原则

1. 输入由 `torch_golden.py --prepare` 生成（固定 seed，`x.bin`）
2. `golden()` 使用 `torch` / `torch.nn.functional` 等成熟算子
3. fp16 device：golden 用 float32，compare 前统一 dtype
4. 多遍 kernel：golden 语义与 device 一致（轴、shape）

详见 [pytorch-golden-reference.md](pytorch-golden-reference.md)、[pytorch-tolerance.md](pytorch-tolerance.md)。

## Shape 首轮建议

- `cols` 用 1024 等 2 的幂（`--smoke`）
- 通过 L3 后再测奇数维 / 大 shape

## 诊断

| 现象 | 处理 |
|------|------|
| `SDAA_TORCH_DATA_DIR unset` | 必须用 `torch_verify.py`，不要直接 `./run.sh` |
| 大量 device=0 | SPE/DMA，见 device-parallel-patterns |
| compare FAIL 但 L2 过 | 调 `golden()` 或 atol/rtol |

```bash
python3 ops/sdaa-op-template/scripts/torch_verify.py \
  --op my_op --scope-cmake --restore-cmake
```
