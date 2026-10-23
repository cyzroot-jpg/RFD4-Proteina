#!/usr/bin/env python3
"""Create a learning-validation task markdown from a standard template."""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

import backend_profiles

SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
REPO_ROOT = SKILL_DIR.parents[1]
TEMPLATE_PATH = SKILL_DIR / "templates" / "learning_task.md.tpl"

PROFILE_ALIASES = {
    "gemmex": "gemm",
    "hgemm": "gemm",
    "matmul": "gemm",
}

FOCUS_PROFILES: dict[str, list[tuple[str, str, list[str]]]] = {
    "generic": [
        (
            "Stage A：适用边界 / Dispatch",
            "documented_only",
            [
                "支持的输入规模、dtype、layout 和对齐约束。",
                "dispatch 或 tune-record 的命中条件。",
                "tail、padding、workspace 和不支持场景。",
            ],
        ),
        (
            "Stage B：执行组织",
            "smoke_covered",
            [
                "核心循环、并行维度和 tile 拆分方式。",
                "主要 runtime / kernel API 的调用顺序。",
                "每个阶段的输入输出 buffer ownership。",
            ],
        ),
        (
            "Stage C：访存 / 同步",
            "smoke_covered；若涉及 RMA、跨核归约或 workspace，则升级为 staged_validation",
            [
                "HBM、LDM、workspace 之间的数据流。",
                "reply 变量、wait 点、sync 点和清零点。",
                "哪些细节是正确性必需，哪些只是性能优化。",
            ],
        ),
    ],
    "gemm": [
        (
            "Stage A：GEMM 适用边界 / Dispatch",
            "documented_only",
            [
                "支持的 M/N/K 范围、对齐约束和 tail 处理。",
                "transA/transB、A/B/C dtype、leading dimension 和 layout contract。",
                "small-K / large-K / split-K 分支阈值；若来自 tune record，记录命中条件。",
                "不支持场景：非对齐、特殊 beta、workspace 不足、shape 太小或太大。",
            ],
        ),
        (
            "Stage B：ACE 计算 / 分块 / 分核",
            "partial_smoke；ACE micro path 用 smoke 覆盖，分块/分核/K 大循环必须用 mid/target staged_validation 覆盖",
            [
                "Smoke 只验证最小 ACE load / compute / writeback 链路，不得声明已覆盖完整分块和分核策略。",
                "ACE north/west load 模式，A/B 在 LDM 中分别按什么布局喂给 ACE。",
                "ACE flags：Accumflag、Lastflag、Northflag、writeback precision 的取值规则；Lastflag 和多次 Accum 需用 larger-K shape 复核。",
                "K loop 的推进、累加初始化和最后一次 writeback 条件，需覆盖 smoke/mid/target 三档。",
            ],
        ),
        (
            "Stage C：A/B/C 访存 / LDM / 同步",
            "smoke_covered；若涉及 RMA、SplitK 或 workspace，则升级为 staged_validation",
            [
                "A、B、C 从 HBM 到 LDM 或从 ACE 到 HBM 的完整路径。",
                "DMA、RMA、direct writeback 分别用于哪些 tensor 和阶段。",
                "LDM layout、bank pressure、buffer 大小和 producer / consumer 关系。",
                "reply 变量、wait 点、sync 点和清零点；哪些 wait 可以后移以隐藏延迟。",
                "若使用 partial C，说明 workspace 大小、生命周期和最终归约方式。",
            ],
        ),
        (
            "Stage D：GEMM 流水 / 性能策略",
            "staged_validation",
            [
                "M/N/K tiling：CTA/SPE tile、ACE tile、K step 的具体关系，需在 mid/target shape 复核。",
                "SPE grid 如何映射 M、N、K，是否存在 splitK 或 group 分配，需在多 tile shape 复核。",
                "fill、steady、drain 阶段分别做什么。",
                "DMA、RMA、ACE、SIMD、sync 哪些 stage 能 overlap，哪些不能。",
                "双缓冲用在 A、B、C、partial C 或 workspace 的哪个位置，切换条件是什么。",
                "ACE 结果是否会在最终 C 前写到 HBM；如果会，原因是什么，如何实现。",
                "每条模式标注为 required、shape-dependent、optimization 或 do-not-copy。",
            ],
        ),
    ],
}


def parse_shape(value: str) -> dict[str, int]:
    """Parse positional M,N,K or arbitrary key=value dimensions."""
    text = value.strip()
    if not text:
        raise ValueError("shape must not be empty")
    if "=" not in text:
        parts = [p.strip() for p in text.split(",")]
        if len(parts) != 3:
            raise ValueError(f"shape '{value}' must be M,N,K")
        dimensions = [int(part) for part in parts]
        if any(dimension <= 0 for dimension in dimensions):
            raise ValueError("shape dimensions must be positive")
        return dict(zip(("M", "N", "K"), dimensions))

    result: dict[str, int] = {}
    for item in text.split(","):
        if "=" not in item:
            raise ValueError(f"shape item '{item}' must be key=value")
        key, raw = item.split("=", 1)
        key = key.strip()
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            raise ValueError(f"invalid shape key: {key}")
        if key.lower() in {"m", "n", "k"}:
            key = key.upper()
        if key in result:
            raise ValueError(f"duplicate shape key: {key}")
        dimension = int(raw.strip())
        if dimension <= 0:
            raise ValueError(f"shape dimension must be positive: {key}={dimension}")
        result[key] = dimension
    return result


def default_stage_shape(profile: str, target_shape: dict[str, int], stage: str) -> dict[str, int]:
    """Return a safe candidate shape when the caller did not specify one."""
    if profile == "gemm" and {"M", "N", "K"} <= target_shape.keys():
        if stage == "smoke":
            return {"M": 128, "N": 32, "K": 128}
        return {"M": 512, "N": 512, "K": 1024}
    return dict(target_shape)


def validate_op_name(name: str) -> None:
    if not re.fullmatch(r"[a-z][a-z0-9_]*", name):
        raise ValueError(f"invalid op name '{name}', expected snake_case")


def topic_to_path(topic: str) -> Path:
    clean = topic.strip().strip("/")
    if not clean or ".." in clean.split("/"):
        raise ValueError(f"invalid topic: {topic}")
    return Path(clean)


def shape_block(shape: dict[str, int]) -> str:
    return "\n".join(f"- {key}={value}" for key, value in shape.items())


def baseline_shapes_table(shapes: list[dict[str, int]]) -> str:
    if not shapes:
        return "- 无"
    keys = list(dict.fromkeys(key for shape in shapes for key in shape))
    lines = ["| " + " | ".join(keys) + " |", "|" + "---|" * len(keys)]
    for shape in shapes:
        lines.append("| " + " | ".join(str(shape.get(key, "")) for key in keys) + " |")
    return "\n".join(lines)


def shape_inline(shape: dict[str, int]) -> str:
    return ",".join(f"{key}={value}" for key, value in shape.items())


def render_template(template: str, values: dict[str, str]) -> str:
    rendered = template
    for key, value in values.items():
        rendered = rendered.replace("{{ " + key + " }}", value)
    return rendered


def display_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def sample_section(samples: list[str]) -> str:
    blocks: list[str] = []
    for idx, sample in enumerate(samples, start=1):
        label = chr(ord("A") + idx - 1)
        blocks.append(
            "\n".join(
                [
                    f"### 样本 {label}",
                    "",
                    "路径：",
                    f"`{sample}`",
                    "",
                    "用途：",
                    f"- {sample_purpose(sample)}",
                ]
            )
        )
    return "\n\n".join(blocks)


def sample_purpose(sample: str) -> str:
    path = sample.lower()
    suffix = Path(sample).suffix.lower()
    if suffix == ".hpp":
        purpose = "学习主实现路径、ACE 主循环、tile / LDM / writeback 细节。"
    elif suffix == ".swcu":
        purpose = "学习 kernel 入口、runtime 调用顺序、参数绑定、dispatch 条件和 workspace 约束。"
    else:
        purpose = "学习实现模式、shape 约束和运行边界。"

    hints: list[str] = []
    if "smallk" in path or "small-k" in path:
        hints.append("同时确认 small-K 阈值和适用边界。")
    if "gemm" in path or "hgemm" in path or "gemmex" in path:
        hints.append("重点抽取 GEMM/ACE 相关模式。")
    if "32x" in path:
        hints.append("关注 32X 粒度下的分块、分核和 writeback 规则。")

    if hints:
        return purpose + " " + " ".join(hints)
    return purpose


def infer_profile(topic: str, op_kind: str, samples: list[str]) -> str:
    haystack = " ".join([topic, op_kind, *samples]).lower()
    for key in ("gemm", "gemmex", "hgemm", "matmul"):
        if key in haystack:
            return PROFILE_ALIASES.get(key, key)
    return "generic"


def shape_hints(topic: str, target_shape: dict[str, int], profile: str) -> list[str]:
    hints: list[str] = []
    topic_l = topic.lower()
    if profile == "gemm":
        missing = {"M", "N", "K"} - target_shape.keys()
        if missing:
            return [f"GEMM profile 缺少 shape key：{', '.join(sorted(missing))}。"]
        m, n, k = target_shape["M"], target_shape["N"], target_shape["K"]
        if "smallk" in topic_l or "small-k" in topic_l:
            hints.append("本任务 topic 标记为 smallK：必须确认样本的 small-K 判定阈值，以及目标 K 是否真的落在该实现适用范围。")
        if k >= 4096:
            hints.append("目标 K 较大：重点确认 K loop、ACE 累加次数、LDM 双缓冲和是否需要 splitK/workspace。")
        if m >= 1024 and n >= 1024:
            hints.append("目标 M/N 较大：重点确认 M/N 分核策略、tile 覆盖顺序和 C 写回带宽是否成为瓶颈。")
    return hints


def focus_section(profile: str, topic: str, target_shape: dict[str, int], extra_focus: list[str]) -> str:
    stages = FOCUS_PROFILES[profile]
    blocks: list[str] = []
    for title, validation, questions in stages:
        block = [f"### {title}", "", f"验证方式：`{validation}`", "", "必须回答："]
        block.extend(f"- {item}" for item in questions)
        blocks.append("\n".join(block))

    hints = shape_hints(topic, target_shape, profile)
    if hints or extra_focus:
        block = ["### 本任务追加关注点", "", "必须回答："]
        block.extend(f"- {item}" for item in hints)
        block.extend(f"- {item}" for item in extra_focus)
        blocks.append("\n".join(block))

    return "\n\n".join(blocks)


def report_items(profile: str, has_baseline: bool) -> str:
    common = [
        "样本清单",
        "可迁移模式",
        "Shape / dtype / layout 约束",
        "Dispatch / Tune 条件",
    ]
    if profile == "gemm":
        common.extend(
            [
                "ACE 计算模式",
                "A/B/C 访存与 LDM 布局",
                "GEMM 流水排布",
                "双缓冲",
                "SplitK / Workspace",
            ]
        )
    else:
        common.extend(
            [
                "执行组织与并行维度",
                "访存路径与 buffer ownership",
                "同步点和资源生命周期",
                "性能相关但非正确性必需的优化",
            ]
        )
    if has_baseline:
        common.append("参考实现基线结果")
    common.extend(["不可迁移细节", "验证计划", "失败记录与规则更新"])
    return "\n".join(f"- {item}" for item in common)


def baseline_section(
    has_baseline: bool,
    dtype: str,
    baseline_shapes: list[dict[str, int]],
) -> str:
    if not has_baseline:
        return "\n".join(
            [
                "是否需要性能基线：no",
                "",
                "本任务不要求性能基线；若人工审核后认为需要，再补充 shape 并实测。",
            ]
        )

    return "\n".join(
        [
            "是否需要性能基线：yes",
            "",
            "记录：",
            "",
            f"- dtype：`{dtype}`",
            "- shapes：",
            baseline_shapes_table(baseline_shapes),
            "- kernel name",
            "- HW time",
            "- TFLOPS",
            "- 是否命中目标样本实现或 tune record",
            "",
            "baseline 只用于确认样本适用边界和性能基线；最终迁移能力仍以新算子的验证结果为准。",
        ]
    )


def followup_shape_section(profile: str, smoke_shape: dict[str, int], mid_shape: dict[str, int]) -> str:
    if profile == "gemm":
        return "\n".join(
            [
                "### Smoke 候选",
                "",
                f"- shape：{shape_inline(smoke_shape)}",
                "- 用途：target 实现分析完成后，只验证 ACE micro path 和最小 writeback。",
                "",
                "### Mid 候选",
                "",
                f"- shape：{shape_inline(mid_shape)}",
                "- 用途：target 实现分析完成后，验证至少一个 target 关注点，例如多 tile、分核或 larger-K。",
            ]
        )

    return "\n".join(
        [
            "### Smoke 候选",
            "",
            f"- shape：{shape_inline(smoke_shape)}",
            "- 用途：target 实现分析完成后，只验证最小正确性路径。",
            "",
            "### Mid 候选",
            "",
            f"- shape：{shape_inline(mid_shape)}",
            "- 用途：target 实现分析完成后，验证至少一个相关关注点。",
        ]
    )


def preflight_section(
    profile: str,
    has_baseline: bool,
    target_shape: dict[str, int],
) -> str:
    if not has_baseline:
        return "\n".join(
            [
                "当前不要求性能基线。",
                "",
                "- `optimize_existing`：以目标算子已通过的 baseline stage 为准。",
                "- `transfer_new_op`：若样本存在 dispatch/tune 分支，先确认 target shape 命中目标实现。",
                f"- target shape：{shape_inline(target_shape)}。",
                "- 只有 target 可以作为最终证明；smoke/mid 只用于降低调试成本。",
            ]
        )

    lines = [
        "目的：先确认真实分支，再决定后续 smoke/mid shape 是否合理。",
        "",
        "预检要求：",
        "- 用 target shape 测试。",
        "- 记录 target shape 命中的 kernel name、dispatch 分支、tune record、HW time 和 TFLOPS。",
        "- 若 target shape 没有命中目标样本实现，先修正样本选择、topic 或 target shape，不要继续写验证算子。",
        "",
        "target shape 校准表：",
        "",
        "| 用途 | shape | 实测 kernel/分支 | 是否保留 | 调整原因 |",
        "|------|-------|--------------------------|----------|----------|",
        f"| target | {shape_inline(target_shape)} | TODO | TODO | TODO |",
        "",
        "shape 合理性判断：",
        "- target 必须命中与样本一致或等价的 kernel/dispatch 分支。",
        "- target 需要覆盖该实现的真实 tile、K loop、tail、splitK/workspace 或流水路径。",
        "- 只有 target 可以作为最终迁移能力证明。",
    ]
    if profile == "gemm":
        lines.extend(
            [
                "",
                "GEMM 特别检查：",
                "- 先只读 target 对应实现，确认 small-K 阈值、分块/分核策略和流水模式。",
                "- smoke/mid shape 只在 target 分析完成后再设计。",
            ]
        )
    return "\n".join(lines)


def validation_plan(
    profile: str,
    smoke_op: str,
    smoke_shape: dict[str, int],
    mid_op: str,
    mid_shape: dict[str, int],
    target_op: str,
    target_shape: dict[str, int],
    has_baseline: bool,
    backend_profile: dict,
) -> str:
    if profile == "gemm":
        target_goals = [
            "验证目标 shape。",
            "先只读 target 实现代码，拆出关注点和 shape 约束。",
            "复核真实 K loop 累加次数、Lastflag 条件和 C 最终写回路径。",
            "如果需要，验证 SplitK / workspace / 中间结果写 HBM。",
        ]
        smoke_goals = [
            "在 target 实现分析完成后，再设计最小正确性 shape。",
            "只验证 ACE micro path 和基础 writeback。",
            "不证明完整分块、分核或流水策略。",
        ]
        mid_goals = [
            "在 target 实现分析完成后，再设计中间 shape。",
            "验证至少一个 target 关注点，例如多 tile、分核或 larger-K。",
            "不替代 target 作为最终证明。",
        ]
    else:
        target_goals = [
            "验证目标 shape。",
            "先确认 target 命中的真实实现，再反推 smoke/mid 关注点。",
            "记录实际 device time 和主要瓶颈。",
        ]
        smoke_goals = [
            "在 target 实现分析完成后，再设计最小正确性 shape。",
            "只验证基础路径。",
            "不证明完整并行策略。",
        ]
        mid_goals = [
            "在 target 实现分析完成后，再设计中间 shape。",
            "验证至少一个相关关注点。",
            "不替代 target 作为最终证明。",
        ]

    if has_baseline:
        target_goals.append("与基线对比。")

    def stage(
        title: str,
        validation: str,
        op: str,
        shape: dict[str, int],
        goals: list[str],
        pass_items: list[str],
    ) -> str:
        lines = [
            f"### {title}",
            "",
            f"验证方式：`{validation}`",
            "",
            "算子名：",
            f"`{op}`",
            "",
            "形状：",
            shape_block(shape),
            "",
            "目标：",
        ]
        lines.extend(f"- {goal}" for goal in goals)
        lines.extend(["", "通过标准："])
        lines.extend(f"- {item}" for item in pass_items)
        return "\n".join(lines)

    stages = [
        stage(
            "Stage 1：Smoke",
            "smoke_covered",
            smoke_op,
            smoke_shape,
            smoke_goals,
            backend_profile["acceptance_text"]["smoke"],
        ),
        stage(
            "Stage 2：Mid",
            "staged_validation",
            mid_op,
            mid_shape,
            mid_goals,
            backend_profile["acceptance_text"]["mid"],
        ),
        stage(
            "Stage 3：Target",
            "staged_validation",
            target_op,
            target_shape,
            target_goals,
            backend_profile["acceptance_text"]["target"],
        ),
    ]
    return "\n\n".join(stages)


def coverage_matrix(profile: str) -> str:
    if profile == "gemm":
        rows = [
            ("适用边界 / dispatch / tune record", "参考实现 preflight + documented_only", "target", "必须先确认真实命中分支"),
            ("ACE north/west load 和基础 writeback", "smoke_covered", "target-first 后设计 smoke", "只证明 ACE micro path"),
            ("ACE flags 基本取值", "partial_smoke", "target-first 后设计 smoke/mid", "Lastflag/多次 Accum 必须 target 复核"),
            ("M/N tiling 和 SPE grid 映射", "staged_validation", "target-first 后设计 mid", "smoke 不覆盖完整分核"),
            ("K loop 大循环和累加次数", "staged_validation", "target", "K 较大时必须 target 或 larger-K"),
            ("LDM layout 和 buffer ownership", "smoke_covered + staged_validation", "target-first 后设计 smoke/mid", "smoke 定 layout，mid 验证复用"),
            ("双缓冲和 steady pipeline", "staged_validation", "target-first 后设计 mid", "需要多 tile/多 K step"),
            ("SplitK / workspace / partial C", "staged_validation 或 documented_not_required", "target", "先由 target preflight 判断是否需要"),
            ("ACE 结果是否中途写 HBM", "staged_validation", "target", "需要结合样本实现和运行分支确认"),
            ("性能策略和吞吐", "benchmark", "target", "以 kernel-bench 和可选参考 baseline 对比"),
        ]
    else:
        rows = [
            ("适用边界 / dispatch", "参考实现 preflight 或 documented_only", "target", "先确认真实分支"),
            ("最小正确性路径", "smoke_covered", "target-first 后设计 smoke", "只证明基础链路"),
            ("并行维度和 tile 拆分", "staged_validation", "target-first 后设计 mid", "需要多 tile/多核 shape"),
            ("访存路径和 buffer ownership", "smoke_covered + staged_validation", "target-first 后设计 smoke/mid", "先定路径再验证复用"),
            ("同步点和资源生命周期", "staged_validation", "target-first 后设计 mid", "跨 tile/跨核时复核"),
            ("性能策略", "benchmark", "target", "只用 target 证明"),
        ]

    lines = [
        "| 关注点 | 覆盖方式 | 覆盖 shape/stage | 审核结论 |",
        "|--------|----------|-------------------|----------|",
    ]
    for focus, method, stage, note in rows:
        lines.append(f"| {focus} | {method} | {stage} | TODO：{note} |")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Initialize an SDAA learning-validation task")
    parser.add_argument("--topic", required=True, help="Topic path, e.g. gemm/pvc-smallk-fp16-fp32")
    parser.add_argument(
        "--mode",
        default="transfer_new_op",
        choices=["optimize_existing", "transfer_new_op"],
        help="Workflow mode",
    )
    parser.add_argument("--sample", action="append", default=[], help="Read-only sample path")
    parser.add_argument("--op-kind", default="", help="operator kind for baseline")
    parser.add_argument("--profile", default="auto", choices=["auto", *sorted(FOCUS_PROFILES)], help="Focus profile")
    parser.add_argument("--focus", action="append", default=[], help="Extra task-specific focus item")
    parser.add_argument("--dtype", required=True, help='DType description, e.g. "A/B=fp16,C=fp32"')
    parser.add_argument("--target-shape", required=True, help="Target shape as M,N,K or arbitrary key=value list")
    parser.add_argument("--baseline-shape", action="append", default=[], help="baseline shape")
    parser.add_argument("--baseline", action="store_true", help="Request baseline testing")
    parser.add_argument(
        "--smoke-shape",
        default="",
        help="Smoke validation shape; defaults to a GEMM candidate or target shape",
    )
    parser.add_argument(
        "--mid-shape",
        default="",
        help="Mid validation shape; defaults to a GEMM candidate or target shape",
    )
    parser.add_argument("--target-op", required=True, help="Target validation op name")
    parser.add_argument("--smoke-op", default="", help="Smoke op name")
    parser.add_argument("--mid-op", default="", help="Mid op name")
    parser.add_argument(
        "--backend",
        default=backend_profiles.DEFAULT_BACKEND,
        choices=sorted(backend_profiles.BACKENDS),
        help="Backend profile for validation criteria and API vocabulary",
    )
    parser.add_argument(
        "--demo-root",
        default="",
        help="Demo root directory (defaults to backend profile's default_demo_root)",
    )
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    try:
        topic_path = topic_to_path(args.topic)
        if args.mode == "transfer_new_op" and len(args.sample) < 2:
            raise ValueError("transfer_new_op requires at least two --sample inputs")
        validate_op_name(args.target_op)
        if args.mode == "optimize_existing":
            smoke_op = args.smoke_op or args.target_op
            mid_op = args.mid_op or args.target_op
        else:
            smoke_op = args.smoke_op or f"{args.target_op}_smoke"
            mid_op = args.mid_op or f"{args.target_op}_mid"
        validate_op_name(smoke_op)
        validate_op_name(mid_op)

        target_shape = parse_shape(args.target_shape)
        focus_profile = infer_profile(args.topic, args.op_kind, args.sample) if args.profile == "auto" else args.profile
        if focus_profile == "gemm" and not {"M", "N", "K"} <= target_shape.keys():
            missing = ", ".join(sorted({"M", "N", "K"} - target_shape.keys()))
            raise ValueError(f"GEMM profile requires shape keys M,N,K; missing: {missing}")
        smoke_shape = (
            parse_shape(args.smoke_shape)
            if args.smoke_shape
            else default_stage_shape(focus_profile, target_shape, "smoke")
        )
        mid_shape = (
            parse_shape(args.mid_shape)
            if args.mid_shape
            else default_stage_shape(focus_profile, target_shape, "mid")
        )
        baseline_requested = args.baseline or bool(args.baseline_shape)
        if baseline_requested and not args.op_kind:
            raise ValueError("baseline requires --op-kind")
        baseline_shapes = [parse_shape(item) for item in args.baseline_shape] if baseline_requested else []
        if not baseline_shapes and baseline_requested:
            baseline_shapes = [target_shape]
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    try:
        backend_profile = backend_profiles.get_backend(
            args.backend,
            demo_root_override=args.demo_root,
        )
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    demo_root_str = backend_profile["default_demo_root"]
    demo_root = Path(demo_root_str).expanduser().resolve()
    task_dir = demo_root / "op_learning" / topic_path
    task_path = task_dir / "learning_task.md"
    learning_report_path = demo_root / "op_learning" / topic_path / "learned_patterns.md"
    promotion_path = SKILL_DIR / "references" / "learned-patterns" / topic_path.with_suffix(".md")

    if not TEMPLATE_PATH.is_file():
        print(f"error: missing template: {TEMPLATE_PATH}", file=sys.stderr)
        return 1
    if task_path.exists() and not args.force and not args.dry_run:
        print(f"error: task exists: {task_path} (use --force)", file=sys.stderr)
        return 1

    template = TEMPLATE_PATH.read_text(encoding="utf-8")
    content = render_template(
        template,
        {
            "topic": args.topic,
            "workflow_mode": args.mode,
            "samples_section": sample_section(args.sample),
            "focus_profile": focus_profile,
            "focus_section": focus_section(focus_profile, args.topic, target_shape, args.focus),
            "preflight_section": preflight_section(
                focus_profile,
                bool(baseline_shapes),
                target_shape,
            ),
            "followup_shape_section": followup_shape_section(
                focus_profile,
                smoke_shape,
                mid_shape,
            ),
            "baseline_section": baseline_section(bool(baseline_shapes), args.dtype, baseline_shapes),
            "learning_report_path": display_path(learning_report_path),
            "report_items": report_items(focus_profile, bool(baseline_shapes)),
            "validation_plan": validation_plan(
                focus_profile,
                smoke_op,
                smoke_shape,
                mid_op,
                mid_shape,
                args.target_op,
                target_shape,
                bool(baseline_shapes),
                backend_profile,
            ),
            "coverage_matrix": coverage_matrix(focus_profile),
            "promotion_path": display_path(promotion_path),
        },
    )

    if args.dry_run:
        print(content)
        return 0

    task_dir.mkdir(parents=True, exist_ok=True)
    task_path.write_text(content, encoding="utf-8")
    print(f"wrote {task_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
