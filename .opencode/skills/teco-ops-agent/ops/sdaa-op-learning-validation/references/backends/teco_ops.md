# Backend: teco_ops

默认 backend。算子落在 `teco-ops` 的 interface + UAL 分层工程中，设备端 kernel 位于
`teco/ual/kernel/<op>/`，C++ 测试位于 `test/zoo/teco/<op>/`。

## 适用场景

- `teco-ops/teco/interface/ops/<op>.cpp` 用户 API 入口
- `teco-ops/teco/ual/args/<op>_args.h` 参数结构
- `teco-ops/teco/ual/ops/<op>/` 分支选择与 Op 类
- `teco-ops/teco/ual/kernel/<op>/*.scpp` 设备 kernel
- `teco-ops/test/zoo/teco/<op>/test_case/*.prototxt` 正确性和性能测例

## 验证方式

| 检查项 | 命令 / 字段 | 通过标准 |
|--------|-------------|----------|
| 算子库构建 | `bash build.sh --build teco` | returncode 为 0 |
| 测试构建 | `cd test && source env.sh && sh build.sh --arch teco` | returncode 为 0 |
| 正确性 | `test/build/demo --case_path=...` | returncode 为 0 |
| 性能 | `--perf_repeat` / `--warm_repeat` | demo 输出性能信息，或至少命令成功 |

## 常用命令

```bash
cd teco-ops
bash build.sh --build teco

cd test
source env.sh
sh build.sh --arch teco
./build/demo --gid=0 --perf_repeat=50 --warm_repeat=3 --gtest_repeat=1 \
  --case_path=zoo/teco/<op>/test_case/case_0.prototxt
```

也可以从 teco-ops-agent 调用统一封装：

```bash
python3 ops/kernel-bench/scripts/teco_ops_test.py \
  --op <op> --demo-root ../../teco-ops --case-path zoo/teco/<op>/test_case/case_0.prototxt --json
```

## stage_result JSON 字段

```json
{
  "correctness": {"passed": true},
  "delivery": {"delivery_status": "pass"},
  "perf_after": {"time_ms": 0.98}
}
```

## 配置文件

默认路径由 `configs/backend_config.json` 指向 `../../teco-ops`。个人路径可以在未跟踪的
`configs/backend_config.local.json` 中覆盖：

```json
{ "backends": { "teco_ops": { "demo_root": "/abs/path/to/teco-ops" } } }
```
