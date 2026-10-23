# AGENTS.md

## Project

KernelPilot Hermes optimizes operators in `Tecorigin/teco-ops`. Humanize owns
the RLCR lifecycle and Hermes is the mandatory review gate. Define each task as
K/R/W: operator semantics, native correctness oracle, and selected prototxt
workload.

## Test policy

- Use only `humanize/skills/teco-ops-op-test` for correctness and performance.
- Build with the target repository's `build.sh` scripts.
- Run `test/build/demo` with 3 warm-ups, 50 performance repeats, and one Google
  Test repeat.
- Require correctness to pass before scoring the same source revision.
- Minimize SDPTI-backed `Average Hardware Time` for identical cases and
  environments.
- Do not use host wall-clock time, build time, source-cycle instrumentation,
  another repository's test framework, or a manual score map.

## Knowledge policy

Use `external/teco-ops-wiki` exclusively. If it lacks evidence, inspect the
upstream teco-ops source and record the gap. Do not substitute another wiki.

## Commands

```bash
humanize/scripts/install-skills-hermes.sh
humanize/scripts/hermes-health-check.sh --skip-live
humanize/tests/run-all-tests.sh
HUMANIZE_TEST_JOBS=4 humanize/tests/run-all-tests.sh
humanize/viz/scripts/viz-start.sh
```

## Architecture

- `humanize/hooks/`: lifecycle and safety hooks.
- `humanize/scripts/`: setup, installation, monitoring, and review wrappers.
- `humanize/skills/humanize-kernel-agent-loop/`: teco-ops RLCR flow.
- `humanize/skills/teco-ops-op-test/`: native test and scoring policy.
- `external/teco-ops-wiki/`: exclusive evidence corpus.

## Repository rules

- Use English for implementation, comments, tests, and active documentation.
- Do not use emoji.
- Preserve unrelated user changes.
- Keep generated workspaces, RLCR state, build outputs, and performance results
  out of version control.
- Version changes must update `humanize/.claude-plugin/plugin.json`,
  `humanize/.claude-plugin/marketplace.json`, and the current-version line in
  `humanize/README.md`.
- Keep synchronized templates and schemas synchronized as documented by
  Humanize's own `AGENTS.md` rules.
