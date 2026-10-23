# Install KernelPilot for Codex

```bash
humanize/scripts/install-skills-codex.sh
```

The installer synchronizes Humanize, the teco-ops RLCR loop,
`teco-ops-op-test`, and the exclusive `teco-ops-wiki` skill.

```bash
humanize/scripts/install-skill.sh \
  --target codex \
  --teco-ops-wiki-root /absolute/path/to/teco-ops-wiki
```

Installation fails when the wiki is incomplete. No alternative wiki or
performance skill is installed.
