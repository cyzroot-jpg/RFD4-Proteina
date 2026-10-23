# Install KernelPilot for Claude Code

```bash
humanize/scripts/install-skills-claude.sh
```

The installer hydrates Humanize, installs the teco-ops RLCR loop and
`teco-ops-op-test`, and links `teco-ops-wiki` as the exclusive wiki.

```bash
humanize/scripts/install-skills-claude.sh \
  --teco-ops-wiki-root /absolute/path/to/teco-ops-wiki
```

```bash
test -f ~/.claude/skills/teco-ops-op-test/SKILL.md
test -f ~/.claude/skills/teco-ops-wiki/SKILL.md
humanize/scripts/hermes-health-check.sh --skip-live
```
