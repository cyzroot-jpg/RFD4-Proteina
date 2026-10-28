# RFD4-Proteina 龙芯 SDAA 适配记录

> RFD4-Proteina 是一个 flow-matching 生物分子设计模型，联合生成蛋白序列与全原子结构，
> 支持 monomer、protein binder、motif scaffolding 等任务。
>
> 本次结论：**无自定义 CUDA 算子**；5 个官方任务（monomer ×3、motif、官方 PPI 输入）的生成、
> pre-oracle 设计指标、离线评测与聚合已在 SDAA 上端到端跑通，并用同一套脚本在 CUDA 复跑做对照
> （第六节）。AF3/OF3 refold 属于另一类 oracle 指标：SDAA 本机不能算，但已把 SDAA 与 CUDA 的设计
> 放到 CUDA 上用同一 oracle 统一 refold，并计算官方 pass 与 FoldSeek 聚类（第七节）。
> 另外验证了 `TORCH_SDAA_ALIGN_NV_DEVICE=a100` 可以把 SDAA 随机流对齐到 CUDA（5.5 节）：
> 对齐后 monomer 的 pre-oracle 指标与 CUDA 的平均差约 0.01–0.02，但逐设计 sequence identity 只有
> 0.68 / 0.64 / 0.38（monomer short/medium/long）、PPI 0.30；E1–E3 归因实验表明，B 类 refold 差异
> 主要来自“同噪声下仍生成不同设计”，oracle 自身采样噪声只占很小一部分（7.4 节）。
> 进一步用单步 fidelity + 消融把 monomer 的数值根因定位到**注意力实现（SDPA vs einsum）**：
> 在 CUDA 上强制 einsum 后，与 SDAA 的 identity 从 0.68 升到 0.89、design RMSD 从 1.16 降到
> 0.12 Å；cuEquivariance 与 bf16 不是主因（7.5 节）。

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
| 工作分支 | `main`（未新建分支） |
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
| AF3 / OF3 | – | CUDA 主机 | SDAA 本机无；refold 在 CUDA 上完成（第七节） |
| PyRosetta | – | – | 无容器；developability 使用官方 sequence 子集 |
| FoldSeek | – | CUDA 主机 | SDAA 本机无；聚类在 CUDA 上完成（第七节） |

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
| SDAA 本机无 AF3/OF3 | refold/pass 无法在 SDAA 上计算 | 把 SDAA 设计放到 CUDA，用同一 oracle 统一 refold（第七节） |
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
/data01/tuyilist/cyz/rfd4_assets/hf_cache/models--nvidia--RFD4-Proteina/snapshots/a06e2509c7033b010fc43614e9fd840303588502
```

运行时通过：

```bash
hf_ckpt_path=/data01/tuyilist/cyz/rfd4_assets/hf_cache/models--nvidia--RFD4-Proteina/snapshots/a06e2509c7033b010fc43614e9fd840303588502
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

本记录包含两类评估，计算阶段和含义不同，**不要混在同一张表里比较**：

- **A 类 pre-oracle 设计指标**（第五、六节）：生成时/离线计算，评价设计本身，不需要额外 oracle。
- **B 类 refold（oracle）指标**（第七节）：交给 AF3/OF3 重新预测后再比对，依赖独立 oracle 运行时。

本节及第六节使用 **a100 RNG 对齐** 的运行（`run_sdaa/results_aligned/sdaa`，2026-10-27
06:03:36–09:13:08 UTC，5/5 PASS）。

### 5.1 运行命令

```bash
cd /data01/tuyilist/cyz/RFD4-Proteina
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
- motif 的 `design_motif_allatom_rmsd` 是**设计 vs 输入 motif**；不要和第七节 refold 后的
  motif RMSD（5.93 Å）混淆。
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
7. **逐设计并不相同（E1）**：monomer-short / medium / long 的 identity 中位数分别为
   0.682 / 0.644 / 0.381，PPI 0.297；只有 short/medium 落在“同一邻域”（design backbone RMSD
   1.16 / 1.88 Å），long 与 PPI 已接近“完全不同设计”的基线（5.40 / 7.18 Å）。均值收敛不等于
   逐设计一致，详见 7.4 节。

### 6.4 各功能在 SDAA 的可用性

| 功能 | SDAA 状态 |
|------|------|
| 模型加载 / 生成 | 可用 |
| monomer / motif / PPI 生成（含官方 PPI 输入） | 可用 |
| 官方 inline 指标（design / developability / motif / interchain） | 可用 |
| 离线 `rfd4-evaluate`（生成 CIF 已保留条件注释） | 可用，且与 inline 指标逐项一致 |
| `sequence_developability`（GRAVY、instability） | 可用 |
| `rosetta_developability` | 不可用（无 PyRosetta） |
| AF3/OF3 refold、scRMSD/pLDDT/ipTM/ipAE | SDAA 本机不可用；已在 CUDA 上对 SDAA 与 CUDA 两批设计完成（第七节） |
| pass rate / FoldSeek 聚类 | SDAA 本机不可用；已在 CUDA 上完成（第七节） |
| torch.compile | 不可用（本次走 eager） |
| cuEquivariance / BioIR | 不可用（无对应 SDAA 运行时） |
| 训练 / 微调 | 本次未验证 |

## 七、B 类：refold（oracle）指标（AF3/OF3）

把设计交给独立的折叠模型重新预测，再看预测能否复现设计。SDAA 本机没有 oracle，所有数字都来自
CUDA：两批设计（CUDA 生成、SDAA a100 对齐生成，各 32 个）用**同一个 oracle、同一套权重**
统一 refold。每批均 32/32 `oracle ok`。

| 维度 | A 类：pre-oracle 设计指标（第五、六节） | B 类：refold（oracle）指标（本节） |
|---|---|---|
| 回答的问题 | 设计本身是否合理 | 独立折叠模型能否复现该设计 |
| 计算阶段 | 生成时 inline 或离线 design 指标 | 生成完成后调用 AF3/OF3 再比对 |
| 典型指标 | bad_bond/clash、SSE、GRAVY、instability、design-motif RMSD、interchain | pLDDT、pTM、ipTM、refolded backbone/motif RMSD、target-aligned binder RMSD、min ipAE |
| 依赖 | 结构 + 注释 | AF3/OF3 apptainer、镜像、权重 |

> 两个 motif RMSD 不同：A 类的 `design_motif_allatom_rmsd`（0.1619 Å）是**设计 vs 输入 motif**；
> 本节的 motif all-atom/CA（5.93 / 5.12 Å）是**refold vs 设计**。

### 7.1 B 类对照（SDAA a100 对齐 / CUDA）

每批 32/32 `oracle ok`；格式为 `SDAA / CUDA`。pLDDT / pTM / ipTM 为 0–100，越高越好；
RMSD 与 min ipAE 为 Å，越低越好；“–” 表示该任务不适用。

| 任务 | pLDDT | pTM | ipTM | backbone RMSD | motif all-atom | motif CA | binder RMSD | min ipAE |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| monomer-short | 82.85 / 88.64 | 74.88 / 82.50 | – | 2.02 / 0.404 | – | – | – | – |
| monomer-medium | 81.16 / 88.09 | 74.83 / 84.17 | – | 2.05 / 0.554 | – | – | – | – |
| monomer-long | 85.07 / 81.72 | 77.75 / 77.25 | – | 2.37 / 2.255 | – | – | – | – |
| motif-1BCF | 73.93 / 75.46 | 60.13 / 60.25 | – | 6.48 / 4.964 | 5.93 / 4.814 | 5.12 / 4.143 | – | – |
| ppi-pdl1 | 87.15 / 87.86 | 74.67 / 76.67 | 52.83 / 58.83 | 7.70 / 4.626 | – | – | 14.15 / 8.677 | 4.63 / 4.859 |

### 7.2 官方 pass 与 FoldSeek 聚类（CUDA 上计算）

判据（`configs/metrics/pass_criteria/all_pass_criteria.yaml`）：`unconditional` backbone ≤1.5 Å；
`motif_scaffold` backbone ≤2.0、motif all-atom ≤2.0、motif CA ≤1.0 Å；`ppi` `ptm_coi` ≥80、
`min_ipae_coi` ≤1.5 Å、binder RMSD ≤2.5 Å；`developability` GRAVY/instability + Rosetta 两项。
聚类后 pass 按结构簇计数；多样性 = 簇数/设计数。pass 一列写成 `任务判据 / developability`。

| 任务 | 判据 | SDAA pass | CUDA pass | SDAA 聚类后 | CUDA 聚类后 | 簇数 (S/C) | 多样性 (S/C) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| monomer-short | unconditional / developability | 0.750 / 0.000 | **1.000** / 0.000 | 0.375 / 0.000 | **0.625** / 0.000 | 5 / 5 | 0.625 / 0.625 |
| monomer-medium | unconditional / developability | 0.833 / 0.167 | **1.000** / 0.333 | 0.833 / 0.167 | **1.000** / 0.333 | 6 / 6 | 1.000 / 1.000 |
| monomer-long | unconditional / developability | 0.500 / 0.000 | **0.750** / 0.000 | 0.500 / 0.000 | **0.750** / 0.000 | 4 / 4 | 1.000 / 1.000 |
| motif-1BCF | motif_scaffold / developability | 0.625 / **0.125** | 0.625 / 0.000 | 0.125 / **0.125** | 0.125 / 0.000 | 1 / 1 | 0.125 / 0.125 |
| ppi-pdl1 | ppi / developability | 0.333 / 0.167 | 0.333 / 0.167 | 0.333 / 0.167 | 0.333 / 0.167 | 5 / 4 | 0.833 / 0.667 |

> “普通 pass” 是任务专属判据（unconditional / motif_scaffold / ppi），不等于包含 developability 的
> 最终官方 pass；两者同时满足才会进入交付集。

### 7.3 解读

1. **monomer**：对齐后 SDAA 的 short/medium 比 CUDA 弱（82.85/81.16 vs 88.64/88.09；
   RMSD 2.02/2.05 vs 0.404/0.554 Å）；long 两边接近（85.07/2.37 vs 81.72/2.255 Å），
   但 N=4，参考价值有限。
2. **motif**：对齐后 pLDDT/pTM 已与 CUDA 基本持平（73.93/60.13 vs 75.46/60.25），但
   backbone 与 motif RMSD 仍高（6.48 / 5.93 / 5.12 vs 4.96 / 4.81 / 4.14 Å）。两批都远高于
   pass 阈值，说明这个 motif 任务的可设计性本身偏弱，不是平台问题。
3. **PPI**：pLDDT 接近，但 ipTM（52.83 vs 58.83）和 binder RMSD（14.15 vs 8.68 Å）更差，
   min ipAE（4.63 vs 4.86 Å）略好。两批 binder RMSD 分别为 14.15 / 8.68 Å，远高于 2.5 Å 的 pass 线，
   界面放置是主要瓶颈。
4. **pass 与多样性（SDAA / CUDA）**：任务 pass CUDA 更高（unconditional 1.000 / 1.000 / 0.750
   vs SDAA 0.750 / 0.833 / 0.500）；聚类后 short 0.625 vs 0.375、medium 1.000 vs 0.833、
   long 0.750 vs 0.500。**motif 两边都只有 1 个簇**，普通 pass 0.625 但聚类后仅 0.125，
   说明采样坍缩到同一解；PPI 两边都是 0.333（SDAA 5 簇、CUDA 4 簇）。
   注意每档差异只相当于 1–2 个设计（n=4–8，pass 粒度为 1/6–1/8），在这些样本量下
   不具统计显著性，不能据此判断平台优劣。
5. **developability 是最终瓶颈**：SDAA 仅 0–0.167，CUDA 仅 0–0.333。本批 SDAA 的 instability
   均值 31–76，官方阈值 ≤40，short/medium（61.96/76.14）直接不过。因此即使 refold 任务 pass
   很高（CUDA short 为 1.000），最终官方 pass（refold ∧ developability）仍接近 0。
6. **归因（E1–E3，7.4 节）**：把两边设计在**同一台 A100、同一 oracle、同一固定 seed** 下重算后，
   oracle 自身方差很小（pLDDT σ 0.11–0.66、backbone RMSD σ 0.14–0.68、motif CA σ 1.29），
   而观测到的逐设计 |Δ| 普遍是 2σ 的 2–18 倍；同时 identity 与 |Δ| 强相关（short ρ=−0.86、
   PPI ρ=−0.83）。因此 B 类差异来自**设计不同**，不是 oracle 噪声，也不是指标实现。
   至于“设计为何不同”，7.5 节的 D1/D2 实验把 monomer 的主因定位到注意力路径。
7. **建议**：motif 需要多样性/搜索（1 个簇说明重复采样）；developability 与 PPI 界面指标应作为
   reward 做搜索；结论中同时报告普通与聚类后 pass，并增大 replicates。

### 7.4 B 类差异归因实验（E1 / E2 / E3）

为回答“B 类差异是设计不同还是 oracle 噪声”，把两批设计放到**同一台 A100、同一 OF3 oracle、
同一固定 diffusion seed** 下重新 refold（不复用之前任何一方的数值），并做三组实验：

- **E1**：按文件名配对，比较序列 identity 与 design-vs-design backbone RMSD（不需要 oracle）；
- **E2**：对同一批 CIF 用 seed 0/1/2 重复 refold，测 oracle 自身方差（每任务 2 个设计）；
- **E3**：逐设计比较 SDAA−CUDA 的 refold 指标，并用 `2σ = 2√2·std_single` 判定噪声可解释性。

#### E1：两边生成的是不是同一批设计

| 任务 | pairs | median identity | ≥0.95 | median design RMSD (Å) | max (Å) |
| --- | ---: | ---: | ---: | ---: | ---: |
| monomer-short | 8 | 0.682 | 37.5% | 1.160 | 9.32 |
| monomer-medium | 6 | 0.644 | 16.7% | 1.880 | 7.91 |
| monomer-long | 4 | 0.381 | 0% | 5.400 | 10.27 |
| motif-1BCF | 8 | 0.794 | 0% | 0.363 | 2.00 |
| ppi-pdl1 | 6 | 0.297 | 16.7% | 7.183 | 11.53 |

对照基线（**对齐 vs 未对齐的 SDAA 自比**，即“不同设计”的量级）：identity 0.31 / 0.31 / 0.27 /
0.80 / 0.31，design RMSD 13.2 / 15.8 / 24.4 / 0.23 / 9.7 Å。

读法：short/medium 明显进入同一邻域（identity 0.68/0.64、RMSD 1.2/1.9 Å），但仍有 3–4 个设计
完全不同；long 与 PPI 基本停在基线水平（0.38/5.4、0.30/7.2 Å），轨迹已分叉；motif 的 identity
被固定 motif 残基抬高（0.79），但 design RMSD 只有 0.36 Å，说明“结构接近、序列不同”。

#### E2：oracle 自身方差（同一 CIF，仅换 diffusion seed）

| 任务 | pLDDT σ | backbone RMSD σ (Å) | 其他 |
| --- | ---: | ---: | --- |
| monomer-short | 0.11 | 0.14 | pTM σ = 0 |
| monomer-medium | 0.66 | 0.40 | |
| monomer-long | 0.53 | 0.30 | |
| motif-1BCF | 0.44 | 0.68 | motif CA RMSD σ 1.29 |
| ppi-pdl1 | 0.34 | 0.04 | ipTM σ 1.61 |

即：**同一设计两次独立 refold** 的 2σ 约为 pLDDT 0.3–1.9、backbone RMSD 0.1–1.1 Å。

#### E3：逐设计归因

| 任务 | 指标 | median abs(Δ) | max abs(Δ) | 2σ_oracle | 落在 2σ 内 | ρ(identity, abs(Δ)) |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| monomer-short | pLDDT | 1.73 | 22.42 | 0.32 | 12.5% | −0.86 |
| monomer-short | backbone RMSD | 0.08 | 7.08 | 0.38 | 62.5% | −0.29 |
| monomer-medium | pLDDT | 0.49 | 36.80 | 1.86 | 66.7% | +0.09 |
| monomer-long | pLDDT | 4.48 | 13.34 | 1.50 | 25.0% | −0.20 |
| motif-1BCF | pLDDT | 22.17 | 39.57 | 1.24 | 12.5% | −0.07 |
| ppi-pdl1 | pLDDT | 3.22 | 5.97 | 0.97 | 0% | −0.60 |
| ppi-pdl1 | ipTM | 10.00 | 56.00 | 4.55 | 33.3% | −0.83 |

逐设计细节：

- **monomer-short**：identity ≥0.8 的 4 对，|ΔpLDDT| ≤ 1.53；identity 0.40–0.56 的 rep6/rep7，
  ΔpLDDT 达 −22；ρ = −0.86。
- **motif**：两边 backbone 只差 0.13–2.0 Å，但 pLDDT 可差 35–40 分，且**双向**（有时 SDAA 差、
  有时 CUDA 差）。E2 的 σ 只有 0.44，因此这是 scaffold 上少量残基不同导致的“双稳”，不是噪声。
- **PPI**：ipTM 中位差 10 分（2σ=4.55），ρ=−0.83。

#### 结论

1. **B 类差异不是 oracle 噪声**：除 monomer-medium 外，逐设计 |Δ| 普遍是 2σ 的 2–18 倍。
2. **来源是设计不同**：identity 0.30–0.68、design backbone RMSD 0.36–7.2 Å，且 identity 与 |Δ|
   强相关（short −0.86、PPI −0.83）。
3. **RNG 对齐只是把 short/medium 拉近**（identity 0.68/0.64，对照基线 0.31），没有消除分叉；
   long 与 PPI 仍在基线水平。
4. **适配本身没有系统性错误**：权重、代码、oracle 都相同；差异来自跨后端数值路径，属于预期行为。
   但“逐设计等价”不成立，跨平台比较必须用分布/多 replicates，不能按单设计对齐。

#### 注意

- E2 每任务只用 `LIMIT=2` 个设计估 σ，σ 的不确定度较大；若要写进正式结论，建议 `LIMIT=8` 重跑。
- 早期 B 类数字混用了 inline 与 offline oracle（template/crop 路径可能不同），E3 已把两边统一重算，
  其结论不受该混淆影响。
- motif 的 sequence identity 被固定 motif 抬高，判断“是否同一设计”应看 design backbone RMSD。

实验产物：`linshi2/2222/out/{E1,E2,E3}/`、`linshi2/2222/out/REPORT.md`；脚本在
`run_sdaa/experiments/`。

### 7.5 数值根因定位（D1 / D2）

#### D1 单步 fidelity：第一次 trunk 调用就已经不同

方法：`fidelity_probe.py` 在第一次调用 trunk 时保存输入/输出张量；两边用完全相同的命令
（`nsteps=20`、1 个设计、seed 1234、`TORCH_SDAA_ALIGN_NV_DEVICE=a100`），再由
`compare_fidelity.py` 逐张量比较。

| 张量（第一次 trunk 输出） | 相对差 | max abs | mean abs |
| --- | ---: | ---: | ---: |
| `insertion.logits` | 1.15e-2 | 3.75e-1 | 7.34e-2 |
| `bb_ca.v` | 6.93e-3 | 3.13e-2 | 5.98e-3 |
| `local_latents.v` | 5.01e-3 | 1.95e-2 | 4.04e-3 |
| `sequence.logits` | 1.81e-3 | 2.50e-1 | 2.94e-2 |

对照：SDAA 自身两次运行 rel = 0；CUDA 自身两次运行 rel = 0（各自确定性）。
所以这 0.2–1.1% 的差是**跨后端单步数值差**，不是采样噪声。

#### D2 消融：一次只改一条数值路径（CUDA，60 步，对比 SDAA 参考设计）

表中为 `median identity / median design RMSD (Å)`：

| 变体 | monomer-short | motif-1BCF | ppi-pdl1 |
| --- | --- | --- | --- |
| base | 0.682 / 1.160 | 0.794 / 0.363 | 0.297 / 7.183 |
| **einsum** | **0.890 / 0.123** | 0.781 / 0.642 | 0.312 / 6.575 |
| einsum_no_cuet | 0.890 / 0.123 | 0.781 / 0.642 | 0.312 / 6.575 |
| no_cuet | 0.682 / 1.160 | 0.794 / 0.363 | 0.297 / 7.183 |
| fp32 | 0.696 / 1.145 | 0.786 / 0.365 | 0.278 / 8.773 |
| det | 0.707 / 0.763 | 0.800 / 0.359 | 0.297 / 7.256 |

判读：

1. **monomer-short 的主因是注意力实现**：把 CUDA 的 SDPA 换成显式 einsum 后，identity 0.682 →
   0.890，design RMSD 1.160 → 0.123 Å；而 `no_cuet` 与 base 完全相同，`fp32`、`det` 只有小幅变化。
   即 **SDPA vs einsum 是 monomer 分叉的主因，cuEquivariance 和 bf16 不是**。
2. **仍有残余**：0.890 而非 1.0、RMSD 0.123 而非 0，说明其余算子（matmul 分块/归约、softmax、
   LayerNorm 等）仍有差异。
3. **motif / PPI 不是这一条**：强制 einsum 对 motif 反而略差（0.794 → 0.781、RMSD 0.363 → 0.642），
   对 PPI 仅从 0.297 升到 0.312；`no_cuet`、`fp32` 也没有改善。它们的差异来自其他算子或
   更混沌的累积，需要 D3 或更细粒度张量比较。
4. **注意 ablation 的边界**：`einsum` 变体把**所有** SDPA 都换成 einsum，是 SDAA 路径的超集；
   D2 只在 CUDA 侧做，结论是“CUDA 变到像 SDAA 后 identity 提高”，严格确认仍需双边同时强制
   的 D3。

结论：到这一层可以写实为——**根因是跨后端数值路径；对 monomer 主要是注意力实现（SDPA vs
einsum），cuEquivariance/bf16 已被排除为主因；motif/PPI 的残余差异尚未定位到单一算子。**

## 八、踩坑记录

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
| 18 | SDAA 本机无法算 refold/pass | 无 apptainer、AF3/OF3 镜像/权重、无 NVIDIA GPU | 把两批设计放到 CUDA 节点，用同一 oracle 统一 refold（第七节） |
| 19 | 无法算 Rosetta developability | 无 PyRosetta 容器 | 使用官方 sequence 子集 |
| 20 | `aggregate_metrics` 静默不执行 | Fire CLI 不接受 `input=<dir>`，被当成位置参数 | 用 `--input=<dir>` |
| 21 | 离线 `evaluate` 把 foldseek 链当重复设计 | `inference_samples/` 递归扫描包含 `foldseek_input_chains/`，PPI 出 12 行 | 仅对 `*_generated.cif` 建符号链接目录再评测 |
| 22 | PPI 生成 CIF 缺 `condition_coordinate_1_atom` | 旧输入是 `C_CRDGRP`（`linshi/work/binder.yaml`），不是官方 `C_CRD` | 改用官方 `ppi_bb_only/pdl1.cif.zst`；`refolded_target_backbone_aligned_binder_rmsd` / `ppi.pass` 才有输入 |
| 23 | 并行任务全挤在少数几张卡上 | `SDAA_VISIBLE_DEVICES` 索引的是逻辑设备（每卡 4 个），不是物理卡 | 按 `逻辑设备数/物理卡数` 换算卡槽（0–4 → 0,4,8,12,16） |

## 九、复现入口

```bash
cd /data01/tuyilist/cyz/RFD4-Proteina
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

refold（B 类指标）在 CUDA 上执行，命令形状（monomer 示例）：

```bash
python3 -m rfproteina.evaluate \
  inputs=<designs>/inference_samples \
  'metrics_tags=[design,developability,unconditional_refolding]' \
  metrics/inline_metrics=all_inline_metrics_no_rosetta \
  metrics/refolding_oracles=of3 \
  job_id=0 out_dir=<designs>/evaluation_refold
```

motif 用 `[design,developability,3d_coordinate_conditioning,motif_scaffold_refolding]`，
PPI 用 `[design,developability,interchain_interactions,ppi_refolding]`；换 AF3 时去掉
`metrics/refolding_oracles=of3` 并设置 `AF3_IMAGE`/`AF3_MODEL_DIR`/`AF3_JAX_CACHE_DIR`。
