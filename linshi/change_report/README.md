# RFD4-Proteina SDAA 适配改动与踩坑记录

## 1. 结论

项目已在 Teco SDAA（LoongArch / Torch-SDAA 3.3.0 / PyTorch 2.12.0）上完成端到端
生成与官方指标评测。原始 CUDA 代码路径保持不变；SDAA 支持通过一个窄范围的
运行时兼容层启用，CPU/CUDA 上该层为 no-op。

## 2. 代码改动清单

| 文件 | 改动 | 目的 |
| --- | --- | --- |
| `src/rfproteina/utils/sdaa_compat.py`（新增） | SDAA 检测、`torch_sdaa.utils.cuda_migrate` 自动迁移、biotite/rdkit/pyarrow/torch 兼容 shim | 让未修改的 CUDA 风格代码在 SDAA 上运行 |
| `src/rfproteina/__init__.py` | 在导入 AtomWorks 前调用 `activate_accelerator_compat()` | 保证设备与依赖 shim 早于 AtomWorks/Lightning 生效 |
| `src/rfproteina/nn/modules/pair_bias_attn.py` | SDAA 上尝试 SDPA，失败则永久回退到显式 einsum；CPU 保持 einsum | SDAA 的 SDPA 对 additive pair bias 可能无可用 kernel；显式路径数值等价 |
| `src/rfproteina/utils/align.py` | `torch.tensor(1.0)` → `torch.ones_like(num_elements)` | 修复 `torch.where` 的 CPU/SDAA 设备不一致 |
| `src/rfproteina/generate.py` | `accelerator` 从 `cfg.hardware.accelerator` 读取；挂载 `ResourceMonitorCallback` | 支持 CPU/CUDA/SDAA 三平台；记录推理性能 |
| `src/rfproteina/evaluate.py` | `main_hydra` 外包 `ResourceUsageRecorder` | 评测阶段记录耗时/内存/CPU |
| `src/rfproteina/utils/resource_monitor.py`（新增） | Lightning callback + 独立 recorder | 记录 wall time、samples/s、device peak memory、RSS、CPU 利用率 |
| `configs/metrics/inline_metrics/developability_metrics_no_rosetta.yaml`（新增） | 仅保留 `sequence_developability` | 无 PyRosetta 容器时仍可运行官方 developability 子集 |
| `configs/metrics/inline_metrics/all_inline_metrics_no_rosetta.yaml`（新增） | 组合上述 developability 组 | 用 `metrics/inline_metrics=all_inline_metrics_no_rosetta` 选择 |

未修改任何模型结构、权重、采样默认值或官方指标定义。

## 3. 环境依赖与安装

### 3.1 `loongarch_packages` 检查结果

目录 `/data01/tuyilist/cyz/teco-drug-discovery-modelzoo/loongarch_packages` 内容与本次
使用情况：

| wheel | 本次是否使用 | 用途 |
| --- | --- | --- |
| `rdkit-2026.9.1-py3-none-linux_loongarch64.whl` | **是** | AtomWorks 化学/键/注释 |
| `openbabel-0.1.dev6623+...whl` | **是** | AtomWorks `[openbabel]` extra |
| `biotite-0.1.dev5354+...whl` | 否 | 环境已有可用的 biotite 1.7.1 LoongArch 构建 |
| `biotraj-1.2.2` | **是（从 pip 缓存）** | `biotite.structure.io.xtc` 依赖 |
| `freesasa` | 否 | 仅部分可选指标/工具使用；本次指标未触发 |
| `plip` / `prodigy_prot` | 否 | 可选相互作用/亲和力指标；本次未触发 |
| `gensim` / `pyscf` | 否 | 本次推理/指标未使用 |
| `torch_scatter` / `torch_cluster` / `torch_sparse` | 否 | 当前 checkpoint 推理路径未使用 |
| `cyclicpeptide` | 否 | 环肽任务；本次未评测 |

另外从 pip 缓存安装：

- `biotraj-1.2.2-cp312-cp312-linux_loongarch64.whl`

`biotite` 使用环境中已存在的 LoongArch 构建（1.7.1）。

### 3.2 需要额外处理的包

- **pyarrow**：LoongArch 索引提供 `pyarrow-23.0.1-...loongarch64.whl`，但索引中的哈希
  记录不一致，直接 `pip install pyarrow` 会报 hash mismatch。改为直接下载 wheel 后
  `pip install --no-deps <wheel>`。该 wheel 不含 `_parquet`，运行期由兼容层安装一个
  “被调用时才报错”的 `pyarrow.parquet` stub（推理路径不读 Parquet）。
- **wandb**：LoongArch 无预编译 wheel，源码构建需要 Go。安装 `wandb==0.17.9`
  （纯 Python wheel）即可满足 `import wandb`；推理不使用 wandb-core。
- **numpy**：rdkit 2026.9.1 LoongArch 构建使用 NumPy 1.x C API。NumPy 2.5.3 下
  rdkit 会在 `SetPositions` 等路径抛出 `_ARRAY_API not found` 并崩溃。固定
  `numpy==1.26.4`，同时将 scipy 降到 1.15.3（scipy 1.18 要求 NumPy ≥2）。
- **rdkit 缺少的模块**：该 LoongArch wheel 不含 `rdDetermineBonds`、InChI 绑定和
  `rdEHTTools`，而 AtomWorks 在 import 时无条件引用。兼容层提供：
  - `rdDetermineBonds.DetermineBonds`：仅在 `infer_bonds=True` 时抛
    `NotImplementedError`；
  - `MolFromInchi` 等 InChI 函数：仅在被调用时抛错；
  - `rdEHTTools.RunMol`：仅在被调用时抛错。
  本次所有输入都带显式键或不需要这些功能，故未触发。
- **rdkit 的 Boost 依赖**：wheel 动态链接 `libboost_numpy312.so.1.81.0` /
  `libboost_python312.so.1.81.0`，系统只有 Python 3.11 版本。创建了兼容符号链接：
  `/usr/local/lib/libboost_numpy312.so.1.81.0 -> /usr/lib64/libboost_numpy311.so.1.81.0`
  （libboost_python 同理）。这是运行时 ABI 兼容处理，不改项目代码。

## 4. 主要踩坑

1. **`torch.cuda.is_available()` 在 SDAA 上默认是 False**
   - 解决：导入 `torch_sdaa.utils.cuda_migrate` 后，`torch.cuda.*` 与
     `device="cuda"` 自动映射到 SDAA；`torch.cuda.device_count()` 变为 32。
2. **Lightning 读取 `torch.cuda.get_device_capability()`**
   - SDAA 抛出 `NotImplementedError`。
   - 解决：兼容层返回 `(8, 0)`，让 Lightning 走 tensor-core 分支。
3. **`torch._dynamo` / torchvision / torchmetrics 导入失败**
   - `torch_sdaa.backend` 缺少 `_CudaDeviceProperties`、`_set_stream_by_id`、
     `_exchange_device`、`_maybe_exchange_device`、`CUDAGraph`；`torch.Event`/
     `torch.Stream` 被实现为函数而非类。
   - 解决：在兼容层补齐别名/惰性 stub，并把 `torch.Event/Stream` 设为 SDAA 的真实类。
4. **transformers 在 torchmetrics 内部导入时失败**
   - 根因同上：`torch.cuda.CUDAGraph` 不存在，transformers 的连续批处理模块在
     类注解求值时失败。补齐 `CUDAGraph` 后解决。
5. **AtomWorks 强制 `biotite==1.6.0`**
   - 环境中的 LoongArch biotite 是 1.7.1，且 `connect_via_residue_names` 从
     `biotite.structure.bonds` 移到了 `biotite.structure.connect`；
     `BondList._bonds` 私有属性也被移除。
   - 解决：兼容层把 `connect_via_residue_names` 重新暴露到旧路径，给 `BondList`
     加 `_bonds` property（返回 `as_array()`），并在运行期把版本字符串呈现为 1.6.0。
     这是“API 兼容层”，不修改 biotite/AtomWorks 源码。
6. **SDPA 在 SDAA 上对 additive pair bias 无可用 kernel**
   - 首次报 `RuntimeError: No available kernel`，同时发现 `attn_bias` 与 q/k/v
     的 dtype 可能不一致（float32 mask + bf16 query 会直接报 dtype 错）。
   - 解决：统一 cast 到 `target_dtype` 后重试 SDPA；若仍失败则永久回退到显式
     einsum（数学等价，仅性能不同）。回退状态按进程缓存，避免每步重试。
7. **`torch.where` 设备不一致**
   - `mean_w_mask` 用 CPU 标量 `torch.tensor(1.0)` 与 SDAA tensor 做 where，CUDA
     上通常被 0-d 广播掩盖，SDAA 上直接报 device mismatch。
   - 解决：改为 `torch.ones_like(num_elements)`。
8. **RMSNorm dtype warning**
   - 模型权重 FP32 + bf16-mixed autocast 时，`F.rms_norm` 的 weight 是 FP32、input
     是 BF16，SDAA 不走 fused 实现，仅影响性能，不影响数值。
   - 未强制改精度，保持官方 `bf16-mixed` 默认。
9. **`torch.compile` 不可用**
   - SDAA 上 `torch._dynamo` 的 CUDA 假设较多；本次所有评测使用
     `inference_experiment=quickstart` 或显式 `compile_lengths=null`，即 eager 路径。
     这与官方 regression baseline 的 eager 路径一致。
10. **离线评测缺少输入注释**
    - `rfd4-evaluate` 对 motif RMSD / hotspot / interchain 等指标需要输入 CIF；
      默认生成只在启用指标时保存 `_input.cif`。
    - 解决：这些任务在生成时直接传 `metrics_tags`，走官方 inline 指标管线。
11. **无 AF3/OF3 与 PyRosetta**
    - 未计算 refolding 指标、pLDDT/ipTM/ipAE 和 pass rate；报告中明确标注。
    - Rosetta developability 用官方 `sequence_developability` 子集替代，并新增
      `all_inline_metrics_no_rosetta` 配置组。

## 5. 复现命令

```bash
cd /data01/tuyilist/cyz/RFD4-Proteina
source scripts/load_local_env.sh

# 生成（SDAA）
PYTHONPATH=src python3 -m rfproteina.generate \
  inference_experiment=quickstart \
  inputs=data/benchmarks/monomer/monomer-short.cif.zst \
  out_dir=./linshi/work/gen_default/short \
  hf_ckpt_path=/data01/tuyilist/cyz/rfd4_assets/hf_cache/models--nvidia--RFD4-Proteina/snapshots/a06e2509c7033b010fc43614e9fd840303588502

# 离线官方指标
PYTHONPATH=src python3 -m rfproteina.evaluate \
  inputs=./linshi/work/gen_default/short/inference_samples \
  metrics_tags='[design,developability]' \
  metrics/inline_metrics=all_inline_metrics_no_rosetta \
  out_dir=./linshi/work/eval_short
```

## 6. 未提交的运行时文件

- `.env.local`：`DATA_PATH`、`HF_HOME`、`HF_HUB_OFFLINE=1`、本地权重路径。
- `/usr/local/lib/libboost_{numpy,python}312.so.1.81.0`：rdkit 运行时兼容符号链接。
- HF 权重缓存：`/data01/tuyilist/cyz/rfd4_assets/hf_cache/`。
- `linshi/`：本次适配的日志、脚本、报告与生成结果（不进入源码 patch）。