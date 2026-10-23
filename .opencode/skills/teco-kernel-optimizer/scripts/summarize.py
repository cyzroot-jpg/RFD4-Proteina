#!/usr/bin/env python3
"""Render run_dir/summary.md from state.json + per-iteration artifacts.

Includes timeline, attribution results, and method effectiveness.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path


def _read(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _fmt_ms(v) -> str:
    return f"{v:.4f} ms" if v is not None else "—"


def _fmt_speedup(v) -> str:
    return f"{v:.2f}×" if v is not None else "—"


def _method_bullets(methods: list[dict]) -> str:
    if not methods:
        return "_(none)_"
    lines = []
    for m in methods:
        axis = m.get("axis", "?")
        name = m.get("name", m.get("id", "?"))
        extra = ""
        if "iter" in m:
            extra = f" _(iter {m['iter']})_"
        if "attribution_ms" in m and m["attribution_ms"] is not None:
            extra += f" — attribution +{m['attribution_ms']:.3f}ms"
        if "speedup_vs_best_before" in m and m["speedup_vs_best_before"] is not None:
            extra += f" — speedup {m['speedup_vs_best_before']:.2f}×"
        if "note" in m:
            extra += f" [{m['note']}]"
        lines.append(f"- **[{axis}]** {name}{extra}")
    return "\n".join(lines)


def _timeline_table(state: dict) -> str:
    rows = [
        "| Iter | Status | Methods | ms | Speedup vs prev best | Speedup vs ref |",
        "|------|--------|---------|----|----------------------|----------------|",
    ]
    for h in state.get("history", []):
        raw_methods = [str(x) for x in (h.get("methods") or []) if x is not None]
        raw_method_names = [str(x) for x in (h.get("method_names") or []) if x is not None]
        methods = ", ".join(raw_methods or raw_method_names)
        rows.append(
            f"| {h['iter']} "
            f"| {h['status']} "
            f"| {methods} "
            f"| {_fmt_ms(h.get('ms'))} "
            f"| {_fmt_speedup(h.get('speedup_vs_best_before'))} "
            f"| {_fmt_speedup(h.get('speedup_vs_ref'))} |"
        )
    return "\n".join(rows)


def render(state_path: str, out_path: str) -> None:
    state = _read(state_path)
    run_dir = state["run_dir"]

    baseline_bench_path = os.path.join(run_dir, "baseline", "bench.json")
    baseline_ms = None
    if os.path.isfile(baseline_bench_path):
        b = _read(baseline_bench_path)
        baseline_ms = (b.get("kernel") or {}).get("average_ms")

    best_ms = state.get("best_metric_ms")
    final_speedup = (baseline_ms / best_ms) if (baseline_ms and best_ms and best_ms > 0) else None

    env = state.get("env", {})
    device_name = env.get("primary_device") or "—"
    devices = env.get("sdaa_devices") or []

    lines = []
    lines.append("# SDAA Kernel Optimization Summary (teco-ops)")
    lines.append("")
    lines.append(f"- **Run dir**: `{run_dir}`")
    lines.append(f"- **Baseline tree**: `{state.get('baseline_tree')}`")
    lines.append(f"- **Working tree**: `{state.get('tree')}`")
    target = state.get("target_kernel")
    lines.append(
        f"- **Op**: `{state.get('op')}`  **Target kernel**: `{target}`  "
        f"**Case**: `{state.get('case_path')}`"
    )
    lines.append(f"- **Iterations**: {len(state.get('history', []))} / {state.get('iterations_total')}")
    lines.append(f"- **Branches per iter**: {state.get('branches', 4)}")
    lines.append("")

    lines.append("## Environment")
    lines.append("")
    lines.append(f"- SDAA device: **{device_name}**")
    if devices:
        d = devices[0]
        if d.get("total_memory_mb") is not None:
            lines.append(f"- Device memory: {d['total_memory_mb']} MB")
        if d.get("source"):
            lines.append(f"- Probe source: `{d['source']}`")
    lines.append(f"- tecocc: `{env.get('tecocc',{}).get('version','—')}`")
    runtime = env.get("runtime", {})
    lines.append(f"- torch: `{runtime.get('torch','—')}` / torch_sdaa: `{runtime.get('torch_sdaa','—')}`")
    lines.append("")

    lines.append("## Headline")
    lines.append("")
    lines.append(f"- **Baseline time**: {_fmt_ms(baseline_ms)}")
    lines.append(f"- **Best time**: {_fmt_ms(best_ms)}")
    lines.append(f"- **Overall speedup vs baseline**: {_fmt_speedup(final_speedup)}")
    lines.append(f"- **Best kernel (relpath in working tree)**: `{state.get('best_file')}`")
    lines.append("")

    lines.append("## Iteration Timeline")
    lines.append("")
    lines.append(_timeline_table(state))
    lines.append("")

    lines.append("## Effective Methods (attribution-verified)")
    lines.append("")
    lines.append(_method_bullets(state.get("effective_methods", [])))
    lines.append("")

    lines.append("## Ineffective Methods")
    lines.append("")
    lines.append(_method_bullets(state.get("ineffective_methods", [])))
    lines.append("")

    lines.append("## Implementation-Failed Methods (correctness/compile failed)")
    lines.append("")
    lines.append(_method_bullets(state.get("implementation_failed_methods", [])))
    lines.append("")

    lines.append("## All Methods Tried")
    lines.append("")
    lines.append(_method_bullets(state.get("selected_methods", [])))
    lines.append("")

    if state.get("frontier"):
        lines.append("## Frontier (unexplored branch candidates)")
        lines.append("")
        for fe in state["frontier"][:20]:
            lines.append(
                f"- iter {fe.get('iter')} branch {fe.get('branch_index')}: "
                f"{_fmt_ms(fe.get('ms'))} "
                f"(+{fe.get('delta_from_champion', '?')}ms from champion)"
            )
        lines.append("")

    lines.append("## Retrospective")
    lines.append("")
    lines.append("_Claude will fill this section in:_")
    lines.append("")
    lines.append("- Which optimizations moved the needle and why (tie to attribution evidence).")
    lines.append("- Which ones were no-ops or regressions, and plausible reasons.")
    lines.append("- How timings and per-method attribution shifted across iterations.")
    lines.append("- Next steps if the user wants more iterations.")
    lines.append("")

    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(json.dumps({"summary": out_path}, indent=2))


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--state", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()
    render(args.state, args.out)


if __name__ == "__main__":
    main()
