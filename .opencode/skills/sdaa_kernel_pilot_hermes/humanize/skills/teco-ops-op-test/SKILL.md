---
name: teco-ops-op-test
description: Build, validate, and benchmark operators in the Tecorigin/teco-ops repository with its native C++ demo and SDPTI-backed metrics. Use for teco-ops correctness checks, performance comparisons, optimization acceptance, or reproducing the README and doc/README_OP.md test workflow.
---

# Test teco-ops operators

Use the repository's own test framework. Do not substitute host timers,
KernelPilot cycle instrumentation, tecoal tecotest, tecolmk lmtest, or an
external profiler as the acceptance benchmark.

## Establish the revision and workload

Require a clean teco-ops worktree. Fetch `origin/main`, record
`git rev-parse HEAD`, and use the latest `origin/main` commit unless the user
explicitly pins another revision. Do not update or switch a dirty worktree
automatically. For the latest-main workflow, verify:

```bash
git fetch origin main
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
```

Select existing prototxt cases from `test/zoo/teco/<op>/test_case/`. Keep the
same case set, device, build flags, and runtime environment for baseline and
candidate. Add a case only when K/R/W requires coverage that is missing.

## Build

Run from the teco-ops root:

```bash
OP=memset
source /opt/tecoai/setvars.sh
bash build.sh --build teco
cd test
source env.sh
bash build.sh --arch teco -f "$OP"
```

Set `OP` to the selected operator name so the test build contains only that
operator. Record the exact commands and compiler/runtime versions.

## Run the standalone correctness gate

Before collecting performance, run every required correctness case without
warm-up or performance repeats:

```bash
CASE=case_0
./build/demo \
  --gid=0 \
  --warm_repeat=0 \
  --perf_repeat=0 \
  --gtest_repeat=1 \
  --case_path="zoo/teco/${OP}/test_case/${CASE}.prototxt"
```

Treat a nonzero exit, a GoogleTest failure, a comparison failure, or a test
framework error as a correctness failure. Reject the candidate and do not run
or score its performance cases.

## Run performance after correctness passes

After every required correctness case passes, run each selected performance
case with the README and `doc/README_OP.md` repeat policy:

```bash
./build/demo \
  --gid=0 \
  --warm_repeat=3 \
  --perf_repeat=50 \
  --gtest_repeat=1 \
  --case_path="zoo/teco/${OP}/test_case/${CASE}.prototxt"
```

The performance command calculates diffs again. Treat any failure as a candidate
failure and discard its performance output; this repeated check does not replace
the standalone correctness gate.

For an operator-level run through the Python test driver, preserve both phases:

```bash
python tools/unit_test_v2.py \
  --gid=0 \
  --cases_dir zoo/ \
  --warm_repeat 0 \
  --perf_repeat 0 \
  --test_name "$OP"
```

Only after that command passes:

```bash
python tools/unit_test_v2.py \
  --gid=0 \
  --cases_dir zoo/ \
  --warm_repeat 3 \
  --perf_repeat 50 \
  --test_name "$OP"
```

## Score candidates

Use `[Average Hardware Time]: ... (ms)` as the primary score; lower is better.
It is SDPTI device-kernel time. With 50 repeats, the test framework sorts the
per-repeat hardware times, discards the highest and lowest five samples, and
averages the remaining 40.

Use Average ComputeForce and Average IoBandWidth only as secondary diagnostic
metrics. Do not score from Average Interface Time, Average Launch Time, a
single Kernel Detail line, build duration, or host wall-clock time.

## Preserve evidence

For baseline and every retained correct candidate, record:

- source commit and diff identity;
- operator, prototxt paths, device ID, and environment;
- build and run commands;
- standalone zero-repeat correctness result and tolerance details;
- warm-up count 3 and performance repeat count 50;
- Average Hardware Time plus secondary metrics; and
- raw stdout/stderr artifact path.

Accept a candidate only when all required cases pass and its comparable primary
score improves. Report regressions case by case; do not hide them in an average.
