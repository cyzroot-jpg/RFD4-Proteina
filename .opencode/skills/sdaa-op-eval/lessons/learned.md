# 评估踩坑记录（来自真实优化会话）

## 1. demo 找不到 Python golden → 所有 kernel 呈现相同错误码

- 现象：`epi_eval` / demo 报 `无法打开文件进行读取`,`flash_attention` 所有候选（含真基线）`max_error=747.016`，且各分支错误一致。
- 根因：demo 的 Python golden 定位依赖 `TECOAL_TECOTEST_PROJECT`（`test/env.sh` 导出）。测试数据缓存被并发破坏/未设置该变量时，参考输出缺失或错误。
- 修复：删除 `test/zoo/<op>/test_case/<case>/` 缓存重新生成；在评测驱动里显式 `export TECOAL_TECOTEST_PROJECT=$test_dir`。
- 教训：**所有候选错误码相同时，先怀疑测试环境/参考数据，不是 kernel。**

## 2. 测试环境 SPM 堆 ≠ 服务端 SPM 堆

- 现象：加了 K 双缓冲/独立 V 缓冲/PV ping-pong（+≈32KB SPM）的版本，测试环境 6 个 case 全 `ALL PASSED`、速度 1.7x；一上 vLLM 服务，worker 日志狂刷
  `flash_attention.scpp:260 spm malloc failed, size 4096` → kernel 早退 → 输出垃圾 → **精度从 0.91x 崩到 0.24x**。
- 根因：`rt_spm_malloc` 失败宏直接 `return`，kernel 不写输出；vLLM worker 可用 SPM 堆（~185KB）小于测试环境。
- 诊断：227 定位 = 崩溃点行号；用 `SPM 预算` 计算各 buffer 和。
- 修复：恢复基线缓冲布局（≈150KB），保留计算类优化；LDM 复用。
- 教训：**性能测试通过 ≠ 服务端可用，精度评测才是服务端正确性的最终验收。**

## 3. kernel 溢出 → 空输出 / detokenizer 报错

- 现象：评测 200 条全部返回空文本（`Overall acc 0.0000`），服务日志
  `TypeError: argument 'id': StreamInput must be an integer or a list of integers`。
- 根因：no-max softmax 的 `exp(S*scale)` 对真实模型 logit 超出 FP16 p_score 动态范围
  （logit>11.09 溢 FP16 → inf → PV NaN → 模型 logit NaN → sampler 输出非整数 token）。
- 诊断：用 kernel 内 `ai_printf` 打印 `max_logit`（观察到 ~12.8，>11.09）；单发 completion 直接看空文本与 detokenizer 报错。
- 教训：**生成空文本时，先怀疑 exp/softmax 溢出，不是网络/评测问题。**

## 4. 确认服务加载了被测 lib

- 现象：改了 kernel 但精度没变/结果异常，怀疑没生效。
- 关键：vLLM 的 TP **worker 进程**（`VLLM::Worker_TP*`）通过 `import tecoops` 加载
  `site-packages/tecoops/libtecoops_ops.so`；`ps` 里 API server 主进程不加载它，查错进程会误判。
- 验证：worker 启动日志 `Using tecoops flash_attn_varlen_func via BlockAttention backend`；
  `md5sum site-packages/...` 与 `build/teco/lib/...` 一致。
- 教训：**改 lib 后必须完整重启服务（API server + EngineCore + Worker_TP*），只杀主进程不够。**

## 5. 并行进程/外部干预

- 现象：会话期间仓库的 `rms_norm_fp16.scpp`、`performance_report.md`、`libteco_ops.so` 被外部改动/覆盖，与优化任务冲突。
- 对策：改动后立刻 `md5sum` 核对并紧接验证；重要状态集中在 skill 脚本与调用方确认。
- 教训：**多人/多 agent 并发修改同一仓库时，先确认 ownership 再动文件。**

## 6. 剥离诊断的数值应视为"上界"

- 现象：逐个去掉 softmax/transpose/matmul 得到各阶段"成本"，把这些数字相加 ≠ 总耗时（有重叠与调度影响）。
- 正确用法：用剥离差量排序优先级（谁最大先优化谁），不把它当精确占比。