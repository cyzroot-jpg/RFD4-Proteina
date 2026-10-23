---
id: source-teco-ops-agent-ops-sdaa-env-check-skill-f2443912
title: "teco-ops-agent ops: sdaa-env-check/SKILL.md"
type: source-local
tags: [teco-ops-agent, ops, skill, sdaa]
confidence: source-reported
skill: sdaa-env-check
source_path: /data/application/xuelu/teco-agent-skills/skills/teco-ops-agent/ops/sdaa-env-check/SKILL.md
relative_source_path: sdaa-env-check/SKILL.md
captured_at: 2026-08-04
---

---
name: sdaa-env-check
description: SDAA 算子开发环境检查技能。用于：(1) 通过 teco-smi 查询太初 AI 加速卡设备信息（设备列表、时钟、显存、驱动版本），(2) 检查 TECO SDK 环境配置（setvars.sh、tecocc、SDAA Runtime 头文件），(3) 验证编译与运行依赖是否完整，(4) 可选检查 SDPTI SDK（性能采集）。触发关键词：环境检查、SDAA环境、teco-smi、tecocc、setvars、设备查询、检查TECO环境、SDPTI、gid、空闲设备。
---

# SDAA 环境检查

快速检查 SDAA 算子开发与运行环境，以及太初 AI 加速卡设备状态。

## 工作流程

```
环境检查
    │
    ├─ TECO SDK / 编译链检查
    │   └─ scripts/check_env.sh
    │
    ├─ 设备信息查询
    │   └─ scripts/device_info.sh / scripts/device_info.py
    │
    └─ 结构化输出（供编排器消费）
        └─ scripts/check_env.sh --json
```

## 快速命令

```bash
# 完整环境检查（推荐）
bash <SKILL_DIR>/scripts/check_env.sh

# 结构化 JSON（写入 env_check.json）
bash <SKILL_DIR>/scripts/check_env.sh --json -o env_check.json

# 设备信息综合查询
bash <SKILL_DIR>/scripts/device_info.sh

# Python 结构化设备查询
python3 <SKILL_DIR>/scripts/device_info.py --json
python3 <SKILL_DIR>/scripts/device_info.py --idle   # 空闲设备 index（gid:auto）
```

> `<SKILL_DIR>` 为本 skill 安装目录（如 `.cursor/skills/sdaa-env-check/` 或 `teco-ops-agent/ops/sdaa-env-check/`）。**禁止**在未定位 skill 目录时直接 `bash scripts/check_env.sh`。

## 检查项

| 检查项 | 说明 | 必需 |
|--------|------|------|
| `/opt/tecoai/setvars.sh` | TECO SDK 环境入口 | 是 |
| `tecocc` | SDAA 设备编译器 | 编译必需 |
| `cmake` | 工程构建 | 编译必需 |
| `sdaa_runtime.h` | SDAA Runtime 头文件 | 运行必需 |
| `teco-smi` | 设备管理 CLI | 运行/选卡必需 |
| Codex 沙箱内 `teco-smi` | 可能误报驱动未加载 | 见 [codex-sandbox-env-check.md](references/codex-sandbox-env-check.md) |
| `SDPTI_SDK_ROOT` / `sdpti_sdk_root` | 性能采集 SDK | 性能分析可选 |
| `python3` | 脚本与编排器 | 建议 ≥3.10 |

详细环境配置见 [env_config_guide.md](references/env_config_guide.md)。

## 设备查询

通过 `teco-smi` 查询当前设备（需先 `source /opt/tecoai/setvars.sh`）：

```bash
source /opt/tecoai/setvars.sh
teco-smi --query-device=clocks.spe,clocks.max.spe,memory.total,count,name,driver_version --format=csv,noheader
```

**编排器选卡约定**（与 `optest-agent` 一致）：

- `gid: auto` → 优先使用 `device_info.py --idle` 返回的空闲 index
- 无空闲设备时回退到全部可见 index

详细命令见 [device_commands.md](references/device_commands.md)。

## 诊断脚本

| 脚本 | 用途 |
|------|------|
| `scripts/check_env.sh` | SDK / 编译链 / 可选 SDPTI 环境检查 |
| `scripts/device_info.sh` | 设备信息综合查询（封装 device_info.py） |
| `scripts/device_info.py` | 结构化设备查询：`--json`、`--idle`、`--list` |

## 输出契约

使用 `--json` 时，`check_env.sh` 输出如下结构供编排器解析：

```json
{
  "status": "pass|warn|fail",
  "errors": 0,
  "warnings": 0,
  "checks": [
    {"name": "setvars", "result": "pass", "detail": "..."}
  ],
  "device": { }
}
```

`device` 字段在 `teco-smi` 可用时由 `device_info.py` 填充。

## Codex 沙箱说明

在 **Codex 交互会话**中，`teco-smi` / `device_info.py` **可能误报** `SDAADriver is not loaded`，而宿主机普通终端正常。

- **不要**仅凭 Codex 内失败断定无卡
- **必须**在宿主机终端复验，或以 `run_cli.py agent-ask` 结果为准
- 若需在 Codex 内直接访问驱动：放宽沙箱（`/permissions`、`danger-full-access` 等）

详见 [codex-sandbox-env-check.md](references/codex-sandbox-env-check.md)。

## 常见问题

- **tecocc 找不到**：先 `source /opt/tecoai/setvars.sh`，确认 TECO SDK 已安装
- **teco-smi 无输出**：检查驱动是否加载、当前用户是否有设备访问权限
- **Codex 内报 `SDAADriver is not loaded` 但宿主机正常**：Codex 沙箱隔离所致，见 [codex-sandbox-env-check.md](codex-sandbox-env-check.md)；在普通终端复验 `device_info.py --json`
- **编译通过但运行失败**：检查 `LD_LIBRARY_PATH` 是否包含算子 `.so` 所在目录（demo 工程参考 `run.sh`）
- **SDPTI 采集失败**：设置 `SDPTI_SDK_ROOT` 或在配置中指定 `sdpti_sdk_root`

详细排查见 [troubleshooting.md](references/troubleshooting.md)。
