# SDAA 环境变量配置指南

本文档基于 `swdnn_test_ops` demo 工程实践整理。

## 配置流程

### 场景 1：仅编译算子（demo / swdnn_test_ops）

```bash
source /opt/tecoai/setvars.sh
cd /path/to/swdnn_test_ops
./run.sh <op_name>
```

`run.sh` 会自动：CMake 编译 `libswdnn_test.so` → `tecocc` 编译测试入口 → 设置 `LD_LIBRARY_PATH` → 运行。

### 场景 2：性能采集（optest-agent / SDPTI）

```bash
source /opt/tecoai/setvars.sh
export SDPTI_SDK_ROOT=/path/to/sdpti   # 含 include/ 与 lib64/
python3 run_cli.py run --config configs/rms_collect.json
```

## 环境变量说明

| 环境变量 | 配置方式 | 必需场景 |
|---------|---------|---------|
| （通过 setvars.sh 注入） | `source /opt/tecoai/setvars.sh` | 编译 + 运行 |
| `LD_LIBRARY_PATH` | 追加算子 `.so` 目录 | 运行 demo 算子 |
| `SDAA_AI_PRINT` | `export SDAA_AI_PRINT=1` | 调试打印（demo 默认开启） |
| `SDPTI_SDK_ROOT` | 手动 export 或 config 指定 | SDPTI 性能采集 |
| `TECOAI_ROOT` / `SDAA_HOME` | 部分环境自定义 SDK 根路径 | 非标准安装路径 |
| `TECO_ENABLE_DUMP_INFO` | `=1` | prototxt dump（ST 调试） |

## demo 工程额外约定

`swdnn_test_ops` 使用 submodule 提供头文件依赖：

```text
thirdParty/tecokernel  -> 计算原语库头文件
thirdParty/tecolibrt   -> 运行时库头文件
```

拉取：

```bash
git submodule update --init --recursive
```

## 常见错误

### 错误 1：未 source setvars.sh

**现象**：`tecocc: command not found` 或找不到 `sdaa_runtime.h`。  
**解决**：`source /opt/tecoai/setvars.sh`

### 错误 2：LD_LIBRARY_PATH 未包含 .so

**现象**：运行时报找不到 `libswdnn_test.so`。  
**解决**：`export LD_LIBRARY_PATH=/path/to/build:$LD_LIBRARY_PATH`（`run.sh` 已自动设置）

### 错误 3：SDPTI 采集失败

**现象**：`Cannot find a usable SDPTI SDK root`。  
**解决**：设置 `SDPTI_SDK_ROOT` 或在 config 中填写 `sdpti_sdk_root`
