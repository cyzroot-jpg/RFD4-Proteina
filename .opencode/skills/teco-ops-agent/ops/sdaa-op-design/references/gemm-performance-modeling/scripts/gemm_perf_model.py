#!/usr/bin/env python3
"""Parameterized GEMM theoretical performance model for SDAA/TECO ACE kernels."""

from __future__ import annotations

import argparse
import math
from dataclasses import dataclass


DTYPE_BYTES = {
    "fp16": 2,
    "bf16": 2,
    "half": 2,
    "float16": 2,
    "fp32": 4,
    "float": 4,
    "float32": 4,
    "int8": 1,
    "uint8": 1,
    "int32": 4,
}

def ceil_div(a: int, b: int) -> int:
    return (a + b - 1) // b


def dtype_size(name: str) -> int:
    key = name.lower()
    if key not in DTYPE_BYTES:
        raise SystemExit(f"unsupported dtype: {name}")
    return DTYPE_BYTES[key]


def fmt_bytes(num: float) -> str:
    sign = "-" if num < 0 else ""
    abs_num = abs(num)
    if abs_num >= 1e9:
        return f"{sign}{abs_num / 1e9:.3f} GB"
    if abs_num >= 1024 * 1024:
        return f"{sign}{abs_num / (1024 * 1024):.3f} MiB"
    if abs_num >= 1024:
        return f"{sign}{abs_num / 1024:.3f} KiB"
    return f"{sign}{abs_num:.0f} B"


def parse_bytes(value: str) -> int:
    text = value.strip().lower()
    suffixes = (
        ("gib", 1024 * 1024 * 1024),
        ("gb", 1024 * 1024 * 1024),
        ("mib", 1024 * 1024),
        ("mb", 1024 * 1024),
        ("kib", 1024),
        ("kb", 1024),
        ("b", 1),
    )
    for suffix, scale in suffixes:
        if text.endswith(suffix):
            return int(float(text[: -len(suffix)]) * scale)
    return int(text)


@dataclass
class Model:
    m: int
    n: int
    k: int
    input_bytes: int
    output_bytes: int
    m1: int
    n1: int
    k1: int
    rows: int
    cols: int
    cores: int
    ace_n: int
    ace_k: int
    ace_ghz: float
    hbm_gbps: float
    ldm_bytes: int | None
    layout: str
    ace_eff: float

    @property
    def m2(self) -> int:
        return self.m1 // self.cols

    @property
    def k2(self) -> int:
        return self.k1 // self.rows

    @property
    def m_loops(self) -> int:
        return ceil_div(self.m, self.m1)

    @property
    def n_loops(self) -> int:
        return ceil_div(self.n, self.n1)

    @property
    def k_loops(self) -> int:
        return ceil_div(self.k, self.k1)

    @property
    def flops(self) -> int:
        return 2 * self.m * self.n * self.k

    @property
    def flops_desc(self) -> int:
        return 2 * self.m2 * self.ace_n * self.ace_k

    @property
    def c_desc(self) -> int:
        return self.m2

    @property
    def ace_peak_tflops(self) -> float:
        return self.cores * self.flops_desc * self.ace_ghz * 1e9 / self.c_desc / 1e12

    @property
    def ace_eff_tflops(self) -> float:
        return self.ace_peak_tflops * self.ace_eff

    @property
    def a_bytes(self) -> int:
        return self.m * self.k * self.input_bytes

    @property
    def b_bytes(self) -> int:
        return self.k * self.n * self.input_bytes

    @property
    def c_bytes(self) -> int:
        return self.m * self.n * self.output_bytes

    @property
    def compute_traffic(self) -> int:
        return (
            self.a_bytes
            + self.m_loops * self.b_bytes
            + 2 * max(self.k_loops - 1, 0) * self.c_bytes
            + self.c_bytes
        )

    @property
    def layout_traffic(self) -> int:
        if self.layout == "include":
            return 2 * self.a_bytes + 2 * self.b_bytes
        return 0

    @property
    def total_traffic(self) -> int:
        return self.compute_traffic + self.layout_traffic

    @property
    def ai(self) -> float:
        return self.flops / self.total_traffic

    @property
    def hbm_roof_tflops(self) -> float:
        return self.ai * self.hbm_gbps * 1e9 / 1e12

    @property
    def roof_tflops(self) -> float:
        return min(self.ace_eff_tflops, self.hbm_roof_tflops)

    @property
    def ldm_mat_a_bytes(self) -> int:
        return self.m2 * self.k2 * self.input_bytes

    @property
    def ldm_mat_b_bytes(self) -> int:
        return self.ace_n * self.k2 * self.input_bytes * 3

    @property
    def ldm_mat_c_bytes(self) -> int:
        return self.ace_n * self.m2 // self.rows * self.output_bytes * 6

    @property
    def ldm_write_bytes(self) -> int:
        return self.ace_n * self.m2 * self.output_bytes * 2

    @property
    def ldm_estimated_bytes(self) -> int:
        return (
            self.ldm_mat_a_bytes
            + self.ldm_mat_b_bytes
            + self.ldm_mat_c_bytes
            + self.ldm_write_bytes
        )

    @property
    def ldm_margin_bytes(self) -> int:
        if self.ldm_bytes is None:
            raise ValueError("ldm_bytes is not provided")
        return self.ldm_bytes - self.ldm_estimated_bytes

    def ms_at(self, tflops: float) -> float:
        return self.flops / (tflops * 1e12) * 1e3

    def render_markdown(self) -> str:
        west_bytes = self.m2 * self.ace_k * self.input_bytes
        north_bytes = self.ace_k * self.ace_n * self.input_bytes
        out_bytes = self.m2 * self.ace_n * self.output_bytes
        t_desc_ns = self.c_desc / (self.ace_ghz * 1e9) * 1e9
        west_gbps = west_bytes / (t_desc_ns * 1e-9) / 1e9
        north_gbps = north_bytes / (t_desc_ns * 1e-9) / 1e9
        ace_loops = max(self.k2 // self.ace_k, 1)
        out_avg_gbps = out_bytes / (ace_loops * t_desc_ns * 1e-9) / 1e9

        lines = [
            "# GEMM Theoretical Performance Model",
            "",
            "## Inputs",
            "",
            f"- Shape: M={self.m}, N={self.n}, K={self.k}",
            f"- DTypes: input={self.input_bytes}B, output={self.output_bytes}B",
            f"- Tile: M1={self.m1}, N1={self.n1}, K1={self.k1}",
            f"- Topology: ROWS={self.rows}, COLS={self.cols}, cores={self.cores}",
            f"- ACE: ACE_N={self.ace_n}, ACE_K={self.ace_k}, freq={self.ace_ghz:.3f}GHz",
            f"- HBM/DMA bandwidth assumption: {self.hbm_gbps:.3f} GB/s",
            (
                f"- LDM usable max: {fmt_bytes(self.ldm_bytes)} ({self.ldm_bytes:,} B)"
                if self.ldm_bytes is not None
                else "- LDM usable max: not provided"
            ),
            f"- Layout traffic: {self.layout}",
            "",
            "## Compute",
            "",
            f"- FLOPs: {self.flops:,} = {self.flops / 1e9:.3f} GFLOPs",
            f"- M/N/K tile loops: {self.m_loops}/{self.n_loops}/{self.k_loops}",
            f"- M2={self.m2}, K2={self.k2}, ACE descriptors per K2={ace_loops}",
            f"- FLOPs per ACE descriptor: {self.flops_desc:,}",
            f"- Ideal ACE peak: {self.ace_peak_tflops:.3f} TFLOPS, {self.ms_at(self.ace_peak_tflops):.3f} ms",
            f"- ACE efficiency model: {self.ace_eff:.3f}",
            f"- Effective ACE upper bound: {self.ace_eff_tflops:.3f} TFLOPS, {self.ms_at(self.ace_eff_tflops):.3f} ms",
            "",
            "## ACE-LDM Bandwidth Per Core",
            "",
            f"- West bytes/desc: {west_bytes:,} B, bandwidth: {west_gbps:.2f} GB/s",
            f"- North bytes/desc: {north_bytes:,} B, bandwidth: {north_gbps:.2f} GB/s",
            f"- Output bytes/writeback: {out_bytes:,} B, average bandwidth: {out_avg_gbps:.2f} GB/s",
            "",
            "## LDM Capacity Per Core",
            "",
            f"- Model: A + 3*B + 6*C_dma + 2*C_write, matching the current 32X static check",
            f"- A tile bytes: {fmt_bytes(self.ldm_mat_a_bytes)}",
            f"- B buffered bytes: {fmt_bytes(self.ldm_mat_b_bytes)}",
            f"- C DMA buffered bytes: {fmt_bytes(self.ldm_mat_c_bytes)}",
            f"- C write buffered bytes: {fmt_bytes(self.ldm_write_bytes)}",
            f"- Estimated LDM use: {fmt_bytes(self.ldm_estimated_bytes)} ({self.ldm_estimated_bytes:,} B)",
            (
                f"- LDM usable max: {fmt_bytes(self.ldm_bytes)} ({self.ldm_bytes:,} B)"
                if self.ldm_bytes is not None
                else "- LDM usable max: not provided; pass --ldm-bytes to compute margin"
            ),
            (
                f"- LDM margin: {fmt_bytes(self.ldm_margin_bytes)} ({self.ldm_margin_bytes:,} B)"
                if self.ldm_bytes is not None
                else "- LDM margin: not computed"
            ),
            "",
            "## HBM/Workspace Roofline",
            "",
            f"- A bytes: {fmt_bytes(self.a_bytes)}",
            f"- B bytes: {fmt_bytes(self.b_bytes)}",
            f"- C bytes: {fmt_bytes(self.c_bytes)}",
            f"- Compute traffic: {fmt_bytes(self.compute_traffic)}",
            f"- Layout traffic: {fmt_bytes(self.layout_traffic)}",
            f"- Total modeled traffic: {fmt_bytes(self.total_traffic)}",
            f"- Arithmetic intensity: {self.ai:.2f} FLOPs/byte",
            f"- HBM roof: {self.hbm_roof_tflops:.3f} TFLOPS, {self.ms_at(self.hbm_roof_tflops):.3f} ms",
            f"- Final roof: {self.roof_tflops:.3f} TFLOPS, {self.ms_at(self.roof_tflops):.3f} ms",
        ]
        return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--m", type=int, required=True)
    parser.add_argument("--n", type=int, required=True)
    parser.add_argument("--k", type=int, required=True)
    parser.add_argument("--input-dtype", default="fp16")
    parser.add_argument("--accum-dtype", default="fp32")
    parser.add_argument("--output-dtype", default="fp32")
    parser.add_argument("--m1", type=int, default=1024)
    parser.add_argument("--n1", type=int, default=256)
    parser.add_argument("--k1", type=int, default=1536)
    parser.add_argument("--rows", type=int, default=4)
    parser.add_argument("--cols", type=int, default=8)
    parser.add_argument("--cores", type=int, default=32)
    parser.add_argument("--ace-n", type=int, default=32)
    parser.add_argument("--ace-k", type=int, default=32)
    parser.add_argument("--ace-ghz", type=float, default=1.18)
    parser.add_argument("--hbm-gbps", type=float, default=256.0)
    parser.add_argument("--ldm-bytes", type=parse_bytes, default=None)
    parser.add_argument("--layout", choices=["include", "exclude"], default="exclude")
    parser.add_argument("--ace-eff", type=float, default=0.89)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    _ = dtype_size(args.accum_dtype)
    model = Model(
        m=args.m,
        n=args.n,
        k=args.k,
        input_bytes=dtype_size(args.input_dtype),
        output_bytes=dtype_size(args.output_dtype),
        m1=args.m1,
        n1=args.n1,
        k1=args.k1,
        rows=args.rows,
        cols=args.cols,
        cores=args.cores,
        ace_n=args.ace_n,
        ace_k=args.ace_k,
        ace_ghz=args.ace_ghz,
        hbm_gbps=args.hbm_gbps,
        ldm_bytes=args.ldm_bytes,
        layout=args.layout,
        ace_eff=args.ace_eff,
    )
    print(model.render_markdown())


if __name__ == "__main__":
    main()
