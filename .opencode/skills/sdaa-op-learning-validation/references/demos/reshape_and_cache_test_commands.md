# reshape_and_cache 测试命令

本文记录 `reshape_and_cache` 算子优化时常用的精度和性能测试命令。

## 精度测试

优先跑 Python API 测试。该测试会调用 `python_api_test/test_reshape_and_cache.py` 中的 `reshape_and_cache_flash` CPU reference 做对拍。

```bash
cd /data/application/xuelu/teco-agent-skills/teco-ops
source /opt/tecoai/setvars.sh

WITH_TORCH=ON WITH_INFERENCE_PLUGIN=OFF python setup.py build_ext --inplace

export LD_LIBRARY_PATH=$(realpath api/tecoops):${LD_LIBRARY_PATH}
python python_api_test/test_reshape_and_cache.py
```

也可以跑 C++ optest 精度 case：

```bash
cd /data/application/xuelu/teco-agent-skills/teco-ops
source /opt/tecoai/setvars.sh
bash build.sh --build teco

cd test
source env.sh
bash build.sh --arch teco -f reshape_and_cache

./build/demo --gid=0 --perf_repeat=0 --warm_repeat=0 --gtest_repeat=1 \
  --case_path=zoo/teco/reshape_and_cache/test_case/case_0.prototxt
```

另外两个现有 case：

```bash
./build/demo --gid=0 --perf_repeat=0 --warm_repeat=0 --gtest_repeat=1 \
  --case_path=zoo/teco/reshape_and_cache/test_case/case_1.prototxt

./build/demo --gid=0 --perf_repeat=0 --warm_repeat=0 --gtest_repeat=1 \
  --case_path=zoo/teco/reshape_and_cache/test_case/case_2.prototxt
```

注意：C++ optest 会把 `slot_mapping` 改成顺序无冲突槽位，主要覆盖基础搬运路径；Python 测试更适合作为优化后的首轮精度对拍。

## 性能测试

性能测试用 C++ optest 跑，打开 `perf_repeat` 和 `warm_repeat`：

```bash
cd /data/application/xuelu/teco-agent-skills/teco-ops
source /opt/tecoai/setvars.sh
bash build.sh --build teco

cd test
source env.sh
bash build.sh --arch teco -f reshape_and_cache

./build/demo --gid=0 --perf_repeat=50 --warm_repeat=3 --gtest_repeat=1 \
  --case_path=zoo/teco/reshape_and_cache/test_case/case_0.prototxt
```

三个现有性能 case 都跑：

```bash
for c in case_0 case_1 case_2; do
  ./build/demo --gid=0 --perf_repeat=50 --warm_repeat=3 --gtest_repeat=1 \
    --case_path=zoo/teco/reshape_and_cache/test_case/${c}.prototxt
done
```

`case_0/1/2` 分别对应 `kv_heads=8/4/2`，都是 `num_tokens=512, head_dim=128, block_size=16`。如果 `gid=0` 被占用，将 `--gid=0` 换成空闲设备或核组。

## 优化流程记录

使用 `sdaa-op-learning-validation` 的 `optimize_existing` 模式优化本算子时，先建立 baseline，再进入单轮假设验证。当前推荐任务目录：

```text
op_learning/reshape_and_cache/fp16-cache-write/
```

### Baseline

先完成构建和 optest 编译：

```bash
cd /data/application/xuelu/teco-agent-skills/teco-ops
source /opt/tecoai/setvars.sh
bash build.sh --build teco

cd test
source env.sh
bash build.sh --arch teco -f reshape_and_cache
```

先跑正确性：

```bash
for c in case_0 case_1 case_2; do
  ./build/demo --gid=0 --perf_repeat=0 --warm_repeat=0 --gtest_repeat=1 \
    --case_path=zoo/teco/reshape_and_cache/test_case/${c}.prototxt
done
```

再跑性能：

```bash
for c in case_0 case_1 case_2; do
  ./build/demo --gid=0 --perf_repeat=50 --warm_repeat=3 --gtest_repeat=1 \
    --case_path=zoo/teco/reshape_and_cache/test_case/${c}.prototxt
done
```

记录每个 case 的 device time：

```text
case_0: num_tokens=512, kv_heads=8, head_dim=128
case_1: num_tokens=512, kv_heads=4, head_dim=128
case_2: num_tokens=512, kv_heads=2, head_dim=128
```

### Baseline 回填

把 baseline 结果写入：

```text
op_learning/reshape_and_cache/fp16-cache-write/stage_results/v0_baseline_probe.json
op_learning/reshape_and_cache/fp16-cache-write/learned_patterns.md
```

`v0_baseline_probe` 是 baseline 阶段，`perf_before` 和 `perf_after` 可以先填同一个代表 device time；后续优化 stage 再记录真实优化前后对比。

```json
{
  "status": "pass",
  "correctness": {
    "python_api": "pass",
    "optest": "pass"
  },
  "delivery": {
    "test_commands": "pass"
  },
  "perf_before": {
    "time_ms": 0.0
  },
  "perf_after": {
    "time_ms": 0.0
  }
}
```

回填后运行结构校验：

```bash
cd /data/application/xuelu/teco-agent-skills/teco-ops
python3 /data/application/xuelu/teco-agent-skills/skills/sdaa-op-learning-validation/scripts/validate_stage_result.py \
  op_learning/reshape_and_cache/fp16-cache-write/stage_results/v0_baseline_probe.json --json
```

### 单轮优化

第一轮代码优化建议从一个 isolated 假设开始，例如：

```text
stage: v1_copy_granularity
hypothesis: 调整 key/value cache 写入粒度可以减少阻塞式 memcpy 开销。
forbidden_changes:
- public C API
- Python API 调用签名
- cache layout 语义
- 测试 case
verification:
- case_0/1/2 正确性
- case_0/1/2 性能
```

每一轮都按固定闭环执行：

```text
记录 attempt -> 改 kernel -> 编译 -> 跑正确性 -> 跑性能 -> 写 stage_results -> validate_stage_result.py
```

一轮只验证一个主要假设。比如搬运粒度和 SPE 分工应拆成 `v1_copy_granularity`、`v2_spe_partition` 两个 stage，避免性能变化无法归因。
