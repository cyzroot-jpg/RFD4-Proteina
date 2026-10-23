#!/bin/bash
# install_lib.sh — 重建 teco 库并安装到 demo 库 + vLLM TP worker 加载路径
# 用法: install_lib.sh <repo_root> [site_packages_tecoops_dir]
#   site_packages_tecoops 默认 /home/py312/lib/python3.12/site-packages/tecoops
# 安装后必须重启 vLLM 服务才能生效。
set -euo pipefail

REPO="${1:?usage: install_lib.sh <repo_root> [site_packages_tecoops]}"
SITE="${2:-/home/py312/lib/python3.12/site-packages/tecoops}"

source /opt/tecoai/setvars.sh >/dev/null 2>&1 || echo "警告: setvars.sh 未找到"

echo "[1/2] 重建 teco 库 ..."
( cd "$REPO" && bash build.sh --build teco >/tmp/inst_teco.log 2>&1 ) \
  || { echo "构建失败，见 /tmp/inst_teco.log"; exit 1; }

SRC="$REPO/build/teco/lib/libteco_ops.so"
[ -f "$SRC" ] || { echo "未找到 $SRC"; exit 1; }

cp -f "$SRC" "$REPO/api/tecoops/libteco_ops.so"
echo "  -> $REPO/api/tecoops/libteco_ops.so"
if [ -d "$SITE" ]; then
  cp -f "$SRC" "$SITE/libteco_ops.so"
  echo "  -> $SITE/libteco_ops.so"
else
  echo "警告: $SITE 不存在，跳过 site-packages 安装"
fi

echo "[2/2] md5 核对:"
md5sum "$SRC" "$REPO/api/tecoops/libteco_ops.so"
[ -d "$SITE" ] && md5sum "$SITE/libteco_ops.so"
echo "完成。请重启 vLLM 服务（TP worker 在启动时加载该 lib），并确认日志出现 'Using tecoops flash_attn_varlen_func via BlockAttention backend'。"