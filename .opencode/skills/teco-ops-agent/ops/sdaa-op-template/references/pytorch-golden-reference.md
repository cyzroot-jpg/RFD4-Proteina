# PyTorch Golden 精度验证

> C++ demo **仅**执行 device 并 dump `device_out.bin`。**权威 golden 全部由 PyTorch 计算。**

## 禁止项

- C++ `cpu_*_forward`
- `compare_data_*` / `test_data.h` 精度比对
- 无 `SDAA_TORCH_DATA_DIR` 直接 `./run.sh` 并宣称精度 PASS

## 三件套

```
src/<op>/<op>_demo.swcu           # 读 x.bin → kernel → device_out.bin
src/<op>/<op>_torch_golden.py     # prepare + compare
common/torch_io.h
```

## 命令

```bash
python3 ops/sdaa-op-template/scripts/torch_verify.py \
  --op my_op --demo-root ./swdnn_test_ops --scope-cmake --restore-cmake
```

此命令必须在非 Codex 沙箱环境执行，因为它同时依赖 PyTorch CUDA golden、SDAA 编译器和
SDAA 设备运行。Codex 沙箱中的 `torch.cuda.is_available()` / `teco-smi` 结果不能作为验收依据。

## 数据流

```text
prepare → build/torch_golden/<op>/{x.bin, meta.json}
run.sh (SDAA_TORCH_DATA_DIR=...) → device_out.bin
compare → torch golden vs device_out.bin
```

## 默认设备

新算子的 PyTorch golden 应通过 `torch_golden_lib.setup_torch_golden(seed)` 初始化随机种子和设备。
默认 `TORCH_GOLDEN_DEVICE=auto`：

- 有 CUDA：使用 `cuda:0` 生成输入和 golden
- 无 CUDA：回退到 CPU
- 指定 `TORCH_GOLDEN_DEVICE=cpu` 可强制 CPU
- 指定 `TORCH_GOLDEN_DEVICE=cuda:1` 可选其他 GPU

CUDA golden 会关闭 TF32，避免 fp32 matmul 参考值被 TF32 近似影响。
`torch_verify.py` 默认要求 `meta.json` 记录 `torch_device` 为 `cuda:*`；CPU golden 只有在显式传
`--allow-cpu-golden` 或设置 `TORCH_VERIFY_ALLOW_CPU_GOLDEN=1` 时才放行。

## 自定义 golden

编辑 `golden()` in `<op>_torch_golden.py`：

```python
def golden(x: torch.Tensor, m: dict) -> torch.Tensor:
    rows, cols = int(m["rows"]), int(m["cols"])
    return torch.softmax(x.view(rows, cols), dim=-1).reshape(-1)
```

容差见 [pytorch-tolerance.md](pytorch-tolerance.md)。
