# 五件套布局（PyTorch 精度）

## Demo 工程

| # | 路径 | 职责 |
|---|------|------|
| 1 | `src/<op>/<op>_float.hpp` | Device kernel |
| 2 | `src/<op>/<op>_demo.swcu` | 读 `x.bin`、launch、`device_out.bin`（**无 CPU golden**） |
| 3 | `src/<op>/<op>_torch_golden.py` | **PyTorch prepare/compare（L3 唯一）** |
| 4 | `common/ual/args/<op>_args.h` | Args struct |
| 5 | `run.sh` | 编译与测试入口 |
| + | `common/torch_io.h` | bin I/O |
| + | `common/verify_sanity.h` | L1/L2 |

## 数据流

```text
torch prepare → x.bin
  → demo (SDAA_TORCH_DATA_DIR) → device_out.bin
  → torch compare → PASS/FAIL
```

## opname 一致性

- `teco_slave_<op>_float` ↔ demo launch
- `<op>_float_test_kernel` ↔ run.sh `TEST_FUNC`
- `<op>_torch_golden.py` ↔ `torch_verify.py`
