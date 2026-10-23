---
id: source-teco-ops-agent-ops-sdaa-env-check-references-codex-sandbox-env-check-9751877d
title: "teco-ops-agent ops: sdaa-env-check/references/codex-sandbox-env-check.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-env-check
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-env-check/references/codex-sandbox-env-check.md
relative_source_path: sdaa-env-check/references/codex-sandbox-env-check.md
captured_at: 2026-08-04
---

# Codex 沙箱与环境检查

> **重要**：Codex 默认沙箱内执行的 `teco-smi` / `device_info.py` 结果，**不能单独作为宿主机是否有卡的依据**。沙箱可能返回 `No AiCard Device Found. SDAADriver is not loaded.`，而普通终端中设备正常。

## 1. 现象

在 **Codex 交互会话**里跑：

```bash
python3 ops/sdaa-env-check/scripts/device_info.py --json
```

可能得到：

```json
{"error": "unexpected teco-smi format: No AiCard Device Found. SDAADriver is not loaded."}
```

同时 `check_env.sh` 可能显示：`teco-smi` 在 PATH 中（pass），但 `device_query` 为 **warn**。

**原因**：Codex 在子进程/沙箱（bubblewrap）中执行命令，往往**无法访问 SDAA 驱动与设备节点**；并非 `device_info.py` 逻辑错误。

## 2. 正确判定流程

```
Codex 内 env-check
        │
        ├─ device_query pass → 可参考设备信息继续
        │
        └─ device_query warn/fail（驱动未加载等）
                │
                └─ 必须在宿主机终端复验（见下）── 以复验结果为准
```

### 宿主机复验（权威）

在 **Codex 外的普通 bash** 中执行：

```bash
cd teco-ops-agent
source /opt/tecoai/setvars.sh   # 如尚未 source
python3 ops/sdaa-env-check/scripts/device_info.py --json
bash ops/sdaa-env-check/scripts/check_env.sh --json -o /tmp/env_check.json
```

或使用仓库 CLI（同样不走 Codex 沙箱）：

```bash
python3 run_cli.py agent-ask "总结环境" --verbose
```

**Agent 结论规则**：

- Codex 沙箱内 `teco-smi` 失败 + 宿主机复验成功 → **以宿主机为准**，可声称有卡
- 两处均失败 → 驱动/硬件确实异常，按 `troubleshooting.md` 排查
- **禁止**仅依据 Codex 沙箱失败就断定「本机无加速卡」

## 3. 放宽 Codex 沙箱（可选）

若希望 **在 Codex 会话内**直接跑通 `teco-smi`，需放宽沙箱权限（视 Codex 版本而定）。

### 3.1 交互式 Codex

1. 启动：`cd teco-ops-agent && codex`
2. 在会话中调整权限（若 CLI 支持）：
   - 输入 `/permissions` 查看或修改当前沙箱策略
   - 将执行策略改为允许访问驱动/系统资源（具体选项以当前 Codex 版本 UI 为准）
3. 重新运行 `device_info.py --json` 验证

### 3.2 非交互 `codex exec`

```bash
# 工作区可写（仍可能看不到驱动）
codex exec -s workspace-write -C ~/teco-ops-agent "..."

# 完全放开沙箱（仅受信环境使用）
codex exec -s danger-full-access -C ~/teco-ops-agent "..."
```

`-s` / `--sandbox` 可选值（Codex v0.133+）：

| 模式 | 说明 |
|------|------|
| `read-only` | 默认偏严，**teco-smi 常失败** |
| `workspace-write` | 可写工作区，驱动访问仍可能受限 |
| `danger-full-access` | 无沙箱隔离，**最可能**让 `teco-smi` 与宿主机一致 |

### 3.3 bubblewrap 提示

若启动时出现：

```
Codex could not find bubblewrap on PATH ... will use the bundled bubblewrap
```

可安装系统 bubblewrap 以减少沙箱异常（不保证解决驱动可见性）：

```bash
sudo apt-get install -y bubblewrap
```

**驱动访问**仍依赖沙箱模式是否为 `danger-full-access` 或等效权限。

## 4. 与 AGENTS.md 的衔接

- Step 1 环境门禁：**仍须**在 Codex 内尝试跑 `check_env.sh` / `device_info.py`
- 若 `device_query` 非 pass：在回复中**明确标注**「Codex 沙箱结果」并建议宿主机复验命令
- 不得因沙箱误报跳过 SDK/编译链等已通过项的结论

## 5. 相关文档

- [troubleshooting.md](troubleshooting.md) — 真实驱动/硬件故障排查
- [device_commands.md](device_commands.md) — `teco-smi` 命令
- 仓库根目录 `AGENTS.md` — 总编排说明
