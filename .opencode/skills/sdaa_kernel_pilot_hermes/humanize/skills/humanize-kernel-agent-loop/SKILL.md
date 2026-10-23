---
name: humanize-kernel-agent-loop
description: Optimize operators in the Tecorigin/teco-ops SDAA custom-operator repository with the Humanize RLCR lifecycle, mandatory Hermes review, the native teco-ops correctness/performance test framework, and teco-ops-wiki as the only knowledge base.
---

# Optimize teco-ops with RLCR

Keep the original Humanize RLCR lifecycle and Hermes gate. Replace the former
KernelPilot benchmark paths with `teco-ops-op-test` for both correctness and
performance acceptance.

## Inputs

Recover or define:

```text
K: target teco-ops operator semantics and implementation boundary
R: native test oracle and tolerances
W: selected prototxt case distribution and performance objective
```

Also record the teco-ops source commit, target SDAA device, baseline, and hard
scope constraints. Ask only when a missing value cannot be inferred safely.

## Installed paths

```text
Humanize runtime: {{HUMANIZE_RUNTIME_ROOT}}
KernelPilot root: {{KERNELPILOT_ROOT}}
teco-ops-wiki root: {{TECO_OPS_WIKI_ROOT}}
```

Verify that the wiki contains `SKILL.md`, `scripts/query.py`,
`scripts/get_page.py`, `data/tags.yaml`, and `wiki/`. Never substitute another
wiki. Verify `hermes --version` and provider configuration; never substitute
another reviewer.

## Bootstrap gate

Before RLCR starts, limit work to selecting a clean teco-ops checkout at the
latest `origin/main` commit unless the user pins another revision,
recovering K/R/W, writing the refined plan and ledgers, and creating a clean
scaffold commit. Do not implement or benchmark a candidate before RLCR is
active.

The optimization workspace is the teco-ops checkout itself. Do not copy the
operator into a synthetic KernelPilot workspace. Keep all implementation,
native test cases, and build files in the repository's documented layout.
Store KernelPilot-only state under ignored `.humanize/`, `performance-results/`,
and `ledgers/` paths.

Start strict-success RLCR and verify state:

```bash
humanize/scripts/setup-rlcr-loop.sh --strict-success
find .humanize/rlcr -maxdepth 2 -name state.md -print
```

Stop if no state file exists.

## Iteration

For every candidate:

1. Read the active round prompt.
2. Query `teco-ops-wiki` for the operator, hardware feature, and proposed
   technique; record the page IDs and affected decision.
3. Make one measurable implementation change in the teco-ops tree.
4. Use `teco-ops-op-test` to build only the selected operator test.
5. Run the standalone zero-repeat correctness gate for every required W case.
6. Reject the candidate if any correctness case fails; otherwise run the
   3-warm-up/50-repeat performance command for the required performance cases.
7. Compare `[Average Hardware Time]` only for identical cases and environment.
8. Record the attempt, raw output path, and regressions.
9. Let Hermes review and gate the next transition.

## Native test contract

Run the documented teco-ops build and test flow:

```bash
OP=memset
CASE=case_0
source /opt/tecoai/setvars.sh
bash build.sh --build teco
cd test
source env.sh
bash build.sh --arch teco -f "$OP"

./build/demo --gid=0 --warm_repeat=0 --perf_repeat=0 --gtest_repeat=1 \
  --case_path="zoo/teco/${OP}/test_case/${CASE}.prototxt"

./build/demo --gid=0 --warm_repeat=3 --perf_repeat=50 --gtest_repeat=1 \
  --case_path="zoo/teco/${OP}/test_case/${CASE}.prototxt"
```

Run the zero-repeat command for every required case and stop on any failure.
Only then run the performance command. Its repeated execution also calculates
diffs, but it does not replace the standalone correctness gate. The primary
score is SDPTI-backed Average Hardware Time in milliseconds, lower being better.
The framework discards the highest and lowest 10 percent of the 50 per-repeat
samples. Treat TFLOPS and IO bandwidth as diagnostics. Do not use host wall-clock
time, build time, source instrumentation, a manually maintained score map, or
another repository's benchmark as acceptance evidence.

Correctness must pass for the same source revision before any score can select
a candidate.

## Wiki contract

Use only:

```bash
cd {{TECO_OPS_WIKI_ROOT}}
python3 scripts/query.py "<operator> DMA SPM optimization" --limit 5 --compact
python3 scripts/get_page.py <page-id> --follow-sources
```

Inspect `artifacts/repos/teco-ops/` when exact source or test behavior matters.
If the wiki lacks evidence, record the gap and inspect the upstream teco-ops
source; do not open a second local wiki.

## Acceptance

Accept a final candidate only when:

1. all required native correctness cases pass the standalone zero-repeat gate;
2. all reported measurements use 3 warm-ups and 50 performance repeats;
3. Average Hardware Time improves on the primary W cases without an
   unacknowledged required-case regression;
4. revision, device, cases, commands, metrics, and raw artifacts are retained;
5. relevant wiki page IDs are recorded; and
6. Hermes approves the transition and final result.

The final report names the selected operator implementation, baseline and final
hardware time per case, speedup, correctness status, regressions, unsupported
cases, and retained evidence paths.
