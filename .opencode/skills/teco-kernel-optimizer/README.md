# SDAA Optimized Skill

[English](README.md) | **简体中文**

一个面向 **SDAA / 太初（TECO）T1** 平台的算子开发与优化 skill 集合，围绕 `teco-ops` 工作树，以 benchmark 驱动、知识库辅助的方式迭代优化 `.scpp` kernel。

这不是一个单独的工具，而是一组配合使用的 skill：hermes（或 Codex/Cursor）读取各自的 `SKILL.md`，按照其中描述的流程执行。`scripts/` 下的 Python 脚本负责确定性的部分（环境检测、benchmark、state 管理、知识库查询）。

## 整体架构

```
┌──────────────────────────────────────────────────────┐
│  teco-kernel-optimizer   迭代式 kernel 优化 skill     │
│   ├─ 优先级扫描选方法 → 生成分支 → benchmark 选 champion  │
│   ├─ 消融归因 → SASS/指令验证 → state 更新             │
│   └─ 每轮必须尝试不同的优化策略                          │
└──────────────────────────────────────────────────────┘
               ▲                        ▲
               │ 查询硬件知识              │ 查询优化经验
               │                        │
┌──────────────────────────┐  ┌────────────────────────┐
│  teco-ops-wiki          │  │  knowledge/            │
│  SDAA 硬件本语知识库       │  │  ACE / DMA / 指令拍数  │
│  SPA/SPE/LDM/DMA/RMA/   │  │  流水线 / T1 架构       │
│  ACE/pipe0/pipe1/HBM    │  │                        │
└──────────────────────────┘  └────────────────────────┘
               ▲
               │ 算子脚手架 / 环境检查 / 文档检索
               │
```

## 核心 skill：teco-kernel-optimizer

### 使用方法

```text
在 agent 中使用下面的 prompt：
@teco-kernel-optimizer 使用这个 skill 对 teco-ops 中的 <op> 算子进行优化，迭代 N 次。
```

其中 `<op>` 是 teco-ops 的测试构建目标；也可以用 `--target teco/ual/kernel/<op>/<kernel>.scpp` 指定具体文件，并用 `--case zoo/teco/<op>/test_case/case_0.prototxt` 指定测例。

### 关键差异：每轮必须尝试不同策略

**每轮迭代必须尝试不同的优化策略，不允许用 baseline 原样混过。** 这是从实战教训中得出的约束：如果所有分支都是 baseline 的拷贝，"迭代优化"就失去了探索意义。可尝试的方向包括：

- 不同 tile size（M1/N1/K1）
- 不同 core 切分（ROWS/COLS）
- 不同 pipeline 调度（操作重排、双缓冲）
- 不同同步模式
- 不同 DMA/RMA pattern
- 不同 LDM 分配

即使尝试可能失败（正确性错、性能变差），也必须尝试；从失败中分析原因，下一轮换方向。

### 输入与产物

**输入**：
1. `teco-ops` 工作树（含 `teco/` / `test/` / `build.sh`）
2. op 选择器：`--op <name>` 或 `--target <rel_path.scpp>`
3. prototxt 测例：默认 `zoo/teco/<op>/test_case/case_0.prototxt`，也可以用 `--case` 指定
4. 迭代次数 `N`（默认 3）
5. 每轮分支数 `K`（默认 4）

**产物**：同级目录下生成 `run_YYYYMMDD_HHMMSS/`：

```text
run_YYYYMMDD_HHMMSS/
├── state.json                   # 全局状态，可跨会话读取
├── env.json                     # SDAA 设备 / tecocc 环境快照
├── baseline/
│   └── bench.json               # 初始时延与正确性
├── iterv1/
│   ├── methods.json             # 本轮选出的方法（优先级扫描结果）
│   ├── analysis.md              # CoT 推理 + 风险说明
│   ├── branches/                # K 个分支候选
│   │   ├── b1/kernel.scpp + bench.json
│   │   └── …
│   ├── kernel.scpp              # champion（最快且正确的分支）
│   ├── ablations/               # leave-one-out 消融实验
│   │   └── no_<method>/kernel.scpp + bench.json
│   ├── attribution.json         # 每个方法的因果贡献（ms）
│   └── bench.json
├── iterv2/ …
├── iterv3/ …
└── summary.md                   # 总加速、瓶颈漂移、回顾
```

### teco-ops 测试契约

skill 使用 teco-ops README 和 `doc/README_OP.md` 描述的原生 C++ 测试框架：

```bash
bash build.sh --build teco

cd test
source env.sh
sh build.sh --arch teco -f <op>
./build/demo --gid=0 --perf_repeat=50 --warm_repeat=3 --gtest_repeat=1 --case_path=zoo/teco/<op>/test_case/case_0.prototxt
```

`benchmark.py` 解析 `ALL PASSED` / failure 信息作为精度结果，解析 `[Average Hardware Time]` 作为性能指标。

## teco-ops-wiki：硬件本语知识库

`teco-ops-wiki/` 把 NVIDIA 假设翻译成 SDAA 硬件本语，是优化推理的知识底座。

**覆盖范围**：
- 硬件页面：`SPA/SPE`、`SPM/LDM`、`Global memory`、`DMA`、`RMA`、`ACE`、`pipe0/pipe1`、HBM channel-bank-row
- 官方手册结构化：11 份太初 PDF（SDAA C 编程指南 v3.1.0、PCX 编程指南、性能优化手册、SDAARuntime、SDPTI、TSight、TecoSMI、Megatron-LM 等），按章节切分
- 4 个 teco 内部仓的真实代码索引（`sdcops` / `tecoal` / `tecocustom` / `tecolmk`，合计 466 个算子）
- 跨 wiki kernel 对位页：`kernel-flash-attention-sdaa`、`kernel-mla-layer-sdaa`、`kernel-paged-attention-sdaa`、`kernel-fused-moe-gating-sdaa` 等
- 共性 technique / migration：`technique-ual-branch-dispatch`、`technique-gemm-layout-dispatch`、`migration-cublas-to-tecoblas-gemm`、`migration-cudnn-to-tecodnn` 等

**查询示例**：

```bash
cd teco-ops-wiki
python3 scripts/query.py "DMA 128B 2KB channel bank" --compact
python3 scripts/query.py "SDAA C GEMM matmul broadcast" --compact
python3 scripts/query.py --tag simd-vectorization --compact
python3 scripts/get_page.py hw-ace --follow-sources
python3 scripts/get_page.py kernel-sdaa-gemm --follow-sources
```

## 快速开始

### 1. 环境准备

```bash
# 检查 SDAA 环境
which tecocc tsight sdpti
python3 -c "import torch; print(torch.cuda.is_available())"

# 确保 teco-ops 工作树存在
ls teco-ops/teco teco-ops/test teco-ops/build.sh
```

### 2. 安装 skills

```bash
# 一键安装所有 SDAA skills 到 ~/.hermes/skills/
chmod +x install_skills.sh
./install_skills.sh

# 验证安装
ls ~/.hermes/skills/
# 应看到: teco-kernel-optimizer  teco-ops-wiki  gemm-performance-modeling
```

### 3. 使用示例

```text
在 hermes 中使用:
@teco-kernel-optimizer 使用这个 skill 对 teco-ops 中的 reshape_and_cache 算子进行优化，迭代 3 次。
```

## 仓库结构

```text
sdaa-optimized-skill/
├── README.md / README.zh-CN.md         # 你在这里
├── install_skills.sh                   # 一键安装脚本（symlink 到 ~/.hermes/skills/）
├── skills/
│   └── teco-kernel-optimizer/          # 主 skill：迭代式 SDAA kernel 优化
│       ├── SKILL.md                    # skill 定义（hermes 读取）
│       ├── scripts/                    # preflight / benchmark / state / ablate / …
│       ├── references/                 # 优化目录、PMU 字段速查、方法注册表
│       ├── templates/                  # analysis.md 骨架、methods.schema.json
│       ├── examples/                   # 带注释的示例流程
│       └── LESSONS_LEARNED.md          # 实战经验总结
├── teco-ops-wiki/                     # 硬件本语知识库（独立 skill）
│   ├── SKILL.md
│   ├── wiki/                           # 技术 / kernel / migration 页面
│   ├── sources/docs/                   # 11 份官方手册结构化
│   ├── sources/repos/                  # 4 个 teco 仓的算子索引
│   ├── artifacts/repos/                # 核心算子 verbatim 快照
│   ├── candidates/                     # 审计 ledger
│   ├── scripts/                        # query / get_page / validate / import_repo
│   └── docs/gap-analysis.md            # 当前覆盖缺口
├── teco-ops/                           # teco-ops 工作树
│   ├── build.sh                        # 算子库构建脚本
│   ├── teco/                           # interface + ual 算子源码
│   └── test/                           # C++ 测试框架和 prototxt 测例
├── env*.json                           # 环境配置文件（多个变体）
└── asset/                              # README 插图
```

## 完整工作流示例

以 "优化 `gemm` 算子 3 次迭代" 为例，agent 的完整工作流：

1. **初始化**
   - 读取 `skills/teco-kernel-optimizer/SKILL.md`
   - 调用 `scripts/preflight.py` 校验 `teco-ops` 工作树 + op/case 选择
   - 初始化 `run_YYYYMMDD_HHMMSS/`，复制 baseline，跑一次 benchmark 作为基线

2. **迭代优化循环**（每轮）：
   - 调用 `teco-ops-wiki` 查询相关硬件知识（ACE/LDM/DMA pattern）
   - 优先级扫描 `references/optimization_catalog.md` 选出本轮方法
   - 写 `analysis.md`（CoT 推理 + 风险）
   - 生成 K 个**真正不同的**分支（tile / core partition / pipeline / DMA 模式）
   - 跑 benchmark 选出最快且正确的分支作为 champion
   - 对 champion 做 leave-one-out 消融，得到每个方法的因果贡献
   - 更新 state：每个方法按"是否在编译后体现 × 贡献是否超过噪声"进入 effective / ineffective / implementation_failed
   - **下一轮必须尝试不同的方法组合**

3. **收尾**
   - 迭代结束后，写 `summary.md`（加速、瓶颈漂移、回顾）
   - 生成 `attribution.json` 记录每个方法的因果贡献

### 手动调试脚本

你不需要手动驱动优化循环——那是 hermes 的工作——但调试 skill 本身时可以：

```bash
cd skills/teco-kernel-optimizer

# 环境检查
python3 scripts/check_env.py

# 预检查（验证工作树和 op 选择）
python3 scripts/preflight.py --op gemm

# 运行单次 benchmark
python3 scripts/benchmark.py --help

# 查询知识库
cd ../../teco-ops-wiki
python3 scripts/query.py "DMA 128B channel bank" --compact
```

## 常见问题排查

### 1. `tecocc` / `tsight` 找不到

```bash
# 检查 PATH
echo $PATH | tr ':' '\n' | grep -i teco

# 如果缺失，添加 SDK 路径
export PATH=/path/to/teco/sdk/bin:$PATH
```

### 2. benchmark 输出缺少 Average Hardware Time

这通常是 teco-ops demo 没有跑到性能统计阶段。检查：
- `bash build.sh --build teco` 是否成功
- `cd test && source env.sh && sh build.sh --arch teco -f <op>` 是否成功
- `--case_path` 指向的 prototxt 是否存在并覆盖目标算子
- demo stdout/stderr 中是否有用例失败或参数解析错误

### 3. 知识库查询返回空

```bash
cd teco-ops-wiki

# 检查 sources 是否完整
ls sources/docs/  # 应有 11 份手册
ls sources/repos/  # 应有 4 个 teco 仓索引

# 重新导入（如需要）
python3 scripts/import_repo.py --help
```

### 4. 安装 skills 时提示 "source missing"

`install_skills.sh` 硬编码了绝对路径。如果你的仓库不在 `/data/application/xuelu/sdaa-optimized-skill`，需要修改脚本中的路径：

```bash
# 编辑 install_skills.sh，修改 SKILLS 数组中的路径
vim install_skills.sh
```

## 限制与注意事项

- **工具链依赖**：需要 `tecocc`（SDAA 编译器）与 `tsight` / `sdpti`（profiler）在 `$PATH` 中，并且 SDAA 设备驱动正常。
- **Reference 在 teco-ops 测试框架内**：精度基线和参数来自 `test/zoo/teco/<op>/` 的测试代码与 prototxt。修改 kernel 时要保持接口与 case 匹配。
- **每轮必须尝试**：这是方法论硬约束，不是建议。Baseline 拷贝不能充当分支。
- **噪声**：短时 kernel（< 50μs）受 launch overhead 主导。建议提高 `--perf_repeat` 或增大 case dims。消融归因使用同一噪声阈值。
- **分支成本**：K=4 + 消融时，每轮要编译 K + (方法数) 个 kernel；首次构建较慢。
- **指令签名是启发式的**：汇编模式 grep 不做完整语义判定，需配合 benchmark 归因交叉验证。
- **重试有上限**：单轮最多 3 次正确性失败，超出记录并继续下一轮。

## 查看优化结果

每次优化会在同级目录生成 `run_YYYYMMDD_HHMMSS/`，包含完整的优化过程记录：

```bash
# 查看总体加速
cat run_*/summary.md | grep -A 5 "Headline"

# 查看每轮的状态
for d in run_*/; do
  echo "=== $d ==="
  cat "$d/state.json" | python3 -m json.tool | grep -E '"best_ms"|"effective_methods"'
done

# 查看某轮的消融归因
cat run_20260706_130058/iterv1/attribution.json | python3 -m json.tool

# 对比 baseline 和 champion
diff -u run_*/tree/teco/ual/kernel/<op>/<kernel>.scpp run_*/iterv3/kernel.scpp | head -50
```

### 关键文件说明

- `state.json`：全局状态，包含每轮的方法分类（effective/ineffective/implementation_failed）
- `attribution.json`：每个方法的因果贡献（ms），正值表示加速，负值表示减速
- `summary.md`：人类可读的总结，包含加速比、瓶颈漂移、经验回顾
- `bench.json`：每轮的 benchmark 原始数据（时延、正确性）
- `analysis.md`：hermes 的 CoT 推理过程，包含风险分析和优化策略选择理由

## 实战经验

`skills/teco-kernel-optimizer/LESSONS_LEARNED.md` 记录了多次优化实践中总结的经验教训，包括：
- 常见的性能瓶颈模式
- 有效的优化策略
- 容易踩的坑
- 如何判断何时停止迭代

在开始新的优化任务前，建议先阅读这份文档。

## 许可证

本 skill 集合独立于太初官方 SDK、TSight、SDPTI 与 tecocc 工具链，不重新分发这些组件。请自行安装。
