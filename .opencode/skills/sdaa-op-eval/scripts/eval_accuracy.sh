#!/bin/bash
# eval_accuracy.sh — OneGenomeRice 精度评测封装（teco-ops 优化对精度影响的验收）
# 用法: eval_accuracy.sh <modelzoo_root> <host> <port> [max_samples] [workers] [baseline]
#   例: eval_accuracy.sh /path/to/tecovllm-modelzoo-juzhenjisuan 127.0.0.1 7777 200 32 0.9120
# 前置: vLLM 服务已运行且加载被测 lib（见 install_lib.sh / verify_serve.sh）
set -euo pipefail

MZ="${1:?usage: eval_accuracy.sh <modelzoo_root> <host> <port> [max_samples] [workers] [baseline]}"
HOST="${2:-127.0.0.1}"; PORT="${3:-7777}"
N="${4:-200}"; W="${5:-32}"; BASE="${6:-0.9120}"

[ -f "$MZ/tools/ci_pipline/epi_eval.py" ] || { echo "错误: $MZ 缺少 tools/ci_pipline/epi_eval.py"; exit 1; }

echo "[1/2] 等待服务就绪 ..."
for i in $(seq 1 120); do
  if curl -s --max-time 3 "http://$HOST:$PORT/health" 2>/dev/null | grep -q "OK"; then echo "  OK"; break; fi
  sleep 5
  [ "$i" -eq 120 ] && { echo "  服务未就绪"; exit 1; }
done

echo "[2/2] 运行精度评测 (N=$N, workers=$W) ..."
log=$(mktemp)
cd "$MZ"
python tools/ci_pipline/epi_eval.py --host "$HOST" --port "$PORT" \
  --max-samples "$N" --workers "$W" 2>&1 | tee "$log" | grep -E "Overall acc|Failed" || true

acc=$(grep -oE "Overall acc[[:space:]]*:[[:space:]]*[0-9.]+" "$log" | grep -oE "[0-9.]+$" | head -1)
if [ -z "$acc" ]; then echo "未解析到 Overall acc，详情见 $log"; exit 1; fi

echo "-----------------------------------------------------"
printf 'accuracy = %.4f   baseline = %.4f   允许范围 [%.4f, %.4f]\n' \
  "$acc" "$BASE" "$(python3 -c "print($BASE-0.01)")" "$(python3 -c "print($BASE+0.01)")"
python3 -c "
acc=$acc; base=$BASE
lo,hi=base-0.01,base+0.01
verdict='PASS' if lo<=acc<=hi else 'FAIL'
print(f'delta = {acc-base:+.4f}  -> {verdict}')
if verdict=='FAIL': raise SystemExit(1)
"
echo "结果已保存: $(ls -td "$MZ/tools/ci_pipline/prec_logs/"OneGenomeRice_* | head -1)/epi_eval_results.json"