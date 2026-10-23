# 样例：matrix_add（PyTorch golden）

## golden()

```python
def golden(x, m):
    # 二元：prepare 时另写 b.bin，或 x 为拼接；示例一元占位
    return x + x  # 替换为 torch 语义：a + b
```

## 验收

```bash
python3 ops/sdaa-op-template/scripts/torch_verify.py \
  --op matrix_add --scope-cmake --restore-cmake
```

不再使用 `cpu_matrix_add_forward` / `compare_data_f32`。
