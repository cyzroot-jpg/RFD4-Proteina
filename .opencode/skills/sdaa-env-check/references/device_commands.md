# teco-smi 设备命令参考

## 前置条件

```bash
source /opt/tecoai/setvars.sh
```

## 常用查询

### 设备硬件摘要（推荐）

```bash
teco-smi --query-device=clocks.spe,clocks.max.spe,memory.total,count,name,driver_version \
  --format=csv,noheader
```

字段含义：

| 字段 | 说明 |
|------|------|
| clocks.spe | 当前 SPE 主频 (MHz) |
| clocks.max.spe | SPE 最大主频 (MHz) |
| memory.total | 设备 Global 显存 (MB) |
| count | 可见设备数量 |
| name | 设备名称（如 TECO_AICARD_01） |
| driver_version | SDAA 驱动版本 |

### 空闲设备（gid:auto）

```bash
teco-smi --query-gpu=index,utilization.gpu --format=csv,noheader,nounits
```

编排器约定：利用率 ≤ 1% 视为空闲；无空闲时回退全部可见 index。

也可使用本 skill 脚本：

```bash
python3 scripts/device_info.py --idle
```

### 结构化 JSON

```bash
python3 scripts/device_info.py --json
python3 scripts/device_info.py --list
```

## SDAA 工具链要点

| 维度 | SDAA (teco-smi / Teco SDK) |
|------|----------------------------|
| 环境入口 | `source /opt/tecoai/setvars.sh` |
| 架构标识 | `arch: UAL_TECO100`, `chip: T1` |
| 编译器 | `tecocc` |

## 脚本封装

本 skill 的 `device_info.py` 逻辑与 `optest-agent/optest_agent/instrument.py::query_device_hardware_info()` 对齐，默认 SPE 时钟参考值：

- SPE: 2.5 GHz（分析口径）
- ACE: 1.25 GHz（半频域）
