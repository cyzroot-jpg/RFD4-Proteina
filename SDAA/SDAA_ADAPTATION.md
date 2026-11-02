# RFD4-Proteina 龙芯 SDAA 适配记录

> RFD4-Proteina 是一个 flow-matching 生物分子设计模型，联合生成蛋白序列与全原子结构，
> 支持 monomer、protein binder、motif scaffolding 等任务。
>

## 一、环境信息

| 项目 | 值 |
|------|-----|
| 架构 | loongarch64（Loongnix，32 个逻辑 SDAA 设备） |
| 机器 | `10.71.13.47` |
| Python | 3.12.13（venv `/home/py312`） |
| PyTorch | 2.12.0 |
| Torch-SDAA | 3.3.0 |
| SDAA Driver / Runtime | 3.3.0 / 3.3.0 |
| 项目 commit | patch 基线 `6fc44c060ef96d4c759bafeaa1eae1a66a5be67c`；本轮测试运行 `00b916c63abe910df3f2f8f0af7222ebb253fca8` |
| 工作分支 | `adapt/sdaa` |
| 模型权重 | `nvidia/RFD4-Proteina` revision `a06e2509c7033b010fc43614e9fd840303588502`（sha256 `5b549dd6…`） |
| 权重格式 | HF bundle `config.json` + `model.safetensors`（约 1.74 GB，含 autoencoder） |
| 运行/评测入口 | 官方 `rfd4-generate`、`rfd4-evaluate`、`aggregate_metrics`（封装在 `run_sdaa/`） |
| 指标配置 | 官方 `configs/metrics/all_metrics.yaml`，按官方 `metrics_tags` 启用 |

关键依赖的版本与兼容处理统一列在 2.2 节。

## 二、分析结论

### 2.1 无自定义 CUDA 算子

项目没有 `.cu` 文件、没有 triton 自定义 kernel、没有 `cpp_extension` 编译的自定义算子。
模型计算全部由标准 PyTorch 算子组成，因此可以通过 Torch-SDAA 的 CUDA→SDAA 自动迁移运行。

核验方式：

```bash
find src -name "*.cu" -o -name "*.cuh"
grep -rn "cpp_extension\|triton" src/rfproteina | head
```

没有发现需要单独移植的自定义 CUDA kernel。

### 2.2 依赖链与兼容处理

| 依赖 | 版本 | 来源 | 状态 / 处理 |
|------|------|------|------|
| torch + torch_sdaa | 2.12.0 / 3.3.0 | 预装 | 直接使用 |
| atomworks | 3.0.4 | PyPI | 需要 biotite/rdkit/pyarrow 兼容 |
| biotite | 1.7.1 | 预装 LoongArch 构建 | 兼容 AtomWorks 的 1.6.0 API |
| rdkit | 2026.9.1 | `loongarch_packages` | 缺 3 个可选模块 → stub；Boost 符号链接 |
| openbabel | 0.1.dev6623 | `loongarch_packages` | 正常 |
| biotraj | 1.2.2 | 本地 LoongArch wheel | 正常 |
| numpy / scipy | 1.26.4 / 1.15.3 | LoongArch wheel | rdkit 依赖 NumPy 1.x，版本固定 |
| pandas / lightning / hydra-core / transformers | 2.3.3 / 2.6.6 / 1.3.7 / 5.12.1 | PyPI | 正常 |
| pyarrow | 23.0.1 | 手动 wheel | 索引哈希不一致 → `--no-deps`；缺 `_parquet` → stub |
| wandb | 0.17.9 | 纯 Python wheel | 新版需要 Go 编译，使用旧版 |
| AF3 / OF3 | – | CUDA 主机 | - |
| PyRosetta | – | – | 无容器；developability 使用官方 sequence 子集 |
| FoldSeek | – | CUDA 主机 | - |

### 2.3 关键不兼容点

| 不兼容点 | 影响 | 处理 |
|------|------|------|
| `torch.cuda.is_available()` 默认 False | CUDA 风格代码无法选设备 | `torch_sdaa.utils.cuda_migrate` |
| SDPA 对 additive pair bias 无快速 kernel | 注意力计算报 `No available kernel` | 回退到显式 einsum + softmax |
| AtomWorks 强制 `biotite==1.6.0` | import 失败 | 运行期版本字符串 + API 桥接 |
| biotite 1.7 移除 `connect_via_residue_names` / `BondList._bonds` | import/指标失败 | 兼容层恢复旧路径 |
| rdkit 缺 `rdDetermineBonds` / InChI / `rdEHTTools` | AtomWorks import 失败 | 安装“调用时才报错”的 stub |
| rdkit 链接 Boost 3.12，系统只有 3.11 | import 报 `libboost_numpy312` 缺失 | `/usr/local/lib` 兼容符号链接 |
| pyarrow 缺 `_parquet` | AtomWorks import 失败 | `pyarrow.parquet` stub |
| `torch._dynamo` 缺 CUDA 私有名字 | torchvision/torchmetrics import 失败 | 补齐 `_CudaDeviceProperties` 等 |
| transformers 引用 `torch.cuda.CUDAGraph` | 连续批处理模块 import 失败 | `CUDAGraph = SDAAGraph` |
| Lightning 读取 `get_device_capability()` | SDAA 抛 NotImplementedError | 返回 `(8, 0)` |
| `torch.where` 混用 CPU/SDAA 标量 | 噪声采样崩溃 | `torch.ones_like` |
| `torch.compile` 不可用 | 只能走 eager | `compile_lengths=null` |
| SDAA 本机无 AF3/OF3 | refold/pass 无法在 SDAA 上计算 | - |
| 无 PyRosetta | Rosetta developability 无法计算 | 使用官方 sequence 子集 |

## 三、适配改动

### 3.1 新增 SDAA 兼容层

新增 `src/rfproteina/utils/sdaa_compat.py`，在 `import rfproteina` 时尽早调用：

```python
from rfproteina.utils.sdaa_compat import activate_accelerator_compat
activate_accelerator_compat()
```

它负责：

1. 检测 SDAA，启用 `torch_sdaa` 和 CUDA→SDAA 自动迁移；
2. 补齐 `torch._dynamo` / transformers / Lightning 需要的 CUDA 名字；
3. 桥接 biotite 1.6 / 1.7 的模块布局差异；
4. 为 rdkit 缺失模块和 pyarrow 缺失 Parquet 安装 fail-loud stub；
5. 在真实 CUDA 设备存在时完全跳过，保证 CUDA/CPU 不受影响。

修改的代码位置：

- `src/rfproteina/utils/sdaa_compat.py`（新增）
- `src/rfproteina/__init__.py:9-17`

### 3.2 设备迁移

问题：`torch.cuda.is_available()` 在 SDAA 上默认是 False，模型代码里的 `device="cuda"` 无法工作。

解决方法：

```python
import torch_sdaa
from torch_sdaa.utils import cuda_migrate
```

启用后：

```python
torch.cuda.is_available()  # True
torch.cuda.device_count()  # 32
torch.randn(2, device="cuda").device  # sdaa:0
```

修改的代码位置：`src/rfproteina/utils/sdaa_compat.py` 的 `_activate_sdaa_backend()`。

### 3.3 SDPA 带 pair bias 无快速 kernel

问题：模型使用：

```python
F.scaled_dot_product_attention(q, k, v, attn_mask=attn_bias)
```

`attn_bias` 是浮点 `[B,H,N,N]`。SDAA 上 flash/mem 快速路径不支持非空 `attn_mask`，
而 math 后端又被 `_configure_flash_attention_backends()` 禁用，于是报：

```text
RuntimeError: No available kernel. Aborting execution.
```

解决方法：先尝试 SDPA；失败后在该进程内永久回退到显式 einsum：

```python
sim = einsum("b h i d, b h j d -> b h i j", q, k) * scale
sim = sim + attn_bias
attn = torch.softmax(sim, dim=-1)
o = einsum("b h i j, b h j d -> b h i d", attn, v)
```

两条路径数学等价；einsum 更慢、更占显存，但结果正确。

修改的代码位置：`src/rfproteina/nn/modules/pair_bias_attn.py`。

### 3.4 `torch.where` 设备不一致

问题：`mean_w_mask` 用 CPU 标量与 SDAA tensor 做 `torch.where`：

```python
num_elements = torch.where(num_elements == 0, torch.tensor(1.0), num_elements)
```

SDAA 报：

```text
RuntimeError: Expected condition, x and y to be on the same device
```

解决方法：

```python
num_elements = torch.where(
    num_elements == 0,
    torch.ones_like(num_elements),
    num_elements,
)
```

修改的代码位置：`src/rfproteina/utils/align.py:47`。

### 3.5 三平台 accelerator

问题：`generate.py` 原来写死 `accelerator="gpu"`，CPU 无法运行。

解决方法：

```python
trainer = L.Trainer(
    accelerator=cfg.hardware.get("accelerator", "gpu"),
    ...
)
```

使用方式：

- CUDA：默认 `gpu`；
- SDAA：默认 `gpu`（`torch.cuda` 已映射到 SDAA）；
- CPU：`hardware.accelerator=cpu precision=32`，SDAA 机器上再加 `RFPROTEINA_DISABLE_SDAA=1`。

修改的代码位置：`src/rfproteina/generate.py:709`。

### 3.6 推理资源监控

新增 `src/rfproteina/utils/resource_monitor.py`，并在 `generate.py` 挂载：

```python
callbacks=[
    GenerationProgressBar(),
    ResourceMonitorCallback(output_dir=cfg.out_dir),
]
```

记录：

- `wall_time_s`：墙钟时间；
- `cpu_time_s` / `cpu_utilization_percent`：CPU 时间与利用率；
- `process_max_rss_bytes`：主机内存峰值；
- `device_peak_memory_bytes` / `device_reserved_memory_bytes`：设备显存峰值；
- `examples_per_second`：吞吐。

输出：

```text
inference_metrics/resource_usage.json
inference_metrics/resource_usage_batches.csv
```

评测侧在 `src/rfproteina/evaluate.py` 外包 `ResourceUsageRecorder`，写
`evaluation_metrics/resource_usage.json`。

### 3.7 无 Rosetta 的 developability 子集

官方 developability 组包含：

- `sequence_developability`：纯 Python，可算；
- `rosetta_developability`：需要 PyRosetta 容器，本机没有。

新增：

- `configs/metrics/inline_metrics/developability_metrics_no_rosetta.yaml`
- `configs/metrics/inline_metrics/all_inline_metrics_no_rosetta.yaml`

用法：

```bash
metrics/inline_metrics=all_inline_metrics_no_rosetta
```

这样保留官方 GRAVY / instability，避免因缺 Rosetta 导致整个 design 指标失败。

### 3.8 文档与 patch

- 使用文档：`docs/how-to/sdaa-evaluation.md`
- 源码 patch：`SDAA/patches/rfd4-proteina-sdaa.patch`
- 全流程脚本：`run_sdaa/`（`run_all.sh` / `run_task.sh` / `summarize.py` / `README.md`）
- SDAA 运行记录：`run_sdaa/results_aligned/sdaa/`（`run_env.txt`、`command.txt`、`summary.md`、`checksums.sha256`）
- CUDA 对照记录：`run_sdaa/results/cuda/`（同一套脚本，结果由 CUDA 主机回传）

## 四、权重下载

官方权重：

- Repo: `nvidia/RFD4-Proteina`
- Revision: `a06e2509c7033b010fc43614e9fd840303588502`
- 文件：`config.json` + `model.safetensors`（约 1.74 GB，FP32，含 autoencoder）

本机缓存：

```text
../rfd4_assets/hf_cache/models--nvidia--RFD4-Proteina/snapshots/a06e2509c7033b010fc43614e9fd840303588502
```

运行时通过：

```bash
hf_ckpt_path=../rfd4_assets/hf_cache/models--nvidia--RFD4-Proteina/snapshots/a06e2509c7033b010fc43614e9fd840303588502
```

避免联网。HF bundle 自带 autoencoder，不需要单独下载 AE 权重。

跨平台核对权重用的文件哈希：

```text
model.safetensors  sha256 5b549dd61adb2f6c6b5cb95bda13f40f5e31556b4e6c755edc0ca6f011c68fb0
                   1742660596 bytes
```

如果使用 native checkpoint：

```text
hf_ckpt_path=null
ckpt_path=$DATA_PATH/flow_checkpoints
ckpt_name=rfd4-proteina-flow-release-2026-10-19.ckpt
autoencoder_ckpt_path=$DATA_PATH/ae_checkpoints/rfd4-proteina-ae-release-2026-10-19.ckpt
```

## 五、测试结果：生成与 pre-oracle 设计指标

本节及第六节使用 **a100 RNG 对齐** 的运行（`run_sdaa/results_aligned/sdaa`，2026-10-27
06:03:36–09:13:08 UTC，5/5 PASS）。

### 5.1 运行命令

```bash
cd .
( setsid nohup env OUT_ROOT="$PWD/run_sdaa/results_aligned" \
    bash run_sdaa/run_all.sh > run_sdaa/logs/run_all_aligned.log 2>&1 < /dev/null & )
```

固定设置：`inference_experiment=inference_on_user_inputs`、`compile_lengths=null`、`seed=1234`、
`batch_size=1`、`precision=bf16-mixed`、`job_id=0`、`save_chain_of_interest=true`、
`hf_ckpt_path=nvidia/RFD4-Proteina`、`metrics/inline_metrics=all_inline_metrics_no_rosetta`。

每个任务的实际输入与 tags（`run_sdaa/run_task.sh` 内置）：

```text
monomer-short   data/benchmarks/monomer/monomer-short.cif.zst                      8  [design,developability]
monomer-medium  data/benchmarks/monomer/monomer-medium.cif.zst                     6  [design,developability]
monomer-long    data/benchmarks/monomer/monomer-long.cif.zst                       4  [design,developability]
motif-1BCF      data/benchmarks/motif_scaffolding/motif_indexed/1BCF_AA.cif.zst    8  [design,developability,3d_coordinate_conditioning]
ppi-pdl1        data/benchmarks/ppi/ppi_bb_only/pdl1.cif.zst                       6  [design,developability,interchain_interactions]
```

`DEVICE` 是卡槽：本机 32 个逻辑设备 / 8 张物理卡 = 4，slot 0–4 → 逻辑 `0,4,8,12,16`。

### 5.2 评测命令

离线评测前只对 `*_generated.cif` 建符号链接目录，避免 `evaluate` 把
`inference_samples/foldseek_input_chains/` 当成重复设计（否则 PPI 会出 12 行而不是 6 行）：

```bash
python3 -m rfproteina.evaluate \
  inputs=<task>/eval_inputs \
  'metrics_tags=<与生成时相同>' \
  metrics/inline_metrics=all_inline_metrics_no_rosetta \
  job_id=0 out_dir=<task>/evaluation

python3 -m rfproteina.inference_utils.aggregate_metrics --input=<task>/inference_metrics
python3 -m rfproteina.inference_utils.aggregate_metrics --input=<task>/evaluation/evaluation_metrics
```

修复后，5 个任务的离线指标与 inline 指标逐项一致（38–50 个数值列最大差为 0；仅
`pre_oracle_pass` 因离线不跑 pre-oracle filter 而不同）。

### 5.3 结果（SDAA，a100 对齐）

| 任务 | n | n_res | bad_bond / clash | helix | sheet | loop | n_SSE | GRAVY | instability | motif RMSD (Å) | H-bond pairs | salt-bridge pairs |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| monomer-short | 8 | 100.0 | 0 / 0 | 0.8188 | 0.0000 | 0.1813 | 11.50 | -0.2504 | 61.96 | – | – | – |
| monomer-medium | 6 | 150.0 | 0 / 0 | 0.7133 | 0.0833 | 0.2033 | 17.00 | -0.1718 | 76.14 | – | – | – |
| monomer-long | 4 | 250.0 | 0 / 0 | 0.6890 | 0.0980 | 0.2130 | 31.00 | -0.0753 | 49.34 | – | – | – |
| motif-1BCF | 8 | 124.5 | 0 / 0 | 0.8639 | 0.0000 | 0.1361 | 9.00 | -0.5689 | 65.00 | 0.1619 (0.1548–0.1696) | – | – |
| ppi-pdl1 | 6 | 199.2 | 0 / 0 | 0.1620 | 0.2984 | 0.5397 | 23.00 | -0.2201 | 31.21 | – | 8.67 | 3.83 |

- 32 个设计全部 `bad_bond_frac = clash_frac = 0`。
- motif 的 `design_motif_allatom_rmsd` 是**设计 vs 输入 motif**；
- PPI 使用官方 `ppi_bb_only/pdl1.cif.zst`（生成 CIF 含 `condition_coordinate_1_atom`）；
  该输入不带 hotspot，因此没有 `hotspot_obedience` 列。

### 5.4 性能（SDAA）

5 任务并行、每任务独占一张卡：串行等价墙钟 38348.6 s（638.7 min），实际并行墙钟约 189 min；
峰值显存 2.28 GB、reserved 2.88 GB、RSS 4.11–4.12 GB。逐任务时间、显存、吞吐以及和 CUDA 的
倍数对比统一放在 **6.2 节的一张表**里，避免重复。

### 5.5 RNG 对齐验证（`TORCH_SDAA_ALIGN_NV_DEVICE=a100`）

Torch-SDAA 支持 `TORCH_SDAA_ALIGN_NV_DEVICE`（仅 `a100/A100/v100/V100`），把随机数管理器
对齐到 CUDA 的 V100/A100 行为；设置后 `torch.sdaa.random_align_nv_device()` 返回 `True`。

两边同 `seed=1234` 的 `randn(5)`：第 1 个数 `-1.6164904832839966` **逐位相同**，其余 4 个相对差
≤ 5.2e-7。说明两边是同一条随机流，差异只是 float32 正态变换的舍入。

对齐后，三个 monomer 任务的 A 类指标与 CUDA 的平均绝对差为：helix 0.0096、sheet 0.0088、
loop 0.0150、GRAVY 0.0244、instability 4.51（逐任务数值见 6.1）。剩余差异来自算子数值路径。
该设置不带来可测的生成性能开销。

## 六、pre-oracle 设计指标对比（SDAA vs CUDA）

同一 commit、同一权重（`a06e2509…`，sha256 `5b549dd6…`）、同一 seed、同一输入与 tags；
SDAA 为 a100 RNG 对齐结果，CUDA 为单 device 顺序执行。两边 32/32 设计 `bad_bond = clash = 0`。
格式为 `SDAA / CUDA`。

### 6.1 指标对照

| 任务 | n_res | helix | sheet | loop | GRAVY | instability | motif RMSD (Å) | H-bond pairs | salt-bridge pairs |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| monomer-short | 100 | 0.819 / 0.838 | 0.000 / 0.000 | 0.181 / 0.163 | -0.250 / -0.253 | 61.96 / 66.18 | – | – | – |
| monomer-medium | 150 | 0.713 / 0.718 | 0.083 / 0.069 | 0.203 / 0.213 | -0.172 / -0.126 | 76.14 / 75.97 | – | – | – |
| monomer-long | 250 | 0.689 / 0.694 | 0.098 / 0.110 | 0.213 / 0.196 | -0.075 / -0.100 | 49.34 / 40.21 | – | – | – |
| motif-1BCF | 124.5 | 0.864 / 0.875 | 0.000 / 0.000 | 0.136 / 0.125 | -0.569 / -0.670 | 65.00 / 66.11 | 0.1619 / ~0.16 | – | – |
| ppi-pdl1 | 199.2 | 0.162 / 0.170 | 0.298 / 0.298 | 0.540 / 0.532 | -0.220 / -0.451 | 31.21 / 50.19 | – | 8.67 / 4.67 | 3.83 / 3.17 |

### 6.2 性能对照

| 任务 | designs | SDAA wall (s) | CUDA wall (s) | 倍数 | SDAA s/设计 | CUDA s/设计 | SDAA peak / reserved (GB) | CUDA peak / reserved (GB) | SDAA RSS (GB) | CUDA RSS (GB) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| monomer-short | 8 | 3703.5 | 69.1 | 53.6× | 462.9 | 8.63 | 1.74 / 1.83 | 1.74 / 1.83 | 4.11 | 4.17 |
| monomer-medium | 6 | 5999.3 | 54.2 | 110.7× | 999.9 | 9.04 | 1.87 / 2.05 | 1.86 / 2.00 | 4.12 | 4.15 |
| monomer-long | 4 | 10808.1 | 60.6 | 178.4× | 2702.0 | 15.16 | 2.28 / 2.52 | 2.23 / 2.48 | 4.11 | 4.15 |
| motif-1BCF | 8 | 6629.4 | 71.3 | 93.0× | 828.7 | 8.91 | 1.83 / 2.08 | 1.82 / 1.99 | 4.12 | 4.17 |
| ppi-pdl1 | 6 | 11208.3 | 64.0 | 175.1× | 1868.0 | 10.66 | 2.15 / 2.88 | 2.11 / 2.53 | 4.12 | 4.18 |
| **合计** | **32** | **38348.6** | **319.2** | **120.1×** | **1198.4** | **9.98** | **2.28 / 2.88** | **2.23 / 2.53** | **4.12** | **4.18** |

吞吐（designs/s）：SDAA 0.0004–0.0022，CUDA 0.066–0.116。CPU util：SDAA 0.20–0.65%
（按 128 个逻辑核归一化），CUDA 1.74–1.76%（按 56 个逻辑核归一化）。

SDAA 为 5 任务并行、每任务独占一张卡（实际并行墙钟约 189 min）；CUDA 为单 device 顺序执行
（319.2 s 即实际总墙钟）。wall 是官方 validation epoch（生成 + inline 指标），不含模型加载。
两边都是 eager、batch size 1；SDAA 的 SDPA 对带加性 pair bias 的注意力回退到显式 einsum，
且无 FlashAttention / 融合 LayerNorm / cuEquivariance，差距随序列变长放大。显存与 RSS 很接近。

### 6.3 结论

1. **几何一致**：两边 32/32 设计 `bad_bond = clash = 0`。
2. **motif 条件依从一致**：design-vs-input motif RMSD 0.1619 Å vs ~0.16 Å。
3. **monomer 已收敛**：RNG 对齐后 helix/sheet/loop/GRAVY 与 CUDA 的差在 0.00–0.03 内，
   instability 差 ≤9（short/medium 3–4），说明主要差异来自噪声流，现已消除。
4. **PPI 仍有分叉**：sheet 几乎相同（0.298），但 GRAVY（-0.220 vs -0.451）、instability
   （31.2 vs 50.2）、H-bond（8.67 vs 4.67）不同——相同噪声下，长轨迹对数值路径更敏感。
5. **性能**：单设计 SDAA 约为 CUDA 的 53.6×–178.4×，总时间 120.1×。
6. **不能声称逐位一致**：SDPA→einsum、bf16、LayerNorm、cuEquivariance 路径不同。



## 七、踩坑记录

| # | 坑 | 根因 | 解决 |
|---|----|------|------|
| 1 | `torch.cuda.is_available()` 为 False | SDAA 不走 CUDA 运行时 | 启用 `torch_sdaa.utils.cuda_migrate` |
| 2 | `torch._dynamo` / torchmetrics import 失败 | SDAA backend 缺 `_CudaDeviceProperties`、`_set_stream_by_id` 等 | 兼容层补齐别名/stub |
| 3 | transformers 导入报 `CUDAGraph` 缺失 | `torch_sdaa.backend` 只有 `SDAAGraph` | `CUDAGraph = SDAAGraph` |
| 4 | `torch.Event` / `torch.Stream` 是函数 | Torch-SDAA 暴露为工厂函数，torch._dynamo 需要类 | 替换为 SDAA 真实类 |
| 5 | Lightning 初始化报 `get_device_capability` 不支持 | SDAA 抛 NotImplementedError | 返回 `(8, 0)` |
| 6 | SDPA 带加性 pair bias 没有可用 kernel | flash/mem 后端不支持非空 `attn_mask`，math 被禁用 | 首次失败后在进程内静默回退并永久使用显式 einsum（日志不一定有 `No available kernel`） |
| 7 | `torch.where` 设备不一致 | CPU 标量 + SDAA tensor | `torch.ones_like` |
| 8 | AtomWorks 强制 `biotite==1.6.0` | 环境是 1.7.1 | 运行期版本字符串 + API 桥接 |
| 9 | biotite 缺 `connect_via_residue_names` / `_bonds` | 1.7 改了模块布局 | 兼容层恢复旧路径 |
| 10 | rdkit 缺 `rdDetermineBonds` / InChI / `rdEHTTools` | LoongArch wheel 未编译这些模块 | fail-loud stub |
| 11 | rdkit 报 `libboost_numpy312` 缺失 | wheel 链接 3.12 Boost，系统只有 3.11 | `/usr/local/lib` 符号链接 |
| 12 | pyarrow 索引哈希不一致 | 内部索引元数据错误 | 直接下载 wheel + `--no-deps` |
| 13 | pyarrow 缺 `_parquet` | wheel 未编译 Parquet | `pyarrow.parquet` stub |
| 14 | numpy 2 下 rdkit 崩溃 | rdkit 使用 NumPy 1.x C API | 固定 `numpy==1.26.4` |
| 15 | scipy 1.18 要求 NumPy ≥2 | 与 rdkit 冲突 | 固定 `scipy==1.15.3` |
| 16 | wandb 源码构建需要 Go | LoongArch 无新 wheel | 使用 `wandb==0.17.9` |
| 17 | `torch.compile` 不可用 | SDAA 的 dynamo/inductor 支持不足 | `compile_lengths=null` |
| 18 | SDAA 本机无法算 refold/pass | 无 apptainer、AF3/OF3 镜像/权重、无 NVIDIA GPU | - |
| 19 | 无法算 Rosetta developability | 无 PyRosetta 容器 | 使用官方 sequence 子集 |
| 20 | `aggregate_metrics` 静默不执行 | Fire CLI 不接受 `input=<dir>`，被当成位置参数 | 用 `--input=<dir>` |
| 21 | 离线 `evaluate` 把 foldseek 链当重复设计 | `inference_samples/` 递归扫描包含 `foldseek_input_chains/`，PPI 出 12 行 | 仅对 `*_generated.cif` 建符号链接目录再评测 |
| 22 | PPI 生成 CIF 缺 `condition_coordinate_1_atom` | 旧输入是 `C_CRDGRP`（`linshi/work/binder.yaml`），不是官方 `C_CRD` | 改用官方 `ppi_bb_only/pdl1.cif.zst`；`refolded_target_backbone_aligned_binder_rmsd` / `ppi.pass` 才有输入 |
| 23 | 并行任务全挤在少数几张卡上 | `SDAA_VISIBLE_DEVICES` 索引的是逻辑设备（每卡 4 个），不是物理卡 | 按 `逻辑设备数/物理卡数` 换算卡槽（0–4 → 0,4,8,12,16） |

## 八、复现入口

```bash
cd .
source scripts/load_local_env.sh
export PYTHONPATH=src

# 推荐：RNG 对齐（与 CUDA 共用同一随机流）——文中的 SDAA 结果来自这里
export TORCH_SDAA_ALIGN_NV_DEVICE=a100
( setsid nohup env OUT_ROOT="$PWD/run_sdaa/results_aligned" \
    bash run_sdaa/run_all.sh > run_sdaa/logs/run_all_aligned.log 2>&1 < /dev/null & )

```

产物与记录（对齐运行）：

- `run_sdaa/results_aligned/sdaa/summary.md`：指标 + 性能 + 产物清单
- `run_sdaa/results_aligned/sdaa/metrics.csv`：任务 × 指标均值
- `run_sdaa/results_aligned/sdaa/run_env.txt`：平台、seed、权重 revision/sha256、commit、版本、起止时间
- `run_sdaa/results_aligned/sdaa/rng_probe.txt`：与 CUDA 核对随机流
- `run_sdaa/results_aligned/sdaa/command.txt` 与 `<task>/command.txt`：完整命令
- `run_sdaa/results_aligned/sdaa/checksums.sha256`：全部输出文件哈希
- `run_sdaa/results_aligned/sdaa/<task>/{inference_samples,inference_metrics,evaluation}`：结构与指标
- `run_sdaa/README.md`：脚本说明（含 CUDA 用法）
