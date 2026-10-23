# SDAA 环境排查

## 编译阶段

| 现象 | 可能原因 | 处理 |
|------|---------|------|
| `tecocc: command not found` | 未 source setvars | `source /opt/tecoai/setvars.sh` |
| `sdaa_runtime.h: No such file` | SDK 未安装或路径错误 | 检查 `/opt/tecoai/include` |
| CMake 找不到 tecokernel/tecolibrt | submodule 未初始化 | `git submodule update --init --recursive` |
| `.swcu` 编译失败 | 语法/对齐/API 约束 | 查 TecoLIBRT 4B/128B 对齐要求 |

## 运行阶段

| 现象 | 可能原因 | 处理 |
|------|---------|------|
| `teco-smi` 无输出 | 驱动未加载或无设备 | 检查硬件连接与驱动安装 |
| Codex 内 `No AiCard Device Found` | Codex 沙箱看不到驱动 | 宿主机终端复验；或 `codex exec -s danger-full-access` / `/permissions` |
| 算子输出全 0 / 随机值 | DMA 未同步、LDM 未初始化 | 检查 `rt_dma_get/put` 与 reply wait |
| 精度不达标 | 阈值过严或 kernel 逻辑错误 | 对照 CPU golden，查 `compare_data_f32_*` 阈值 |
| ACE 结果不稳定 | 频率/半频域相关问题 | 参考 SWAI ACE 文档中的频率稳定性说明 |

## 性能采集阶段

| 现象 | 可能原因 | 处理 |
|------|---------|------|
| SDPTI 找不到 SDK | 未设置 `SDPTI_SDK_ROOT` | 配置 sdpti 根目录 |
| v2 插桩编译失败 | 源码含不支持的语句结构 | 使用 `--generate-only` 先检查插桩产物 |
| pipeline 显示 0% Compute | 标量循环未识别为 SIMD | 改用 `simd_load/store` 模式 |

## 检查顺序建议

1. `bash scripts/check_env.sh`
2. `python3 scripts/device_info.py --json`
3. `cd swdnn_test_ops && ./run.sh <op>` 验证精度
4. （可选）`python3 run_cli.py v2-run --config configs/<op>_v2_instrument.json` 验证性能链
