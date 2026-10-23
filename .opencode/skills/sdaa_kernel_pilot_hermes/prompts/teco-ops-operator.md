# teco-ops operator optimization task

Use `humanize-kernel-agent-loop`, `teco-ops-op-test`, and mandatory Hermes
review to improve one operator in a clean `Tecorigin/teco-ops` checkout.

## K/R/W

- K: the selected operator's documented semantics, API, dtype/layout support,
  and implementation files under `teco/`.
- R: the native test oracle and tolerances in `test/zoo/teco/<op>/`.
- W: the required prototxt cases and their performance priority.

Record the exact source commit, target device, baseline, and unsupported cases.
Do not silently change the workload.

## Required workflow

1. Verify a clean target checkout at latest `origin/main` unless the task
   explicitly pins another revision.
2. Query `external/teco-ops-wiki` for the operator and proposed optimization;
   record page IDs and source paths.
3. Create only ignored RLCR, ledger, and raw-result paths.
4. Start strict-success RLCR and verify its state before implementation.
5. Establish a baseline with every required W case.
6. Make one measurable operator change per candidate.
7. Build only the selected operator test with `-f <op>`.
8. Run the standalone `0/0` correctness command for every required case and
   reject the candidate on any failure.
9. Only after all correctness cases pass, run the `3/50` performance command
   and compare SDPTI-backed Average Hardware Time under an identical environment.
10. Record all attempts and let Hermes gate each transition.

## Native command

```bash
OP=memset
CASE=case_0
source /opt/tecoai/setvars.sh
bash build.sh --build teco
cd test
source env.sh
bash build.sh --arch teco -f "$OP"

# Standalone correctness gate.
./build/demo --gid=0 --warm_repeat=0 --perf_repeat=0 --gtest_repeat=1 \
  --case_path="zoo/teco/${OP}/test_case/${CASE}.prototxt"

# Performance measurement after all required correctness cases pass.
./build/demo --gid=0 --warm_repeat=3 --perf_repeat=50 --gtest_repeat=1 \
  --case_path="zoo/teco/${OP}/test_case/${CASE}.prototxt"
```

The performance command calculates diffs again, but it does not replace the
standalone correctness gate. Lower Average Hardware Time is better. Do not score
host wall-clock time, build time, interface time, a single kernel-detail line,
source-cycle instrumentation, or another repository's benchmark.

## Completion

Finish only when all required correctness cases pass, the primary cases improve
without hidden regressions, commands and raw outputs are retained, wiki evidence
is recorded, and Hermes approves. Report baseline/final time and speedup per
case, plus regressions and unsupported cases.
