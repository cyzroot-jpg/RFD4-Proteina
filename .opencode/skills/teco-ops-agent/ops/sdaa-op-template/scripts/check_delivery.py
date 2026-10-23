#!/usr/bin/env python3
"""Check whether an operator has completed the mandatory delivery pipeline."""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
DEFAULT_DEMO_ROOT = REPO_ROOT / "swdnn_test_ops"
DESIGN_SCRIPT_DIR = REPO_ROOT / "ops" / "sdaa-op-design" / "scripts"
KERNEL_BENCH_SCRIPT = REPO_ROOT / "ops" / "kernel-bench" / "scripts" / "bench_kernel.py"

sys.path.insert(0, str(DESIGN_SCRIPT_DIR))
from op_design_lib import (  # noqa: E402
    design_paths,
    list_incomplete_fields,
    normalize_design,
    validate_design,
)

TODO_RE = re.compile(r"\bTODO\b", re.IGNORECASE)
SUCCESS_RE = re.compile(r"success rate ([0-9.]+)")
RMA_ASYNC_RE = re.compile(r"\brt_rma_i(?:put|get)\s*\(")
VOLATILE_INT_RE = re.compile(r"\bvolatile\s+int\s+([A-Za-z_][A-Za-z0-9_]*)\b")
FORBIDDEN_TOKEN_RE = re.compile(r"\bACE_PREC\b")


def _swcu_path(demo_root: Path, op: str) -> Path:
    return demo_root / "src" / op / f"{op}.swcu"


def _find_call_args(text: str, func_name: str) -> list[list[str]]:
    calls: list[list[str]] = []
    needle = f"{func_name}("
    pos = 0
    while True:
        start = text.find(needle, pos)
        if start < 0:
            break
        arg_start = start + len(needle)
        depth = 1
        i = arg_start
        while i < len(text) and depth > 0:
            if text[i] == "(":
                depth += 1
            elif text[i] == ")":
                depth -= 1
            i += 1
        if depth != 0:
            break
        calls.append(_split_args(text[arg_start:i - 1]))
        pos = i
    return calls


def _split_args(arg_text: str) -> list[str]:
    args: list[str] = []
    depth = 0
    start = 0
    for i, ch in enumerate(arg_text):
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif ch == "," and depth == 0:
            args.append(arg_text[start:i].strip())
            start = i + 1
    tail = arg_text[start:].strip()
    if tail:
        args.append(tail)
    return args


def _normalize_expr(expr: str) -> str:
    expr = re.sub(r"\s+", "", expr)
    expr = expr.replace("(void*)", "")
    return expr


def check_rma_safety(text: str) -> dict:
    if not RMA_ASYNC_RE.search(text):
        return {
            "pass": True,
            "uses_async_rma": False,
            "errors": [],
        }

    errors: list[str] = []
    if "__rt_local_rply" not in text:
        errors.append("async RMA requires __rt_local_rply for local reply")
    if "__rt_remote_rply" not in text:
        errors.append("async RMA requires __rt_remote_rply for remote reply")

    reply_names = {
        name
        for name in VOLATILE_INT_RE.findall(text)
        if name not in {"__rt_local_rply", "__rt_remote_rply"}
    }
    iput_calls = _find_call_args(text, "rt_rma_iput")
    iget_calls = _find_call_args(text, "rt_rma_iget")
    for idx, args in enumerate(iput_calls, start=1):
        if len(args) >= 6:
            local_reply = args[1]
            remote_reply = args[5]
            for name in reply_names:
                if f"&{name}" in local_reply or f"&{name}" in remote_reply:
                    errors.append(
                        f"rt_rma_iput call {idx} uses local volatile int '{name}' as reply"
                    )
        else:
            errors.append(f"rt_rma_iput call {idx} has unexpected argument count")

    for idx, args in enumerate(iget_calls, start=1):
        if len(args) >= 6:
            local_reply = args[1]
            remote_reply = args[5]
            for name in reply_names:
                if f"&{name}" in local_reply or f"&{name}" in remote_reply:
                    errors.append(
                        f"rt_rma_iget call {idx} uses local volatile int '{name}' as reply"
                    )
        else:
            errors.append(f"rt_rma_iget call {idx} has unexpected argument count")

    pending_dsts: list[str] = []
    pos = 0
    while pos < len(text):
        wait_pos = text.find("rt_rma_wait_value", pos)
        put_pos = text.find("rt_rma_iput", pos)
        if wait_pos < 0 and put_pos < 0:
            break
        if wait_pos >= 0 and (put_pos < 0 or wait_pos < put_pos):
            pending_dsts.clear()
            pos = wait_pos + len("rt_rma_wait_value")
            continue
        call_args = _find_call_args(text[put_pos:], "rt_rma_iput")
        if not call_args:
            break
        args = call_args[0]
        if len(args) >= 5:
            dst = _normalize_expr(args[4])
            if dst in pending_dsts:
                errors.append(
                    "multiple pending rt_rma_iput calls write to the same destination buffer"
                )
                pending_dsts.clear()
            else:
                pending_dsts.append(dst)
        pos = put_pos + len("rt_rma_iput")

    return {
        "pass": not errors,
        "uses_async_rma": True,
        "errors": errors,
        "iput_count": len(iput_calls),
        "iget_count": len(iget_calls),
        "reference": "ops/sdaa-op-template/references/rma-safety-rules.md",
    }


def check_design_impl_consistency(design_doc: dict, swcu_text: str) -> dict:
    """Verify the kernel implementation matches the design dataflow.

    Extracts expected API tokens from design.json (kernel_apis, dataflow,
    double_buffer) and checks their presence in the .swcu source.  This
    catches the common failure mode where the design specifies an ACE or
    RMA dataflow but the kernel was silently implemented with plain SIMD /
    blocking DMA instead.
    """
    errors: list[str] = []
    expected: list[dict] = []

    op_def = design_doc.get("operator_definition", {})
    kernel_apis = op_def.get("kernel_apis", [])
    api_token_map = {
        "rt_ace": "rt_ace_",
        "rt_dma_iget": "rt_dma_iget",
        "rt_dma_iput": "rt_dma_iput",
        "rt_rma": "rt_rma_",
    }
    for api_text in kernel_apis:
        api_lower = api_text.lower()
        for label, token in api_token_map.items():
            if label in api_lower and token not in swcu_text:
                expected.append({"token": token, "source": f"kernel_apis: {api_text}"})
                errors.append(
                    f"design kernel_apis expects '{token}' but it is absent from swcu"
                )

    pipeline = design_doc.get("pipeline_layout", {})
    dataflow = pipeline.get("dataflow_description", "")
    if "RMA" in dataflow and "rt_rma_" not in swcu_text:
        errors.append(
            f"design dataflow '{dataflow}' requires rt_rma_* but none found in swcu"
        )
    if "ACE" in dataflow and "rt_ace_" not in swcu_text:
        errors.append(
            f"design dataflow '{dataflow}' requires rt_ace_* but none found in swcu"
        )

    dbuf = design_doc.get("double_buffer_strategy", {})
    if dbuf.get("enabled") or dbuf.get("buffer_depth", 0) >= 2:
        bufs = [b.get("name", "") for b in dbuf.get("buffers", []) if b.get("name")]
        if bufs and not any(b in swcu_text for b in bufs):
            errors.append(
                f"design double_buffer_strategy expects buffers {bufs} but none found in swcu"
            )

    return {
        "pass": len(errors) == 0,
        "expected_tokens": expected,
        "errors": errors,
    }


SIMD_VEC_RE = re.compile(r"\bsimd_(?:load|store|vfcvths|vfmas|vfmul|vfadd)\b")
UNROLL_SUFFIX_RE = re.compile(r"\b[a-z]+_[0-7]\b")


def check_simd_unroll(swcu_text: str) -> dict:
    """Warn when a __device__ SIMD loop lacks 8x-unroll / software-pipeline
    indicators.

    This is a *soft* check (warnings, not hard fail) because precise
    dual-issue structure cannot be reliably determined from text alone.
    It flags the clearest violation: a __device__ function that calls SIMD
    vector ops inside a loop but shows no evidence of >=8x unrolling (no
    _0.._7 suffix vectors) and no software-pipeline pattern.
    """
    warnings: list[str] = []
    # Split into __device__ function bodies (heuristic: brace counting)
    dev_starts = [m.start() for m in re.finditer(r"__device__", swcu_text)]
    for ds in dev_starts:
        brace_open = swcu_text.find("{", ds)
        if brace_open < 0:
            continue
        depth = 0
        end = brace_open
        for i in range(brace_open, len(swcu_text)):
            if swcu_text[i] == "{":
                depth += 1
            elif swcu_text[i] == "}":
                depth -= 1
                if depth == 0:
                    end = i
                    break
        body = swcu_text[brace_open:end]
        has_simd = bool(SIMD_VEC_RE.search(body))
        has_loop = bool(re.search(r"\bfor\s*\(", body))
        has_unroll = bool(UNROLL_SUFFIX_RE.search(body))
        if has_simd and has_loop and not has_unroll:
            warnings.append(
                "__device__ function with SIMD vector ops in a loop shows no "
                "8x-unroll indicators (no _0.._7 suffix); naive 1x loop is forbidden "
                "by sdaa-op-template SIMD rules"
            )
    return {
        "pass": len(warnings) == 0,
        "warnings": warnings,
        "is_hard_gate": False,
    }


def check_forbidden_tokens(swcu_text: str) -> dict:
    errors: list[str] = []
    if FORBIDDEN_TOKEN_RE.search(swcu_text):
        errors.append(
            "ACE_PREC must not appear in generated T1 .swcu code; "
            "rt_ace_writeback Precisionflag should be passed as integer 0 or 1"
        )
    return {
        "pass": len(errors) == 0,
        "errors": errors,
    }


def _parse_benchmark_json(text: str) -> dict | None:
    decoder = json.JSONDecoder()
    objects: list[dict] = []
    for idx, char in enumerate(text):
        if char != "{":
            continue
        try:
            value, _ = decoder.raw_decode(text[idx:])
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            objects.append(value)
    for value in reversed(objects):
        if "max_cycles" in value and ("time_us" in value or "time_ms" in value):
            return value
    return objects[-1] if objects else None


def run_kernel_bench(op: str, demo_root: Path, build_dir_name: str) -> dict:
    if not KERNEL_BENCH_SCRIPT.is_file():
        return {
            "pass": False,
            "skipped": True,
            "is_hard_gate": False,
            "error": f"missing script: {KERNEL_BENCH_SCRIPT}",
        }

    cmd = [
        sys.executable,
        str(KERNEL_BENCH_SCRIPT),
        "--op",
        op,
        "--demo-root",
        str(demo_root),
        "--build-dir",
        build_dir_name,
        "--json",
    ]
    try:
        proc = subprocess.run(
            cmd,
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            timeout=180,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        return {
            "pass": False,
            "skipped": False,
            "is_hard_gate": False,
            "command": cmd,
            "error": f"kernel-bench timed out after {exc.timeout}s",
        }

    output = (proc.stdout or "") + "\n" + (proc.stderr or "")
    parsed = _parse_benchmark_json(output)
    result = {
        "pass": proc.returncode == 0 and parsed is not None,
        "skipped": False,
        "is_hard_gate": False,
        "command": cmd,
        "returncode": proc.returncode,
    }
    if parsed is not None:
        result["metrics"] = parsed
    else:
        result["error"] = "no JSON metrics found in kernel-bench output"
        result["output_tail"] = output[-3000:]
    return result


def _is_hard_gate(step: dict) -> bool:
    detail = step.get("detail")
    if isinstance(detail, dict):
        return detail.get("is_hard_gate", True) is not False
    return True


def check_delivery(op: str, demo_root: Path, run_benchmark: bool = True) -> dict:
    steps: list[dict] = []
    paths = design_paths(demo_root, op)
    swcu = _swcu_path(demo_root, op)

    # Step: design exists
    design_ok = paths.json_path.is_file()
    steps.append({
        "step": "design_exists",
        "pass": design_ok,
        "detail": str(paths.json_path),
    })

    design_strict_ok = False
    incomplete: list[str] = []
    if design_ok:
        try:
            raw = json.loads(paths.json_path.read_text(encoding="utf-8"))
            doc = normalize_design(raw)
            schema_errs = validate_design(doc, strict=False)
            incomplete = list_incomplete_fields(doc)
            design_strict_ok = not schema_errs and not incomplete
            steps.append({
                "step": "design_strict_valid",
                "pass": design_strict_ok,
                "detail": {"schema_errors": schema_errs, "incomplete_count": len(incomplete)},
            })
        except (json.JSONDecodeError, ValueError) as exc:
            steps.append({"step": "design_strict_valid", "pass": False, "detail": str(exc)})

    # Step: scaffold (single .swcu)
    scaffold_ok = swcu.is_file()
    steps.append({
        "step": "scaffold_swcu",
        "pass": scaffold_ok,
        "detail": {"path": str(swcu), "exists": scaffold_ok},
    })

    # Step: kernel implemented (no TODO in swcu)
    kernel_ok = False
    todo_hits: list[str] = []
    if scaffold_ok:
        text = swcu.read_text(encoding="utf-8", errors="replace")
        todo_hits = TODO_RE.findall(text)
        kernel_ok = len(todo_hits) == 0
    steps.append({
        "step": "kernel_implemented",
        "pass": kernel_ok,
        "detail": {"swcu": str(swcu), "todo_count": len(todo_hits)},
    })

    rma_safety = {"pass": True, "uses_async_rma": False, "errors": []}
    if scaffold_ok:
        rma_safety = check_rma_safety(text)
    steps.append({
        "step": "rma_safety",
        "pass": bool(rma_safety["pass"]),
        "detail": rma_safety,
    })

    # Step: compile-safe API tokens (hard gate)
    forbidden_tokens = {"pass": True, "errors": []}
    if scaffold_ok:
        forbidden_tokens = check_forbidden_tokens(text)
    steps.append({
        "step": "forbidden_tokens",
        "pass": bool(forbidden_tokens["pass"]),
        "detail": forbidden_tokens,
    })

    # Step: design-impl consistency (hard gate)
    design_impl = {"pass": True, "errors": []}
    if scaffold_ok and design_ok:
        try:
            raw_doc = json.loads(paths.json_path.read_text(encoding="utf-8"))
            design_impl = check_design_impl_consistency(raw_doc, text)
        except (json.JSONDecodeError, ValueError) as exc:
            design_impl = {"pass": False, "errors": [f"cannot parse design.json: {exc}"]}
    steps.append({
        "step": "design_impl_consistency",
        "pass": bool(design_impl["pass"]),
        "detail": design_impl,
    })

    # Step: SIMD unroll (soft check / warning)
    simd_unroll = {"pass": True, "warnings": []}
    if scaffold_ok:
        simd_unroll = check_simd_unroll(text)
    steps.append({
        "step": "simd_unroll",
        "pass": bool(simd_unroll["pass"]),
        "detail": simd_unroll,
    })

    # Step: build artifact
    build_dirs = sorted(demo_root.glob(f"build_{op}")) + sorted(demo_root.glob("build"))
    lib_built = any((d / "libswdnn_test.so").is_file() for d in build_dirs)
    steps.append({
        "step": "lib_built",
        "pass": lib_built,
        "detail": "run torch_verify for authoritative build result",
    })

    # Step: L3 verify (check for success_rate log file or parse build output)
    l3_pass = False
    success_rate = None
    # Check for verify result file written by torch_verify.py
    for build_dir in build_dirs:
        result_file = build_dir / "verify_result.json"
        if result_file.is_file():
            try:
                result = json.loads(result_file.read_text(encoding="utf-8"))
                success_rate = result.get("success_rate")
                l3_pass = success_rate == 1.0
                break
            except (json.JSONDecodeError, KeyError):
                pass
    steps.append({
        "step": "l3_verify",
        "pass": l3_pass,
        "detail": {
            "success_rate": success_rate,
            "hint": f"python3 {SCRIPT_DIR / 'torch_verify.py'} --op {op} "
                    f"--scope-cmake --restore-cmake --json",
        },
    })

    # simd_unroll is advisory (is_hard_gate=False): reported but does not
    # block delivery_status, to avoid false-positives from text heuristics.
    mandatory_pass = (
        design_strict_ok and scaffold_ok and kernel_ok and
        bool(rma_safety["pass"]) and bool(forbidden_tokens["pass"]) and
        bool(design_impl["pass"]) and l3_pass
    )
    performance_benchmark = None
    if mandatory_pass and run_benchmark:
        performance_benchmark = run_kernel_bench(op, demo_root, f"build_{op}")
        steps.append({
            "step": "kernel_bench",
            "pass": bool(performance_benchmark["pass"]),
            "detail": performance_benchmark,
        })
    elif run_benchmark:
        performance_benchmark = {
            "pass": False,
            "skipped": True,
            "is_hard_gate": False,
            "reason": "delivery_status is not pass",
        }
        steps.append({
            "step": "kernel_bench",
            "pass": False,
            "detail": performance_benchmark,
        })

    return {
        "op": op,
        "delivery_status": "pass" if mandatory_pass else "incomplete",
        "performance_benchmark": performance_benchmark,
        "steps": steps,
        "incomplete_fields": incomplete,
        "blocking": [
            s["step"]
            for s in steps
            if not s["pass"] and _is_hard_gate(s)
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Check mandatory operator delivery pipeline")
    parser.add_argument("--op", required=True)
    parser.add_argument("--demo-root", default=str(DEFAULT_DEMO_ROOT))
    parser.add_argument(
        "--no-benchmark",
        action="store_true",
        help="Do not run kernel-bench after delivery_status passes",
    )
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    demo_root = Path(args.demo_root).expanduser().resolve()
    report = check_delivery(args.op, demo_root, run_benchmark=not args.no_benchmark)

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(f"delivery: {report['delivery_status']} (op={args.op})")
        for step in report["steps"]:
            mark = "OK" if step["pass"] else "FAIL"
            print(f"  [{mark}] {step['step']}: {step['detail']}")
        bench = report.get("performance_benchmark") or {}
        metrics = bench.get("metrics") or {}
        if metrics:
            print(
                "benchmark: "
                f"time_us={metrics.get('time_us')}, "
                f"time_ms={metrics.get('time_ms')}, "
                f"max_cycles={metrics.get('max_cycles')}"
            )
        if report["blocking"]:
            print("blocking:", ", ".join(report["blocking"]))

    return 0 if report["delivery_status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
