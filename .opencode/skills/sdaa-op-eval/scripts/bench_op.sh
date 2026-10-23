#!/bin/bash
# bench_op.sh — teco-ops 算子性能评估（Average Hardware Time + 正确性）
# 用法: bench_op.sh <repo_root> <op_name> <case_ids...>
#   例: bench_op.sh /path/to/teco-ops-juzhenjisuan flash_attention 0 1 2 3 4 5
#       bench_op.sh /path/to/teco-ops-juzhenjisuan reshape_and_cache case_0 case_1 case_2
# 可选环境变量:
#   SKIP_BUILD=1          跳过 teco 库/test 框架构建（已构建过时用）
#   BASELINE_MS_<case>=x  设基线毫秒则额外输出该 case 加速比
set -euo pipefail

REPO="${1:?usage: bench_op.sh <repo_root> <op_name> <case_ids...>}"
OP="${2:?usage: bench_op.sh <repo_root> <op_name> <case_ids...>}"
shift 2
CASES=("$@")
if [ "${#CASES[@]}" -eq 0 ]; then echo "错误: 未提供 case ids"; exit 1; fi
if [ ! -f "$REPO/build.sh" ] || [ ! -d "$REPO/test" ]; then echo "错误: $REPO 不是 teco-ops 仓库根（缺 build.sh/test）"; exit 1; fi

source /opt/tecoai/setvars.sh >/dev/null 2>&1 || echo "警告: setvars.sh 未找到"

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  echo "[1/2] 构建 teco 库 ..."
  ( cd "$REPO" && bash build.sh --build teco >/tmp/bench_teco.log 2>&1 ) \
    || { echo "teco 库构建失败，见 /tmp/bench_teco.log"; exit 1; }
  echo "[2/2] 构建 test 框架 ..."
  ( cd "$REPO/test" && source env.sh >/dev/null 2>&1 && bash build.sh --arch teco -f "$OP" >/tmp/bench_test.log 2>&1 ) \
    || { echo "test 框架构建失败，见 /tmp/bench_test.log"; exit 1; }
fi

test_dir="$REPO/test"
export LD_LIBRARY_PATH="$REPO/build/teco/lib:/home/py312/lib/python3.12/site-packages/torch/lib:${LD_LIBRARY_PATH:-}"
export TECOAL_TECOTEST_PROJECT="$test_dir"

printf "%-18s %-12s %-8s %s\n" "case" "hw_time_ms" "correct" "speedup"
printf "%-18s %-12s %-8s %s\n" "--------------------" "------------" "--------" "-------"
for c in "${CASES[@]}"; do
  case_path="zoo/teco/$OP/test_case/$c.prototxt"
  out=$(cd "$test_dir" && ./build/demo --gid=0 --perf_repeat=50 --warm_repeat=3 --gtest_repeat=1 \
        --case_path="$case_path" 2>&1 || true)
  ms=$(printf '%s' "$out" | grep -oE "\[Average Hardware Time[[:space:]]*\]:[[:space:]]*[0-9.]+" \
       | grep -oE "[0-9.]+$" | head -1)
  if printf '%s' "$out" | grep -q "ALL PASSED"; then pass="PASS"; else pass="FAIL"; fi
  base_var="BASELINE_MS_${c//./_}"
  base="${!base_var:-}"
  sp=""
  if [ -n "$base" ] && [ -n "$ms" ]; then
    sp=$(python3 -c "print(f'{$base/float($ms):.2f}x')" 2>/dev/null || true)
  fi
  printf "%-18s %-12s %-8s %s\n" "$c" "${ms:-N/A}" "$pass" "${sp:-}"
done
echo "-----------------------------------------------------"
echo "注: hw_time 为 [Average Hardware Time] (warm=3, repeat=50)；PASS = 正确且 max_error 在阈值内"