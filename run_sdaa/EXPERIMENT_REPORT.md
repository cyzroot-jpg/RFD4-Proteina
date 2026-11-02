# RFD4-Proteina SDAA vs CUDA 实验报告

日期：2026-10-27 / 2026-10-28
代码：`00b916c63abe910df3f2f8f0af7222ebb253fca8`
权重：`nvidia/RFD4-Proteina` @ `a06e2509…`（`model.safetensors` sha256 `5b549dd6…`）

---

## 0. 结论先行

1. **适配正确，没有系统性平台误差。** 同权重、同代码、同 oracle；几何/条件/离线指标一致，32/32 设计可 refold。
2. **两边不等价。** 逐设计 sequence identity 只有 0.68 / 0.64 / 0.38 / 0.79 / 0.30（monomer short/medium/long、motif、PPI）。
3. **B 类（refold）差异不是 oracle 噪声**，而是设计不同：oracle σ 很小，观测差是 2σ 的 2–18 倍，且 identity 与 |Δ| 强相关。
4. **数值根因已定位到注意力实现（对 monomer）**：第一次 trunk 调用两边就差 0.2–1.1%；在 CUDA 上强制显式 einsum 后，monomer-short 的 identity 0.682 → 0.890、design RMSD 1.160 → 0.123 Å。
5. **cuEquivariance 与 bf16 不是主因**（`no_cuet` 与 base 相同，`fp32` 仅小幅变化）；motif/PPI 的残余差异来自其他算子或更强的累积，尚未定位到单一算子。
6. **设计质量与平台无关，是当前主要问题**：motif 可设计性差且坍缩（1 个结构簇）、PPI binder 放置差、developability pass 仅 0–0.33。

---

## 1. 目的

回答三个问题：

1. **适配是否正确**：SDAA 上是不是同一个模型算出来的，有没有系统性平台误差？
2. **两边差多少**：A 类（pre-oracle 设计指标）与 B 类（AF3/OF3 refold）分别差在哪？
3. **差异从哪来**：是 oracle 噪声、指标实现，还是生成的设计不同；若是设计不同，具体是哪段数值路径？

---

## 2. 实验设置

| 项目 | SDAA | CUDA |
| --- | --- | --- |
| 硬件 | Teco SDAA，每任务独占一张物理卡 | A100（refold、E1–E3、D1–D2 在同一台） |
| 生成 | `run_sdaa/run_all.sh`（官方 `generate`） | 同一套脚本 |
| seed / 采样 | 1234，thinking_medium（60 steps / 180 passes），eager | 同左 |
| 精度 / batch | `bf16-mixed` / 1 | 同左 |
| RNG 对齐 | `TORCH_SDAA_ALIGN_NV_DEVICE=a100` | —（对齐目标） |
| oracle | 无 AF3/OF3 | OF3（`metrics/refolding_oracles=of3`） |
| 任务 / 设计数 | monomer short/medium/long、motif-1BCF、ppi-pdl1（8/6/4/8/6 = 32） | 同左 |

关键控制：

- 权重 sha256 相同；`src/`、`configs/` 在运行 commit 上 0 改动；无自定义 CUDA 算子；
- RNG 对齐后两边 `randn(5)` 第 1 个数逐位相同、其余相对差 <5.2e-7；
- 所有 refold 在同一台 A100、同一 OF3 oracle 上计算；E3 用同一固定 seed 重算两边；
- D1 两边用完全相同的命令（`nsteps=20`、1 设计、seed 1234）；D2 用 60 步、8 设计、参考集为 SDAA 对齐设计。

---

## 3. 实验清单

| 编号 | 目的 | 做法 | 产物 |
| --- | --- | --- | --- |
| **A 类** | 同噪声下设计指标是否一致 | 两边生成 + inline/离线指标 | `metrics.csv`、§4.1 |
| **B 类** | 设计可复现性是否一致 | 两边 CIF 在 CUDA 上 refold | pLDDT/pTM/RMSD、§4.2 |
| **pass+聚类** | 最终产出质量与多样性 | refold + FoldSeek | 普通/聚类后 pass、§4.3 |
| **E1** | 两边是不是同一批设计 | 按文件配对比较 CIF：序列 identity、design backbone RMSD | `pairs.csv`、§4.4 |
| **E2** | oracle 自身噪声多大 | 同一 CIF，seed 0/1/2 重复 refold（2 设计/任务） | `oracle_sigma.csv`、§4.5 |
| **E3** | abs(Δ) 是否超出 2σ、与 identity 的关系 | 两边逐设计 refold CSV + E1 + E2 | `attribution.md`、§4.6 |
| **D1** | 第一次 trunk 调用是否已不同 | 同输入/同噪声，dump 第一层输入输出并逐张量比较 | `call0.pt`、§4.7 |
| **D2** | 哪条数值路径造成分叉 | CUDA 上 8 个消融变体 × 8 设计，对比 SDAA 参考 | `summary.md`、§4.8 |
| **E 探针** | 实际注意力路径、误差放大、首个分叉 module、算子预算 | 两边各跑 `run_probe.sh`（对齐，20 步 × 1 设计） | fidelity/layers/ops 对比 |

脚本：`run_sdaa/experiments/`。E1–E3 产物：`linshi2/2222/out/`；D1–D2 产物：`linshi2/333333/out/`。

---

## 4. 结果

### 4.1 A 类：几何与条件一致，均值收敛

- 两边 32/32 设计 `bad_bond = clash = 0`。
- motif design-vs-input RMSD 0.1619 Å vs ~0.16 Å；PPI 盐桥 3.83 vs 3.17。
- monomer（SDAA / CUDA）：helix 0.819/0.838、0.713/0.718、0.689/0.694；GRAVY 差 ≤0.03；
  instability 差 ≤9。
- PPI 仍分叉：GRAVY −0.220/−0.451、instability 31.2/50.2、H-bond 8.67/4.67。

### 4.2 B 类：refold 指标可见差异

| 任务 | pLDDT (S/C) | pTM (S/C) | backbone RMSD (S/C, Å) | 其他 |
| --- | --- | --- | --- | --- |
| monomer-short | 82.85 / 88.64 | 74.88 / 82.50 | 2.02 / 0.404 | |
| monomer-medium | 81.16 / 88.09 | 74.83 / 84.17 | 2.05 / 0.554 | |
| monomer-long | 85.07 / 81.72 | 77.75 / 77.25 | 2.37 / 2.255 | |
| motif-1BCF | 73.93 / 75.46 | 60.13 / 60.25 | 6.48 / 4.964 | motif all-atom 5.93/4.814；CA 5.12/4.143 |
| ppi-pdl1 | 87.15 / 87.86 | 74.67 / 76.67 | 7.70 / 4.626 | ipTM 52.83/58.83；binder 14.15/8.677；min ipAE 4.63/4.859 |

### 4.3 pass 与 FoldSeek 聚类

| 任务 | 普通 pass（S/C） | 聚类后 pass（S/C） | 簇数（S/C） | developability pass（S/C） |
| --- | --- | --- | --- | --- |
| monomer-short | 0.750 / 1.000 | 0.375 / 0.625 | 5 / 5 | 0.000 / 0.000 |
| monomer-medium | 0.833 / 1.000 | 0.833 / 1.000 | 6 / 6 | 0.167 / 0.333 |
| monomer-long | 0.500 / 0.750 | 0.500 / 0.750 | 4 / 4 | 0.000 / 0.000 |
| motif-1BCF | 0.625 / 0.625 | 0.125 / 0.125 | 1 / 1 | 0.125 / 0.000 |
| ppi-pdl1 | 0.333 / 0.333 | 0.333 / 0.333 | 5 / 4 | 0.167 / 0.167 |

> pass 粒度是 1/6–1/8，0.25 的差只相当于 1–2 个设计，不具统计显著性。

### 4.4 E1：两边不是同一批设计

| 任务 | pairs | median identity | ≥0.95 | median design RMSD (Å) |
| --- | ---: | ---: | ---: | ---: |
| monomer-short | 8 | 0.682 | 37.5% | 1.160 |
| monomer-medium | 6 | 0.644 | 16.7% | 1.880 |
| monomer-long | 4 | 0.381 | 0% | 5.400 |
| motif-1BCF | 8 | 0.794 | 0% | 0.363 |
| ppi-pdl1 | 6 | 0.297 | 16.7% | 7.183 |

对照基线（对齐 vs 未对齐的 SDAA 自比，代表“完全不同设计”）：identity 0.31/0.31/0.27/0.80/0.31，
design RMSD 13.2/15.8/24.4/0.23/9.7 Å。

### 4.5 E2：oracle 噪声很小

| 任务 | pLDDT σ | backbone RMSD σ (Å) | 其他 |
| --- | ---: | ---: | --- |
| monomer-short | 0.11 | 0.14 | pTM σ=0 |
| monomer-medium | 0.66 | 0.40 | |
| monomer-long | 0.53 | 0.30 | |
| motif-1BCF | 0.44 | 0.68 | motif CA σ 1.29 |
| ppi-pdl1 | 0.34 | 0.04 | ipTM σ 1.61 |

### 4.6 E3：差异远超噪声，且与设计差异相关

| 任务 | 指标 | median abs(Δ) | 2σ | 落在 2σ 内 | ρ(identity, abs(Δ)) |
| --- | --- | ---: | ---: | ---: | ---: |
| monomer-short | pLDDT | 1.73 | 0.32 | 12.5% | −0.86 |
| monomer-short | backbone RMSD | 0.08 | 0.38 | 62.5% | −0.29 |
| monomer-medium | pLDDT | 0.49 | 1.86 | 66.7% | +0.09 |
| monomer-long | pLDDT | 4.48 | 1.50 | 25.0% | −0.20 |
| motif-1BCF | pLDDT | 22.17 | 1.24 | 12.5% | −0.07 |
| ppi-pdl1 | pLDDT | 3.22 | 0.97 | 0% | −0.60 |
| ppi-pdl1 | ipTM | 10.00 | 4.55 | 33.3% | −0.83 |

逐设计例子：short 中 identity ≥0.8 的 4 对 |ΔpLDDT| ≤1.53，identity 0.40–0.56 的 rep6/rep7 差 22 分；
motif backbone 只差 0.13–2.0 Å，pLDDT 却可双向差 35–40 分（双稳）。

### 4.7 D1：第一次 trunk 调用就已经不同

| 张量（第一次 trunk 输出） | 相对差 | max abs | mean abs |
| --- | ---: | ---: | ---: |
| `insertion.logits` | 1.15e-2 | 3.75e-1 | 7.34e-2 |
| `bb_ca.v` | 6.93e-3 | 3.13e-2 | 5.98e-3 |
| `local_latents.v` | 5.01e-3 | 1.95e-2 | 4.04e-3 |
| `sequence.logits` | 1.81e-3 | 2.50e-1 | 2.94e-2 |

SDAA 自身两次运行 rel=0，CUDA 自身两次运行 rel=0 → 各自确定；0.2–1.1% 的差是跨后端单步数值差。

### 4.8 D2：消融定位（CUDA，60 步；identity / design RMSD Å）

| 变体 | monomer-short | motif-1BCF | ppi-pdl1 |
| --- | --- | --- | --- |
| base | 0.682 / 1.160 | 0.794 / 0.363 | 0.297 / 7.183 |
| **einsum** | **0.890 / 0.123** | 0.781 / 0.642 | 0.312 / 6.575 |
| einsum_no_cuet | 0.890 / 0.123 | 0.781 / 0.642 | 0.312 / 6.575 |
| no_cuet | 0.682 / 1.160 | 0.794 / 0.363 | 0.297 / 7.183 |
| fp32 | 0.696 / 1.145 | 0.786 / 0.365 | 0.278 / 8.773 |
| det | 0.707 / 0.763 | 0.800 / 0.359 | 0.297 / 7.256 |

- monomer-short：强制 einsum 后 identity 0.682 → **0.890**、design RMSD 1.160 → **0.123 Å**；
  `no_cuet` 与 base 相同、`fp32` 小幅变化 → **注意力实现是主因，cuEquivariance/bf16 不是**。
- motif/PPI：强制 einsum 没有改善 → 残余差异来自其他算子/累积，未定位到单一算子。

---

### 4.9 E 探针（RNG 对齐）：闭环结果

SDAA 与 CUDA 各跑一次 `run_probe.sh`（`TORCH_SDAA_ALIGN_NV_DEVICE=a100`，20 步、1 设计）。

**实际注意力路径（插桩）**：`ATTENTION_PATH counts={'sdpa': 1, 'einsum': 584}`，
`_SDAA_SDPA_UNAVAILABLE=True`。SDAA 第一次 SDPA 内部失败后，**其余 584 次全部走显式 einsum**。

**误差随步数放大**：

| trunk 调用 | 相对差中位 | 最大 |
| --- | ---: | ---: |
| call0 | 5.97e-3 | 1.15e-2 |
| call4 | 1.09e-2 | 1.38e-2 |
| call9 | 6.01e-2 | 1.02e-1 |
| call12 | 1.37e-1 | 2.75e-1 |
| call17 | 4.03e-1 | 8.57e-1 |

单步处于 bf16 噪声底（同机 bf16 vs fp32 约 7.4e-3），第 4–6 步开始放大，第 17 步到 40%。

**第一个跨过 1e-3 的 module**：

| 顺序 | module | rel |
| ---: | --- | ---: |
| 72 | `pair_repr_builder.adaln` | 6.3e-4 |
| 84 | `transformer_layers.0.mhba.adaln` | 7.1e-4 |
| 97 | `transformer_layers.0.mhba` | 7.5e-4 |
| **106** | **`transformer_layers.0.transition.transition.swish_linear.0`** | **1.15e-3** |
| 1034 | `transformer_layers.4.transition.transition` | 1.1e-2 |
| 1122 | `transformer_layers.6.mhba` | 8.0e-3 |

**算子误差预算（bf16 vs float64）**：`attention_einsum` SDAA 1.40e-3 / CUDA 1.18e-4；
`attention_sdpa` SDAA 4.27e-7 / CUDA 7.47e-6；其余算子范数相同。

**结论**：差异从第一个 block 就以 5–8e-4 存在（bf16 量级），第一个跨过 1e-3 的是 layer-0 的
transition（FFN）；attention 在 layer-0 是 ~5.5e-4，随后被 transition 放大。因此“起源”是分布式的
bf16 数值差，**注意力物化是最大的可调杠杆**（E4：einsum 0.682→0.890 / 1.160→0.123 Å）。

**修正**：此前 CUDA 报告推断“SDAA 的 SDPA 未抛异常、走 math、标志未置位”，与插桩结果相反；
以 `counts={'sdpa': 1, 'einsum': 584}` 为准。

### 4.10 G 实验：PPI 的 A 类差异归因

| 检查 | 结果 |
| --- | --- |
| G0 指标复现 | 同一 CIF 两边重算，GRAVY/instability/H-bond/盐桥/疏水 max abs Δ = 0 |
| G1 靶点条件 | target identity 1.0、条件掩码一致、target backbone RMSD 0.07–0.08 Å |
| G2 binder 序列 | 5/6 对 identity 0.52–0.78；rep5 identity 1.0 |
| G6 统计（n=4/5） | GRAVY -0.200 vs -0.495（p=0.19）；instability 30.2 vs 52.9（p=0.11）；H-bond 5.5 vs 5.2（p=1.00）；盐桥 4.25 vs 3.80（p=0.80） |

**degenerate 设计（靶点副本）**：按 binder 与同一复合物中的靶点链比较：

| 设计 | binder 长度 | 与靶点 identity | 与靶点 CA RMSD |
| --- | ---: | ---: | ---: |
| rep0 | 51 | 0.60 | 12.9 Å |
| rep1 | 79 | 0.50 | 14.5 Å |
| rep2 | 85 | 0.56 | 15.2 Å |
| **rep3** | 108 | **0.96** | **0.97 Å** |
| rep4 | 73 | 0.46 | 15.4 Å |
| **rep5** | 109 | **1.00** | **0.19 Å** |

rep5 是靶点 5–113 的逐位复制；rep3 是带 N 端重排的近拷贝。CUDA 报告只标出了 rep5，
其 SDAA rep3 的 “best superposition 7.30 Å” 与本表不一致，需要在 CUDA 侧复核。

**按同一判定复核（SDAA rep3/rep5 退化，CUDA 仅 rep5）后的 genuine 设计（n=4 vs 5）**：

| 指标 | SDAA | CUDA | 说明 |
| --- | ---: | ---: | --- |
| GRAVY | -0.200 | -0.495 | SDAA 略更疏水（此前“更亲水”方向写反） |
| instability | 30.2 | 52.9 | SDAA 更稳定（趋势） |
| H-bond | 5.5 | 5.2 | 基本无差异 |
| 盐桥 | 4.25 | 3.80 | 基本无差异 |

**关键修正**：主表 H-bond 8.67 vs 4.67 的“大差异”完全来自退化设计（binder=靶点，H-bond 计数异常高）；
剔除后界面指标一致，GRAVY/instability 只剩采样趋势（p≈0.11–0.19）。

**完整归因实验 H（同一主机、同一代码重算）**：

| 指标 | 全体 Δ | 退化对贡献 | genuine Δ | 方向 | sign-flip p |
| --- | ---: | ---: | ---: | --- | ---: |
| GRAVY | +0.231 | -0.001 | +0.348 | +3/−1 | 0.50 |
| instability | −18.98 | +0.64 | −29.43 | +0/−4 | 0.125 |
| H-bond | +4.00 | **+4.33** | **−0.50** | +1/−3 | 1.00 |
| 盐桥 | +0.67 | +0.17 | +0.75 | +2/−2 | 0.875 |
| 疏水 | +0.33 | +1.17 | −1.25 | +1/−3 | 0.50 |

- H-bond 8.67 vs 4.67 的差距 **100% 来自退化设计**；genuine 设计无差异。
- GRAVY/instability 只剩采样趋势（p=0.50 / 0.125），n=4 不足以判显著。
- 组分差异（E −6.1%、V +4.1%、D +4.0%、I −3.8%）解释 GRAVY 偏移。

**结论**：指标、条件、退化全部受控后，PPI 的 A 类差异只剩“binder 序列不同”；
不是平台偏差。完整报告：`run_sdaa/experiments/out/H/final/REPORT.md`。

## 5. 综合结论

1. **适配正确性：成立。** 同权重（sha256 一致）、同代码（`src/configs` 0 改动）、无自定义算子；
   32/32 可 refold；几何/条件/离线指标一致；RNG 已对齐。
2. **逐设计不等价：成立。** identity 0.68/0.64/0.38/0.79/0.30；design RMSD 0.36–7.18 Å；
   只有 short/medium 进入同一邻域，long/PPI 已分叉。
3. **B 类差异不是 oracle 噪声。** oracle σ 小（pLDDT 0.11–0.66、RMSD 0.14–0.68），观测差是
   2σ 的 2–18 倍；identity 与 |Δ| 强相关（short −0.86、PPI −0.83）。
4. **差异链条（已用实验闭合）：**
   同权重/同代码/同噪声 → **第一次 trunk 调用就差 0.2–1.1%（bf16 噪声底）** →
   layer-0 attention ~5.5e-4、transition 放大到 1.1e-3 → 逐层/逐步增长（第 17 步约 40%）
   → 不同局部解 → identity 0.30–0.68 → refold 指标出现可观差异（oracle 噪声只占小部分）。
5. **数值根因：** 插桩确认 SDAA 实际走显式 einsum（1 次 SDPA 失败 + 584 次 einsum）；
   在 CUDA 上强制 einsum 是唯一显著拉近的开关（0.682→0.890 / 1.160→0.123 Å）。
   `no_cuet` 与 base 相同、`fp32` 仅小幅变化、`manual_ln` 反而更远 → 主因是“物化注意力”，
   cuEquivariance/bf16/融合 norm 不是；motif/PPI 的残余差异来自其他算子或混沌累积。
6. **设计质量与平台无关：** motif 可设计性差且坍缩（1 个结构簇）；PPI binder RMSD 8.7–14.2 Å
   （pass 线 2.5 Å）；developability pass 0–0.33，是最终交付瓶颈。
7. **PPI 的 A 类差异（G 实验）**：指标复现（Δ=0）与靶点条件（identity 1.0、0.07–0.08 Å）都已排除。
   主表的 H-bond 大差异来自 degenerate “靶点副本”（rep5 及 SDAA rep3）；剔除后界面指标一致，
   只剩 GRAVY/instability 的采样趋势（p≈0.11–0.19，不显著）。统计必须剔除退化设计。

---

## 6. 实践含义

- SDAA 可用于生成、可信任模型行为；**不能要求与 CUDA 逐设计一致**，也不应把 B 类差异解读为平台优劣。
- 跨平台比较用**分布 + 20–50 replicates + 普通/聚类后 pass**；不要按单设计配对。
- 若追求两边“更像”，可在两边强制同一注意力实现（诊断配置），但那偏离官方默认路径，不建议用于生产。
- 若目标是拿到好设计：motif 需要多样性/搜索，developability 与 PPI 界面应作为 reward 做搜索，
  而不是继续加大无条件采样。

---

## 7. 局限

- 每条件 4–8 个设计、一个 seed；pass 粒度 1/6–1/8，统计力有限。
- E2 每任务只用 2 个设计估 σ（`LIMIT=2`），σ 不确定度较大；正式结论建议 `LIMIT=8` 重跑。
- D2 只在 CUDA 侧消融，且 `einsum` 变体替换了所有 SDPA（是 SDAA 路径的超集）；严格确认需 D3（两边同时强制）。
- 早期 B 类数字混用了 inline 与 offline oracle；E3 已统一重算，结论不受影响，但旧数字不宜直接引用。
- motif 的 sequence identity 被固定 motif 抬高，判断“同设计”应看 design backbone RMSD。
- SDAA 本机无 AF3/OF3/PyRosetta/FoldSeek。

---

## 8. 产物索引

| 内容 | 路径 |
| --- | --- |
| SDAA 主结果 | `run_sdaa/results_aligned/sdaa/`（`summary.md`、`metrics.csv`、`checksums.sha256`） |
| 实验脚本与说明 | `run_sdaa/experiments/`（README 含 E1–E3、D1–D3 用法） |
| E1/E2/E3 结果 | `linshi2/2222/out/{E1,E2,E3}/`、`out/REPORT.md` |
| D1/D2 结果 | `linshi2/333333/out/{D1,D2}/` |
| G 实验（CUDA 侧） | `linshi2/99999999/{G0,G1,G2,G_ATTRIBUTION.md}` |
| 适配记录 | `SDAA/SDAA_ADAPTATION.md`（7.4/7.5 节） |

## 9. 建议的下一步

1. `D3`：两边同时强制同一注意力实现（如 `precision=32 + force_einsum + no_cuet`）再跑 E1，确认 monomer 的 identity 能否接近 1。
2. 若要继续定位 motif/PPI：在 trunk 内 hook softmax / matmul / LayerNorm 等算子，逐层比较（D1 的扩展版）。
3. 质量提升：以 refold + developability + 界面指标为 reward，在 CUDA 上做 reward-guided search。
4. 统计：每条件提升到 20–50 个设计，并报告 median/IQR 与普通/聚类后 pass。
---

## 10. 差异原因总结（一页版）

**一句话：根因是跨后端的数值实现差异，主要在注意力路径（CUDA 用 SDPA、SDAA 回退到显式 einsum），
这个微小差异在 60 步去噪中被放大，最终生成出不同的设计。** 不是权重、代码、输入、seed 或 oracle 的问题。

### 因果链

```text
同权重 / 同代码 / 同输入 / RNG 已对齐
        │
        ▼
第一次 trunk 调用就有 0.2–1.1%（bf16 噪声底，D1）
        │  单体主因：物化注意力（SDAA einsum）vs CUDA 融合 SDPA（D2/E）
        ▼
60 步去噪放大（flow matching 的混沌性）
        │
        ▼
落到不同局部解 → 序列/结构不同（identity 0.30–0.68，E1）
        │
        ▼
refold 指标随之不同（B 类差异），oracle 噪声只占很小一部分（E2/E3）
```

### 支撑证据

| 结论 | 证据 |
| --- | --- |
| 不是随机流 | 对齐后 `randn` 逐值一致（相对差 <5.2e-7） |
| 不是权重/代码 | 权重 sha256 一致；`src/configs` 在运行 commit 上 0 改动 |
| 差异从单层开始 | 同输入下第一次 trunk 输出差 0.18%–1.15%；两边各自重复运行差为 0 |
| 主因是注意力实现 | CUDA 强制 einsum 后，monomer-short identity 0.682 → 0.890、design RMSD 1.160 → 0.123 Å |
| SDAA 实际走 einsum | 插桩：`sdpa=1, einsum=584, _SDAA_SDPA_UNAVAILABLE=True` |
| cuEquivariance 不是主因 | `no_cuet` 与 base 完全相同 |
| bf16 不是主因 | `fp32` 只把 identity 从 0.682 提到 0.696 |
| 不是 oracle 噪声 | oracle σ 仅 pLDDT 0.11–0.66；观测差是 2σ 的 2–18 倍 |
| 不是指标实现 | 离线与 inline 指标逐项一致；同一 CIF 在任一平台算出的指标相同 |

### 尚未完全解释的部分

- **motif / PPI**：强制 einsum、关 cuEquivariance、fp32 都没有改善，说明残余差异来自其他算子
  （matmul 分块/归约顺序、softmax、LayerNorm）或更强的混沌累积，尚未定位到单一算子。
- monomer 强制 einsum 后仍有 0.89 vs 1.0 的差距，说明注意力只是**主因**，不是唯一来源。

### 一句话总结

**SDAA 和 CUDA 不是“算错了”，而是“同样输入下浮点算子实现不同 → 轨迹分叉 → 采样到不同设计”。**
对 monomer 已确认主要是 SDPA/einsum 的差别；motif/PPI 还叠加了其他数值实现差异。
