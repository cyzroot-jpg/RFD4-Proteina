# 实验：SDAA vs CUDA 的 B 类（refold）差异来自哪里

目录：

| 文件 | 作用 |
| --- | --- |
| `compare_designs.py` | **E1**：逐设计比较两个 CIF 集合（序列 identity、design-vs-design backbone RMSD），不需要 oracle |
| `refold_repeats.sh` | **E2**：在 CUDA 上对同一批 CIF 用多个 AF3/OF3 diffusion seed 反复 refold，测 oracle 自身方差 |
| `aggregate_repeats.py` | E2 后处理：每设计 mean/std，汇总成 `oracle_sigma.csv` |
| `analyze_experiment.py` | **E3**：把「逐设计 refold 差异」「设计 identity」「oracle 方差」合到一起，给出归因 |

背景：oracle 的 `seed` 默认是 `None`，含义是**每次 fold 各自采样扩散噪声**（见
`src/rfproteina/metrics/oracles/af3_oracle.py` 的 `seed` 说明）。而主实验里每个设计只 refold
一次，所以 SDAA 与 CUDA 的 B 类差异天然包含 **oracle 采样噪声**。这三个实验就是把它和
“设计本身不同”分开。

---

## E1：两边生成的是不是同一批设计

在同时拥有两套 CIF 的主机上运行（建议把 CUDA 结果同步回 SDAA 后在本机跑）：

```bash
# 把 CUDA 结果同步回来后（见文末），一条命令跑完 5 个任务
B_ROOT=run_sdaa/results/cuda OUT=run_sdaa/experiments/out/E1 \
  bash run_sdaa/experiments/run_e1.sh
```

单任务也可以直接调 `compare_designs.py`：

```bash
python3 run_sdaa/experiments/compare_designs.py \
  --a run_sdaa/results_aligned/sdaa/monomer-short/inference_samples \
  --b run_sdaa/results/cuda/monomer-short/inference_samples \
  --out run_sdaa/experiments/out/E1/monomer-short \
  --a-name sdaa --b-name cuda
```

判读：

- identity 中位数 ≈1、design backbone RMSD ≈0 → 两边是同一批设计；
- identity 低（如 0.3）或 RMSD 达到 Å 级 → 数值路径把轨迹分开了，设计确实不同。

参考基线（本机已跑：**对齐 vs 未对齐**的 SDAA 自比，用来标定“不同样本”的量级）：

| 任务 | pairs | median identity | median design RMSD (Å) |
| --- | ---: | ---: | ---: |
| monomer-short | 8 | 0.307 | 13.23 |
| monomer-medium | 6 | 0.312 | 15.76 |
| monomer-long | 4 | 0.270 | 24.43 |
| motif-1BCF | 8 | **0.802** | **0.226** |
| ppi-pdl1 | 6 | 0.310 | 9.69 |

含义：不同噪声下，monomer 的 identity ~0.3、结构差 >10 Å；motif 因为 motif 固定，
序列 identity 仍有 0.80 但结构只差 0.23 Å。**如果 SDAA 对齐 vs CUDA 的结果落在 0.3 附近，
就说明设计确实不同；如果 identity ≈1 / RMSD ≈0，则 B 类差异只能来自 oracle 噪声。**

## E2：oracle 自身的方差有多大（CUDA）

在 CUDA 主机上运行（需要 apptainer 与 `AF3_IMAGE`/`AF3_MODEL_DIR`/`AF3_JAX_CACHE_DIR`）：

```bash
for TASK in monomer-short ppi-pdl1; do
  INPUTS=/path/to/inputs/$TASK \
  TAGS='[design,developability,unconditional_refolding]' \
  OUT=run_sdaa/experiments/out/E2/$TASK ORACLE=of3 SEEDS="0 1 2" LIMIT=2 \
    bash run_sdaa/experiments/refold_repeats.sh
done
```

- `INPUTS` 指向任一含 `*_generated.cif` 的目录（建议用 SDAA 的设计，作为同一设计对照）。
- 每个 seed 跑一次 `rfd4-evaluate`，输出 `seed0/`、`seed1/`、`seed2/`。
- 结束后自动生成 `<OUT>/oracle_sigma.csv`：每个指标在重复 refold 下的 `median_std`。

若三个 seed 的结果完全一致（std=0），说明该 oracle 在该配置下是确定的，B 类差异只能来自设计。

## E3：归因

需要三样东西：E1 的 `pairs.csv`、两边主 refold 的 `per_example_metrics.csv`、E2 的 `oracle_sigma.csv`。

```bash
python3 run_sdaa/experiments/analyze_experiment.py \
  --out run_sdaa/experiments/out/E3 \
  --pairs run_sdaa/experiments/out/E1/monomer-short/pairs.csv \
  --refold-a /path/to/sdaa_eval/evaluation_metrics/per_example_metrics.csv \
  --refold-b /path/to/cuda_eval/evaluation_metrics/per_example_metrics.csv \
  --sigma run_sdaa/experiments/out/E2/monomer-short/oracle_sigma.csv \
  --a-name sdaa --b-name cuda
```

输出 `attribution.md`，每个指标给出：

| 列 | 含义 |
| --- | --- |
| `median abs(Δ)` / `max abs(Δ)` | 逐设计 SDAA−CUDA 的 refold 指标差 |
| `2σ_oracle` | `2·√2·median_std`，即“同一设计两次独立 refold”的 2σ 预期 |
| `noise-consistent` | `abs(Δ) ≤ 2σ_oracle` 的设计比例 |
| `ρ(identity, abs(Δ))` | 设计 identity 与指标差的相关性（越负越说明差异来自设计不同） |

判读：

1. **noise-consistent ≈100% 且 identity ≈1** → B 类差异基本是 oracle 采样噪声；
2. **noise-consistent 低且 identity 低** → 两边生成的就是不同设计（数值路径导致）；
3. **identity ≈1 但 |Δ| 远超 2σ** → 需要检查 refold 配置/种子是否真的相同；
4. **PPI/motif 这类任务**建议单独看：它们对界面/局部位移更敏感。

## 各任务的 refolding tags

```text
monomer-*   [design,developability,unconditional_refolding]
motif-1BCF  [design,developability,3d_coordinate_conditioning,motif_scaffold_refolding]
ppi-pdl1    [design,developability,interchain_interactions,ppi_refolding]
```

## 预计结果与后续

- 若 E2 的 σ 较大（pLDDT 1–3、backbone RMSD 0.5–2 Å），那么 short/medium 的 B 类差距大部分可由
  oracle 噪声解释；此时应把“单次 refold 的均值”换成“多次 refold 的均值±std”再比较。
- 若 E2 的 σ 很小而 E1 的 identity 很低，则应当承认：相同 seed/噪声下，SDAA 的数值路径仍会
  把部分设计送到不同的局部解。这不是适配错误，但会限制“逐设计等价”的结论。
- 想进一步缩小差异，可尝试在 SDAA 上固定 `torch_deterministic=true` 或改用 CPU 生成噪声，
  但要清楚这已经偏离了官方默认推理路径。
---

## 数据同步

```bash
# CUDA -> SDAA（设计 CIF + 主 refold 的 per-example CSV）
rsync -av <cuda-host>:/path/to/RFD4-Proteina/run_sdaa/results/cuda/ \
  /data01/tuyilist/cyz/RFD4-Proteina/run_sdaa/results/cuda/

# SDAA -> CUDA（给 E2 用；SDAA 对齐后的设计）
rsync -av /data01/tuyilist/cyz/RFD4-Proteina/run_sdaa/results_aligned/sdaa/ \
  <cuda-host>:/path/to/RFD4-Proteina/run_sdaa/results/sdaa_from_sdaa/
```


---

## 已验证的运行记录

本套实验已在 CUDA 主机上完整跑过一轮（A100 + OF3，两边设计统一重算：

- 结果：`linshi2/2222/out/{E1,E2,E3}/`、`linshi2/2222/out/REPORT.md`
- 结论：B 类差异主要来自“同噪声下仍生成不同设计”，oracle 自身 σ 很小
- CUDA 侧为跑通做了两处必要修正，已回填到本目录脚本：
  - `++metrics.refolding_oracles.<oracle>.seed=<n>`（Hydra struct 模式下需要 `++`）
  - 用 `HERE=$(dirname ${BASH_SOURCE[0]})` 定位同目录脚本，避免依赖仓库内相对路径

---

# 实验 D：定位是哪一段数值路径导致分叉

E1–E3 已经确定“差异来自设计不同”。D 组实验进一步回答“设计为什么不同”，即具体是哪个数值
实现造成的。分三步，从最直接到最便宜。

## D1 单步 fidelity：同输入、同噪声，比第一次 trunk 输出

`fidelity_probe.py` 在第一次调用 trunk 时，把**输入张量与输出张量**保存成 `call0.pt`。
两边用完全相同的命令（同 seed、同输入），第一个 trunk 调用拿到的 `x_t` 也相同，因此张量差
只反映这一层的数值实现。

```bash
# SDAA（和 CUDA 各跑一次，命令完全相同；nsteps=20 只是省钱）
FIDELITY_OUT=<out>/fid_sdaa \
SDAA_VISIBLE_DEVICES=0 TORCH_SDAA_ALIGN_NV_DEVICE=a100 \
python3 run_sdaa/experiments/fidelity_probe.py \
  inference_experiment=quickstart compile_lengths=null seed=1234 batch_size=1 job_id=0 \
  hf_ckpt_path=nvidia/RFD4-Proteina \
  inputs=data/benchmarks/monomer/monomer-short.cif.zst num_replicates=1 \
  generation.n_recycle_schedule='[[20,2]]' generation.args.nsteps=20 \
  out_dir=<out>/run_sdaa_probe

# CUDA：同一条命令，去掉 SDAA 变量，加 CUDA_VISIBLE_DEVICES=0

# 比较
python3 run_sdaa/experiments/compare_fidelity.py <out>/fid_sdaa <out>/fid_cuda
```

判读：

- 第一次 trunk 输出的 `rel` 已经 >1e-3 → **单层数值实现差异**（可继续用 D2 定位到具体算子）；
- 第一次 trunk 输出 `rel` ≈0 → 单层一致，差异来自 60 步累积/混沌放大（bf16、舍入）。

本机自检：两次完全相同的 SDAA 运行，`call0.pt` 的 4 个输出张量 `rel` 全为 **0.0**，
说明探针本身是确定性的、足够敏感。

> 为什么不用内置的 `save_trajectory_every`：在 monomer 上它会触发
> `structure_export.py` 的一个 bug（`has_idx_all_token_level` 为 None），所以这里用 trunk hook。

## D2 消融矩阵：一次只改一条数值路径

`run_ablation.sh` 在 CUDA 上跑 6 个变体，每个变体后用 `compare_designs.py` 与参考设计集比较：

| 变体 | 改了什么 | 模拟的 SDAA 差异 |
| --- | --- | --- |
| `base` | 不动 | 基线（应等于 CUDA 原结果） |
| `einsum` | SDPA 换成显式 einsum | SDAA 的 pair-bias 注意力路径 |
| `no_cuet` | 关掉 cuequivariance（attention + tri-mult） | SDAA 无 cuEquivariance |
| `einsum_no_cuet` | 两者都关 | 更接近 SDAA |
| `fp32` | `precision=32` | 测试 bf16 的影响 |
| `det` | `torch_deterministic=true` | 非确定性 kernel 的影响 |

```bash
# CUDA 上（8 个设计，每个变体约 1 分钟）
TASK=monomer-short \
REF=run_sdaa/results_aligned/sdaa/monomer-short/inference_samples \
OUT=run_sdaa/experiments/out/D2 \
  bash run_sdaa/experiments/run_ablation.sh
```

判读：哪个变体让 identity 从 base 的 0.68 明显升向 1，哪条路径就是主因。

要测 bf16 / 强制 einsum 的双边影响，用同样脚本在 SDAA 上跑（`PLATFORM=sdaa REPS=2`），
再与 CUDA 的对应变体比较；两边设置相同时 identity 应显著高于 base。

## D3 组合验证

找到候选后，在**两边**都用同一组强制设置（例如 `precision=32` + `force_einsum` + `no_cuet`）
跑 E1。若 identity 升到 ≈1，则候选被确认；若仍低，说明差异在更底层的 matmul/softmax/归约顺序，
只能靠 D1 的张量级比较继续定位。

## 成本

| 实验 | 成本 |
| --- | --- |
| D1 单步 fidelity（20 steps × 1 设计） | 每边约 3 分钟 |
| D2 消融（CUDA，8 设计 × 6 变体） | 约 10 分钟 + 6 次 compare |
| D3 双边组合（每边 2 设计） | SDAA 约 15–20 分钟，CUDA 约 1 分钟 |

---

## 已验证结果（D1 / D2，CUDA 主机）

D1（第一次 trunk 调用，nsteps=20，1 设计）：SDAA 与 CUDA 的 `sequence.logits` / `local_latents.v` /
`bb_ca.v` / `insertion.logits` 相对差分别为 1.81e-3 / 5.01e-3 / 6.93e-3 / 1.15e-2；
两边各自重复运行 rel=0，说明差异来自跨后端单步数值，不是采样。

D2（CUDA 消融，60 步；identity / design RMSD Å）：

| 变体 | monomer-short | motif-1BCF | ppi-pdl1 |
| --- | --- | --- | --- |
| base | 0.682 / 1.160 | 0.794 / 0.363 | 0.297 / 7.183 |
| einsum | **0.890 / 0.123** | 0.781 / 0.642 | 0.312 / 6.575 |
| einsum_no_cuet | 0.890 / 0.123 | 0.781 / 0.642 | 0.312 / 6.575 |
| no_cuet | 0.682 / 1.160 | 0.794 / 0.363 | 0.297 / 7.183 |
| fp32 | 0.696 / 1.145 | 0.786 / 0.365 | 0.278 / 8.773 |
| det | 0.707 / 0.763 | 0.800 / 0.359 | 0.297 / 7.256 |

结论：monomer 的主因是注意力实现（SDPA vs einsum）；cuEquivariance 与 bf16 不是主因；
motif/PPI 不随这些开关变化，残余差异在其他算子/累积，需要 D3 或更细粒度张量比较。

---

# 实验 E：完整根因定位（分层）

目标：不是只证明“数值路径”，而是按 **时间 → 深度 → 算子 → 因果 → 残余** 的顺序，把每一处差异
定位到具体 module / op，并确认它确实造成设计分叉。

## E0 不变量（先排除“配置不同”）

```bash
# 两边应一致：权重 sha256、commit、src/configs 是否 dirty、RNG 探针
sha256sum "$CKPT/model.safetensors"
git rev-parse HEAD && git status --porcelain src configs
# RNG：SDAA 带 TORCH_SDAA_ALIGN_NV_DEVICE=a100，两边 randn(5) 应逐值一致
```

## E1 时间：误差从第几步开始放大

`run_probe.sh` 会记录前 N 次 trunk 调用（默认 N=nsteps=20）：

```bash
# SDAA 与 CUDA 各跑一次（命令相同）
OUT=<out>/sdaa  bash run_sdaa/experiments/run_probe.sh
OUT=<out>/cuda  bash run_sdaa/experiments/run_probe.sh
# 在任一侧比较（需要两个目录）
python run_sdaa/experiments/compare_fidelity.py <out>/sdaa/fidelity <out>/cuda/fidelity
```

判读：每个 `callK.pt` 是一步 trunk 的输入/输出。若 `rel` 从第 1 步起就稳定在 1e-3 量级并缓慢增长，
是“每步都有小误差 + 线性/指数放大”；若第 1 步为 0、之后才起来，则是纯累积。

## E2 深度：第一个出现差异的 module

`run_probe.sh` 同时生成 `layers/layers.csv`（第一次 trunk 调用的 1517 个 module 输出统计）。

```bash
python run_sdaa/experiments/compare_layers.py <out>/sdaa/layers <out>/cuda/layers --threshold 1e-3
```

输出会给出**按执行顺序第一个 rel > threshold 的 module**（例如 `transformer_layers.*.mhba.mha.pair_norm`
或 `...to_qkv`）。这就是“差异的起点”。想对该 module 做逐元素比较，可再跑一次并设置
`LAYER_PROBE_FULL='<module regex>'`，全张量会按 `full_index.csv` 保存。

## E3 算子误差预算：把 module 对应到 op

`run_probe.sh` 同时生成 `ops_<platform>.json`（16 个微算子，含 float64 CPU 参考）：

```bash
python run_sdaa/experiments/op_bench.py --compare <out>/sdaa/ops_sdaa.json <out>/cuda/ops_cuda.json
```

列：`rel(a,b)` 是两平台同一算子的相对差；`a/b vs cpu64` 是各自相对 float64 的误差。
把 E2 的第一个 divergent module 与这里的算子对应，即可判断是 attention、matmul、norm 还是 softmax。

已验证的一条线索（SDAA 实测）：

| op | rel to float64 |
| --- | ---: |
| `attention_einsum.bfloat16` | **1.4e-3** |
| `attention_sdpa.bfloat16` | 4.3e-7 |
| `matmul.bfloat16` | 6.0e-6 |
| `rmsnorm.bfloat16` | 1.7e-4 |
| `layernorm.bfloat16` | 1.3e-4 |

即“显式 einsum 注意力在 bf16 下误差比融合 SDPA 大三个数量级”，与 D2 中“CUDA 强制 einsum
后 identity 0.68→0.89”互相印证。

## E4 因果：消融矩阵

```bash
TASK=monomer-short REF=<sdaa>/monomer-short/inference_samples OUT=<out>/abl \
  bash run_sdaa/experiments/run_ablation.sh
```

变体（默认全跑）：`base`、`einsum`、`no_cuet`、`einsum_no_cuet`、`manual_ln`、`manual_ln_einsum`、`fp32`、`det`。
每个变体都会与参考设计比较 identity / design RMSD。哪个变体让 identity 明显升向 1，哪条路径就是
因果；对 `manual_ln`，脚本会把 `F.layer_norm` / `F.rms_norm` 换成手写非融合实现。

## E5 双边确认

候选找到后，在**两边**用同一强制设置各跑一次（例如 `precision=32 + einsum + manual_ln`），
再用 `compare_designs.py` 比较两边输出：

- identity ≈1 → 候选项就是全部主因；
- 仍低 → 还有第二个来源，回到 E2/E3 继续找。

## E6 残余与统计

- 对“两边强制同一路径后仍存在的差异”，重复 E1/E2，看第一个 divergent module 是否后移；
- 每条件用 8–20 个设计、2–3 个 seed 重复，报告分布与 pass/聚类，而不是单设计。

## 决策树

```text
第一次 trunk 调用 rel > 1e-3 ?
├─ 是 → E2 找首个 divergent module → E3 对应 op → E4 消融 → E5 双边确认
└─ 否 → E1 看误差随步数增长 → 若 fp32/det 明显改善 → 累积/精度问题
                                    否则 → matmul/归约顺序等底层差异
```

## 一键探针

`run_probe.sh` 把 E1+E2+E3 打包成一条命令（约 6–8 分钟/边，20 步、1 设计）：

```bash
OUT=<out>/sdaa DEVICE=0 bash run_sdaa/experiments/run_probe.sh     # SDAA
OUT=<out>/cuda DEVICE=0 bash run_sdaa/experiments/run_probe.sh     # CUDA
```

自检：同一目录自比，`compare_fidelity`、`compare_layers`、`op_bench --compare` 都应全为 0
（已验证；说明探针确定、可比较）。

## 成本

| 步骤 | 成本 |
| --- | --- |
| E0 | <1 分钟 |
| E1+E2+E3（`run_probe.sh`，20 步 × 1 设计） | 每边 6–8 分钟 |
| E4（8 变体 × 8 设计 × 60 步，CUDA） | 约 15–20 分钟 |
| E5（两边各 2 设计） | SDAA 约 15 分钟，CUDA 约 1 分钟 |


---

## 已验证结果（E 探针，RNG 对齐）

在 SDAA（`TORCH_SDAA_ALIGN_NV_DEVICE=a100`）与 CUDA 上各跑一次 `run_probe.sh`：

**实际注意力路径（插桩 `attn_path_probe.py`）**

```text
ATTENTION_PATH counts={'sdpa': 1, 'einsum': 584} _SDAA_SDPA_UNAVAILABLE=True
```

即 SDAA 第一次 SDPA 调用内部失败（日志里的警告是失败前打印的），随后 584 次全部使用显式 einsum。

**误差随步数放大**：call0 中位 5.97e-3（bf16 噪声底）→ call4 1.09e-2 → call9 6.01e-2 →
call12 1.37e-1 → call17 4.03e-1。

**第一个跨过 1e-3 的 module**：`transformer_layers.0.transition.transition.swish_linear.0`
（1.15e-3）；layer-0 attention 本身约 5.5e-4，属于 bf16 量级，随后被 transition 放大；
深层 layer4 transition 1.1e-2、layer6 mhba 8.0e-3。

**算子预算（bf16 vs float64）**：`attention_einsum` SDAA 1.40e-3 / CUDA 1.18e-4；
`attention_sdpa` SDAA 4.27e-7 / CUDA 7.47e-6；其余算子范数相同。

注意：`run_probe.sh` 现在会在 SDAA 未设置 `TORCH_SDAA_ALIGN_NV_DEVICE` 时告警；
**未对齐的 probe 与 CUDA 不可比**（此前一次 `out/E/sdaa_probe` 就是未对齐，已废弃）。

---

# 实验 F：motif / PPI 专项（定位剩余差异）

## 为什么单独设计

- **motif**：结构只差 0.36 Å、motif 条件依从一致，但 refold pLDDT 双向差 35–40 分（双稳）；
  常规消融（einsum / no_cuet / fp32 / manual_ln）都不改善。
- **PPI**：identity 0.30、A 类已分叉（GRAVY/instability/H-bond），消融也几乎不改善。
- 两者可能不是同一个原因，所以分别定位，不合并。

## F1 逐层 + 算子（两边 probe，20 步）

```bash
# motif：SDAA 与 CUDA 各一次（CUDA 去掉 SDAA 变量）
OUT=<out>/F/motif/sdaa TASK=motif-1BCF NSTEPS=20 \
  TORCH_SDAA_ALIGN_NV_DEVICE=a100 on  # SDAA 侧
OUT=<out>/F/motif/cuda TASK=motif-1BCF NSTEPS=20 bash run_sdaa/experiments/run_probe.sh

# PPI 同样跑一份
OUT=<out>/F/ppi/sdaa TASK=ppi-pdl1 NSTEPS=20 ...
OUT=<out>/F/ppi/cuda TASK=ppi-pdl1 NSTEPS=20 ...
```

比较：

```bash
python run_sdaa/experiments/compare_fidelity.py <sdaa>/fidelity <cuda>/fidelity
python run_sdaa/experiments/compare_layers.py   <sdaa>/layers   <cuda>/layers --threshold 1e-3
python run_sdaa/experiments/op_bench.py --compare <sdaa>/ops_sdaa.json <cuda>/ops_cuda.json
```

判读：第一个 rel>1e-3 的 module + 对应 op，就是 motif/PPI 的起点。

## F2 序列差异落在哪里（motif vs scaffold / binder）

```bash
python run_sdaa/experiments/analyze_sequence_divergence.py \
  --a <sdaa designs> --b <cuda designs> --out <out>/F/seq/motif \
  --motif-input data/benchmarks/motif_scaffolding/motif_indexed/1BCF_AA.cif.zst
```

输出每个设计的 identity、mismatch 数，以及 **motif / scaffold 分开的 mismatch 数**；
再加 `--refold-a/--refold-b` 可把 refold 指标并进来做相关。

已验证（SDAA 对齐 vs 未对齐，motif）：15–31 个 mismatch **全部在 scaffold，motif 区 0 个**。
所以 motif 的 refold 差异应由 scaffold 序列/构象变化引起，而不是 motif 残基改变。

## F3 哪一步开始分叉（序列决策点）

```bash
python run_sdaa/experiments/analyze_step_divergence.py <sdaa>/fidelity <cuda>/fidelity
```

输出每一步的 `seq_agreement`（sequence logits argmax 一致率）、速度张量的 rel/cos。
已验证（monomer，20 步）：seq agreement 在 step 12–14 从 0.93 掉到 0.78，速度 rel 从 0.13
升到 0.63；step 17 速度 rel 0.88。即**结构/序列在 12–14 步左右分叉**。

## F4 组合消融（motif/PPI）

`run_ablation.sh` 新增了三个变体：`tri_torch`（只关 cuequivariance 三角乘）、`all_manual`
（einsum + 手写 norm + torch 三角乘 + no_cuet）、`all_manual_fp32`（再加 fp32）。

```bash
TASK=motif-1BCF REF=<sdaa motif designs> OUT=<out>/F/abl/motif \
  VARIANTS="base einsum tri_torch manual_ln all_manual all_manual_fp32 fp32 det" \
  bash run_sdaa/experiments/run_ablation.sh
```

若 `all_manual_fp32` 把 identity 明显拉高 → 剩余差异是“多个算子 + bf16”的叠加；
若仍不变 → 归因于 matmul/归约顺序或混沌累积。

## F5 分叉步的逐层定位

`layer_probe.py` 新增 `LAYER_PROBE_AT_CALL`：可以只记录第 k 次 trunk 调用的 module 统计。

```bash
LAYER_PROBE_OUT=<out>/F/layers_at12 LAYER_PROBE_AT_CALL=12 \
  python run_sdaa/experiments/layer_probe.py ...（同 probe 参数，NSTEPS=20）
```

然后比较两边的 `layers_at12`，看 step 12 时第一个 divergent module 是否与 F1 一致。

## 决策树

```text
motif/PPI: F1 第一个 divergent module
├─ 是 attention/norm/tri-mult → F4 对应组合消融
├─ 是 matmul/归约 → F5 + op_bench 确认；通常无法完全消除
└─ 序列差异只在 scaffold（F2）→ 结合 F3 的分叉步，检查该步的 module
```

---

# 实验 G：PPI 的 A 类差异归因

现象：monomer/motif 的 A 类指标基本一致，但 PPI 不一致（GRAVY -0.220 vs -0.451、
instability 31.2 vs 50.2、H-bond 8.67 vs 4.67），identity 只有 0.30。
目标：区分“目标条件不同 / 指标实现不同 / binder 设计不同 / 统计噪声”。

## G0 指标实现复核（先排除）

取一个 **CUDA 生成的 PPI CIF**，在 SDAA 上用相同 tags 离线重算，和 CUDA 的数值对照：

```bash
python -m rfproteina.evaluate inputs=<one-cif-dir> \
  'metrics_tags=[design,developability,interchain_interactions]' \
  metrics/inline_metrics=all_inline_metrics_no_rosetta job_id=0 \
  out_dir=<out>/G0
```

同一 CIF 两边数值一致 → 指标/COI 选择没有问题，差异来自设计。

## G1 目标条件是否相同

```bash
python run_sdaa/experiments/analyze_ppi_conditioning.py \
  --a <sdaa ppi designs> --b <cuda ppi designs> --out <out>/G1
```

它比较：target 链的 backbone 坐标（N/CA/C/O）、target 序列、以及**只限 target 原子**的
`condition_*` 掩码。

已验证（SDAA 对齐 vs 未对齐，作为基线）：target identity 1.0、靶点条件掩码完全一致、
target backbone RMSD 0.075–0.087 Å（bf16 输出级），binder 本身不同。
→ 如果 SDAA vs CUDA 也是这个结果，就排除“目标表示不同”。

## G2 binder 序列差异落点

```bash
python run_sdaa/experiments/analyze_sequence_divergence.py \
  --a <sdaa ppi designs> --b <cuda ppi designs> --out <out>/G2
```

输出每个设计的 mismatches 位置。可进一步把 mismatch 与界面残基（H-bond/盐桥涉及的残基）
求交集，判断差异是“界面局部”还是“整条 binder”。

## G3 哪一步开始分叉

```bash
# 先对 PPI 跑两次 probe（SDAA/CUDA，对齐）
OUT=<out>/G3/sdaa TASK=ppi-pdl1 NSTEPS=20 TORCH_SDAA_ALIGN_NV_DEVICE=a100 bash run_sdaa/experiments/run_probe.sh
OUT=<out>/G3/cuda TASK=ppi-pdl1 NSTEPS=20 bash run_sdaa/experiments/run_probe.sh

python run_sdaa/experiments/analyze_step_divergence.py <out>/G3/sdaa/fidelity <out>/G3/cuda/fidelity
```

看 `seq_agreement` 从哪一步开始下降（binder 序列的决策点）。

## G4 逐层 / 算子

```bash
python run_sdaa/experiments/compare_layers.py <out>/G3/sdaa/layers <out>/G3/cuda/layers --threshold 1e-3
python run_sdaa/experiments/op_bench.py --compare <out>/G3/sdaa/ops_sdaa.json <out>/G3/cuda/ops_cuda.json
```

PPI 比 monomer 多出：target 坐标条件注入、pair 表示、界面 attention；第一个 divergent module
会指向其中一类。若在分叉步（G3）才明显，可用 `LAYER_PROBE_AT_CALL=<step>` 再定位。

## G5 组合消融

```bash
TASK=ppi-pdl1 REF=<sdaa ppi designs> OUT=<out>/G5 \
  VARIANTS="base einsum tri_torch manual_ln all_manual all_manual_fp32 fp32 det" \
  bash run_sdaa/experiments/run_ablation.sh
```

若没有任何变体改善 → 差异是“多算子 + 混沌累积”，而不是单一模块。

## G6 统计：是系统偏移还是抽样波动

当前每边只有 6 个 PPI 设计。要区分“SDAA 系统性更疏水/更不稳定”与“只是抽到不同样本”，
需要每边 10–20 个设计（PPI 在 SDAA 约 31 min/设计，可多卡并行），然后：

```python
# 比较 A 类指标分布（GRAVY、instability、H-bond 等）
from scipy.stats import mannwhitneyu
# u, p = mannwhitneyu(sdaa_values, cuda_values, alternative="two-sided")
```

- p 不显著 + 分布重叠 → 抽样差异；
- p 显著且方向一致 → 系统性偏移，回到 G1/G4 找条件或算子原因。

## 决策树

```text
G0 同一 CIF 指标不同? ──是──> 指标/COI 实现问题（罕见）
        │否
G1 target 条件不同? ──是──> 条件注入/坐标精度问题
        │否
G2/G3 binder 分叉 → G4 第一个 divergent module → G5 消融
        │
G6 扩大样本：分布重叠 = 抽样；显著偏移 = 系统性
```

---

## 已验证结果（G 实验，PPI A 类归因）

- **G0 指标复现**：同一 CIF 两边重算，GRAVY / instability / H-bond / 盐桥 / 疏水
  `max abs Δ = 0` → 指标实现无平台差异。
- **G1 靶点条件**：target identity **1.0**、只限 target 的 `condition_*` 掩码一致、
  target backbone RMSD **0.07–0.08 Å** → 条件注入一致。
- **G2 binder 序列**：5/6 对 identity 0.52–0.78；rep5 identity 1.0。
- **G6 统计（n=4/5）**：GRAVY -0.200 vs -0.495（p=0.19）；instability 30.2 vs 52.9（p=0.11）；
  H-bond 5.5 vs 5.2（p=1.00）；盐桥 4.25 vs 3.80（p=0.80）→ 只有趋势，不显著。

**degenerate 设计（靶点副本）**：

| 设计 | binder 长度 | 与靶点 identity | 与靶点 CA RMSD |
| --- | ---: | ---: | ---: |
| rep0 | 51 | 0.60 | 12.9 Å |
| rep1 | 79 | 0.50 | 14.5 Å |
| rep2 | 85 | 0.56 | 15.2 Å |
| **rep3** | 108 | **0.96** | **0.97 Å** |
| rep4 | 73 | 0.46 | 15.4 Å |
| **rep5** | 109 | **1.00** | **0.19 Å** |

rep5 = 靶点 5–113 的复制；rep3 = 带 N 端重排的近拷贝。CUDA 报告只标出了 rep5，
其 SDAA rep3 的 “best superposition 7.30 Å” 与本表不一致，需要在 CUDA 侧复核。
**做 PPI 统计时必须剔除 degenerate 设计，并单独报告“靶点复制率”。**


### 逐设计复核（`analyze_ppi_aclass.py`）

用同一份代码（都在 CUDA 上重算）对比 6 对设计：

| rep | 长度 S/C | 退化 S/C | GRAVY Δ | instability Δ | H-bond Δ |
| --- | --- | --- | ---: | ---: | ---: |
| rep0 | 51 / 51 | N / N | -0.394 | -17.6 | -3 |
| rep1 | 79 / 79 | N / N | +0.237 | -32.2 | -3 |
| rep2 | 85 / 85 | N / N | +0.380 | -4.6 | -3 |
| rep3 | 108 / 108 | **Y / N** | +0.019 | +3.8 | +11 |
| rep4 | 73 / 73 | N / N | +1.171 | -63.4 | +7 |
| rep5 | 109 / 109 | **Y / Y** | -0.026 | +0.0 | +15 |

剔除退化（SDAA rep3/rep5、CUDA rep5）后，genuine n=4 vs 5：

- GRAVY -0.200 vs -0.495（SDAA 略更疏水；此前“更亲水”方向写反）
- instability 30.2 vs 52.9（SDAA 更稳定，趋势）
- H-bond 5.5 vs 5.2、盐桥 4.25 vs 3.80（基本无差异）

**关键结论**：主表 H-bond 8.67 vs 4.67 的差异**完全来自退化设计**；剔除后界面指标一致。
GRAVY/instability 只剩采样趋势（方向 4/6，leave-one-out 波动大，p≈0.11–0.19）。


### 完整归因实验 H（已端到端跑完）

脚本：`run_ppi_aclass_experiment.py`；报告：`out/H/final/REPORT.md`。

- H0：官方 GRAVY/instability 与 Biopython 序列推导值最大差 4e-5 → 指标实现无问题；
- H1/H2：SDAA rep3/rep5 退化，CUDA 仅 rep5；逐设计 Δ 见表；
- H3/H4：genuine（n=4）统计：
  - H-bond 全体 Δ=+4.00，退化对贡献 +4.33，genuine Δ=−0.50（p=1.00）→ 大差异是退化伪影；
  - GRAVY genuine Δ=+0.348（+3/−1，p=0.50，CI [−0.20,+0.94]）→ 略更疏水，不显著；
  - instability genuine Δ=−29.4（4/4，p=0.125 = n=4 最小可能值）→ 趋势；
  - 盐桥/疏水：genuine 无差异；
- H5：genuine 组分差异 E −6.1%、V +4.1%、D +4.0%、I −3.8%，解释 GRAVY 偏移。

结论：PPI 的 A 类差异 = 不同 binder 序列 + 退化设计；无平台偏差证据。
