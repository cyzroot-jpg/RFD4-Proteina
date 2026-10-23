# design.json schema v3.0

## 顶层目标

schema v3 不再把 design.json 当“填写完整即可”的文档，而是要求它能承载：

- shape 输入模式
- 分层性能模型
- 多级分块
- 真实分核和通信
- LDM / bank / pipeline 约束

## 顶层字段

| 字段 | 说明 |
|------|------|
| `schema_version` | `"3.0"` |
| `op` | snake_case |
| `title` / `status` | 标题；完成设计时 `status` 为 `review` / `approved` |
| `workflow` | 迭代元数据；完成时 `current_focus=complete` |

## operator_definition

```json
{
  "computation_type": "matmul",
  "operator_family": "gemm",
  "formula": "C = A * B",
  "logic_steps": [],
  "io_tensors": [],
  "kernel_apis": [],
  "independent_axes": ["M", "N"],
  "reduction_axes": ["K"],
  "reuse_axes": ["A@row", "B@col"]
}
```

## parameters

```json
{
  "shape_mode": "locked | ranged | ideal_search",
  "shape_keys": ["M", "N", "K"],
  "shapes": {"smoke": {}, "default": {}},
  "locked_shapes": {"M": 4096, "N": 4096, "K": 4096},
  "shape_ranges": {
    "M": {"min": 1, "max": 8192},
    "N": {"min": 1, "max": 8192},
    "K": {"min": 1, "max": 8192}
  },
  "ideal_shape_goal": {
    "enabled": false,
    "optimize_for": "throughput",
    "fixed_axes": {},
    "search_axes": ["M", "N", "K"],
    "notes": ""
  }
}
```

## throughput_model

```json
{
  "model_type": "layered_t1",
  "hardware_caps": {},
  "traffic_model": {},
  "stage_time_model_us": {
    "dma": 0.0,
    "rma": 0.0,
    "ace": 0.0,
    "simd": 0.0,
    "compute_group": 0.0,
    "writeback": 0.0,
    "sync": 0.0
  },
  "constraint_discounts": [],
  "bottleneck_type": "memory",
  "upper_bound_tflops": 68.0
}
```

## tiling_strategy

```json
{
  "tile_axis": "M/N/K or cols/rows",
  "tile_elems": 4096,
  "dma_bytes_per_tile": 8192,
  "alignment_bytes": 128,
  "hierarchy": ["global_tile", "core_tile", "ace_tile"],
  "selected_tile": {"M1": 1024, "N1": 256, "K1": 1536, "M2": 128, "N2": 32, "K2": 384},
  "search_space": {},
  "constraints": [],
  "feasible_region_summary": "",
  "rationale": ""
}
```

## core_partition_strategy

```json
{
  "slave_core_num": 32,
  "grid_shape": {"rows": 4, "cols": 8},
  "partition_axis": "M/N/K",
  "strategy": "2d_bcast | ring | split_k | row_stride",
  "pattern": "",
  "split_dimensions": [],
  "communication_pattern": [],
  "reduction_pattern": "",
  "loader_assignment": [],
  "rationale": ""
}
```

## double_buffer_strategy

```json
{
  "enabled": true,
  "buffered_tensors": ["A", "B"],
  "buffer_depth": 2,
  "overlap_dma_compute": true,
  "stage_buffers": [],
  "enable_condition": "T_dma < 0.8 * T_ace",
  "blocked_by": [],
  "rationale": ""
}
```

## ldm_planning

```json
{
  "budget_bytes_per_spe": 262144,
  "usable_budget_bytes": 240640,
  "buffers": [],
  "total_bytes": 196608,
  "fits_budget": true,
  "bank_allocation": [],
  "pressure_summary": "",
  "reuse_notes": "",
  "allocation_notes": ""
}
```

## pipeline_layout

```json
{
  "passes": [],
  "dataflow_description": "",
  "sync_points": [],
  "steady_state_stages": [],
  "overlap_pairs": [],
  "wait_points": [],
  "fill_drain_notes": ""
}
```

## scaffold / golden

`scaffold.family` 仅作为设计元数据，用于提示 teco-ops 落地形态。

- `elewise`
- `reduce`
- `norm`
- `manual`：设计阶段允许，后续按 teco-ops interface + UAL 布局人工落地
