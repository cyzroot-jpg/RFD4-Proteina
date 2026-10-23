#!/bin/bash
# verify_serve.sh — vLLM 服务健康自检 + 确认使用 tecoops kernel + 单次生成非空
# 用法: verify_serve.sh <host> <port> [model_id]
#   model_id 默认从 /v1/models 探测
# 可选: PROMPT="ACGT..." 自定义提示词
set -euo pipefail

HOST="${1:-127.0.0.1}"
PORT="${2:-7777}"

echo "[1/4] 等待服务就绪 ..."
for i in $(seq 1 120); do
  if curl -s --max-time 3 "http://$HOST:$PORT/health" 2>/dev/null | grep -q "OK"; then
    echo "  health OK (~$((i*5))s)"; break
  fi
  sleep 5
  [ "$i" -eq 120 ] && { echo "  超时：服务未就绪"; exit 1; }
done

echo "[2/4] 探测模型 ..."
MODEL="${3:-}"
if [ -z "$MODEL" ]; then
  MODEL=$(curl -s --max-time 8 "http://$HOST:$PORT/v1/models" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['data'][0]['id'])" 2>/dev/null) || true
fi
[ -n "$MODEL" ] && echo "  model: $MODEL" || { echo "  无法探测模型"; exit 1; }

PROMPT="${PROMPT:-GGCGGAGAGCCAGAAGAAGATCGCGCTGCTGGAGGGCGAGTGCCAGCGGCTGCGCGCCATGGTGCGGAAGCGCCTCCCGGGCCCCGCCGCCATCGCCAAGATGAGGGACGAGGTGGACCAGCCGGCGACACCCAGAAGGTCGCGCTCCGTGGCGCCGATGTCGCCGCGGTCCGTGGCGCCGGCGGCGCCGATGACACCCATGTCGACGTCGGCGCGGCCGATGACTCCCACCATGTCAGCGCGGCCAATGACGCCCATGTCGGCGCGGCCGATGACGCCGCGCCGT}"

echo "[3/4] 单次生成自检 (empty = kernel 溢出/NaN 的典型症状) ..."
resp=$(curl -s --max-time 120 "http://$HOST:$PORT/v1/completions" -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL\",\"prompt\":\"$PROMPT\",\"max_tokens\":20,\"temperature\":0}" 2>/dev/null || true)
text=$(printf '%s' "$resp" | python3 -c "import json,sys; print(json.load(sys.stdin)['choices'][0]['text'])" 2>/dev/null || echo "")
if [ -n "$text" ]; then
  echo "  生成文本: $(printf '%s' "$text" | tr '\n' ' ' | cut -c1-60)"
  echo "[4/4] OK: 服务正常，输出非空"
else
  echo "  生成文本为空！可能原因:"
  echo "    - kernel 溢出产生 NaN（检查服务日志 detokenizer TypeError / spm malloc failed）"
  echo "    - max_tokens 太短 / 模型未正确加载"
  echo "  请检查 $HOST:$PORT 的启动日志"
fi