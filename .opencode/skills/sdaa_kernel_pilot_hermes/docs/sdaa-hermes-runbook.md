# teco-ops KernelPilot Hermes runbook

## Preconditions

- Hermes CLI and provider configuration are working.
- SDAA compiler, runtime, device, and `/opt/tecoai/setvars.sh` are available.
- The teco-ops checkout is clean and at latest `origin/main`, unless the task
  explicitly pins another revision.
- K/R/W identifies the operator, correctness cases, and performance cases.
- `external/teco-ops-wiki` passes validation.

```bash
humanize/scripts/hermes-health-check.sh --skip-live
```

## Install

```bash
humanize/scripts/install-skills-hermes.sh
```

For a non-default wiki location:

```bash
humanize/scripts/install-skill.sh \
  --target hermes \
  --teco-ops-wiki-root /absolute/path/to/teco-ops-wiki
```

No alternative wiki or performance skill is supported.

## Prepare the target checkout

Clone the repository when no target checkout exists, then verify latest main:

```bash
git clone https://github.com/Tecorigin/teco-ops.git /absolute/path/to/teco-ops
cd /absolute/path/to/teco-ops
git fetch origin main
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
```

Record the exact commit. Do not switch or update a dirty checkout automatically.
Use the teco-ops checkout itself as the
optimization workspace; do not copy an operator into a synthetic project.

Create ignored local paths for RLCR and evidence:

```text
.humanize/
ledgers/
performance-results/
```

Write the refined K/R/W plan, initialize a clean scaffold commit if needed,
start strict-success RLCR, and verify `.humanize/rlcr/*/state.md` before editing
an operator.

## Query the wiki

```bash
cd /absolute/path/to/kernelpilot/external/teco-ops-wiki
python3 scripts/query.py "<operator> DMA SPM optimization" --limit 5 --compact
python3 scripts/get_page.py <page-id> --follow-sources
```

Record page IDs and the decision they changed. Inspect
`artifacts/repos/teco-ops/` for exact source behavior. If coverage is missing,
inspect upstream teco-ops and record the evidence gap.

## Build and test

From the teco-ops root:

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

Build only the selected operator test with `-f <op>`. First run every required W
case with zero warm-ups and zero performance repeats as a standalone correctness
gate. A nonzero exit, GoogleTest failure, comparison failure, or test framework
error rejects the candidate and skips performance measurement. Only after the
complete correctness case set passes, rerun every required performance case with
3 warm-ups and 50 performance repeats.

The primary score is `[Average Hardware Time]` in milliseconds. It is SDPTI
device-kernel time. The framework sorts the 50 per-repeat hardware times,
discards the highest and lowest five, and averages the middle 40. Lower is
better. TFLOPS and IO bandwidth are secondary diagnostics.

Do not score host time, interface time, launch time, a single kernel-detail
sample, build duration, or results from another framework.

## Iterate under RLCR

For each candidate, make one measurable change, run the standalone correctness
gate, compare native hardware time only when every required correctness case
passes, update the attempt ledger, retain raw output, and let Hermes gate the
next transition.

The final report includes commit, device, case paths, build and run commands,
baseline/final hardware time per case, speedup, correctness status, regressions,
unsupported cases, wiki page IDs, and raw artifact paths.
