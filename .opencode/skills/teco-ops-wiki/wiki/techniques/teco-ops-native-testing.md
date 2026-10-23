---
id: technique-teco-ops-native-testing
title: "Native teco-ops correctness and SDPTI performance testing"
type: technique
architectures: [sdaa, teco-t1]
tags: [benchmarking, correctness, sdpti, teco-ops]
confidence: verified
reproducibility: runnable
sources: [source-teco-ops-main]
---

# Native teco-ops testing

Build the TECO library, build `test/build/demo`, then run each required
prototxt case with `--gid=0 --warm_repeat=3 --perf_repeat=50
--gtest_repeat=1`. This is the workflow documented by the repository README and
`doc/README_OP.md`.

Use the same invocation as the correctness gate and benchmark. A test failure
invalidates the performance sample. Use `Average Hardware Time` as the primary
score: the SDAA profiler collects SDPTI kernel activity, constructs one total
kernel time per repeat, sorts 50 values, drops the highest and lowest five, and
averages the middle 40. Lower is better.

Average Interface Time, Average Launch Time, and individual Kernel Detail lines
are diagnostic only. Keep case paths, commit, device, commands, correctness
result, repeat policy, and raw output for every retained result.
