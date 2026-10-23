# 为 Kimi CLI 安装 Humanize

本指南说明如何为 [Kimi Code CLI](https://github.com/MoonshotAI/kimi-cli) 安装 Humanize skill。

## 概述

Humanize 为 Kimi 提供四个 Agent Skill：

| Skill | 类型 | 用途 |
|-------|------|---------|
| `humanize` | 标准 | 所有工作流的通用指导 |
| `humanize-gen-plan` | 流程 | 从草稿生成结构化计划 |
| `humanize-refine-plan` | 流程 | 使用 CMT 块优化带注释的计划 |
| `humanize-rlcr` | 流程 | 带 Codex 审查的迭代开发 |

## 安装

### 快速安装（推荐）

在 Humanize 仓库根目录下运行：

```bash
./scripts/install-skills-kimi.sh
```

此命令将：
- 将 `humanize`、`humanize-gen-plan`、`humanize-refine-plan` 和 `humanize-rlcr` 同步到 `~/.config/agents/skills`
- 将运行时依赖复制到 `~/.config/agents/skills/humanize`

通用安装脚本（所有目标）：

```bash
./scripts/install-skill.sh --target kimi
```

### 手动安装

### 1. 克隆或导航到 humanize 仓库

```bash
cd /path/to/humanize
```

### 2. 将 skill 和运行时包复制到 Kimi 的 skills 目录

```bash
# Create the skills directory if it doesn't exist
mkdir -p ~/.config/agents/skills

# Copy all four skills
cp -r skills/humanize ~/.config/agents/skills/
cp -r skills/humanize-gen-plan ~/.config/agents/skills/
cp -r skills/humanize-refine-plan ~/.config/agents/skills/
cp -r skills/humanize-rlcr ~/.config/agents/skills/

# Kimi 不使用 Codex 原生 Stop hook，因此安装 scripts/install-skill.sh --target kimi 使用的基于门控的 RLCR 入口点
cp skills/humanize-rlcr/SKILL-kimi.md ~/.config/agents/skills/humanize-rlcr/SKILL.md

# 复制 skill 使用的运行时依赖
# （必须与 install-skill.sh 的 install_runtime_bundle 匹配）
cp -r scripts ~/.config/agents/skills/humanize/
cp -r hooks ~/.config/agents/skills/humanize/
cp -r prompt-template ~/.config/agents/skills/humanize/
cp -r templates ~/.config/agents/skills/humanize/
cp -r config ~/.config/agents/skills/humanize/
cp -r agents ~/.config/agents/skills/humanize/

# 注入 SKILL.md 文件中的运行时根路径占位符
for skill in humanize humanize-gen-plan humanize-refine-plan humanize-rlcr; do
  sed -i.bak "s|{{HUMANIZE_RUNTIME_ROOT}}|$HOME/.config/agents/skills/humanize|g" \
    "$HOME/.config/agents/skills/$skill/SKILL.md"
done

# 从 SKILL.md 文件中移除 user-invocable 标志以适配运行时可见性
# （与 scripts/install-skill.sh 的行为一致）
for skill in humanize humanize-gen-plan humanize-refine-plan humanize-rlcr; do
  awk '
    BEGIN { in_fm = 0; fm_done = 0 }
    /^---[[:space:]]*$/ {
      if (fm_done == 0) {
        in_fm = !in_fm
        if (in_fm == 0) {
          fm_done = 1
        }
      }
      print
      next
    }
    in_fm && $0 ~ /^user-invocable:[[:space:]]*/ { next }
    { print }
  ' "$HOME/.config/agents/skills/$skill/SKILL.md" > "$HOME/.config/agents/skills/$skill/SKILL.md.tmp"
  mv "$HOME/.config/agents/skills/$skill/SKILL.md.tmp" "$HOME/.config/agents/skills/$skill/SKILL.md"
done
```

### 3. 验证安装

```bash
# 列出已安装的 skill
ls -la ~/.config/agents/skills/

# 应显示：
# humanize/
# humanize-gen-plan/
# humanize-refine-plan/
# humanize-rlcr/
```

### 4. 重启 Kimi（如果已在运行）

Skill 在启动时加载。重启 Kimi 以加载新的 skill：

```bash
# 退出当前 Kimi 会话
/exit

# 或按 Ctrl-D

# 重新启动 Kimi
kimi
```

## 使用

### 列出可用 skill

```bash
/help
```

在帮助输出中查找 "Skills" 部分。

### 使用 skill

#### 1. 从草稿生成计划

```bash
# 启动流程（会询问输入/输出路径）
/flow:humanize-gen-plan

# 或作为标准 skill 加载
/skill:humanize-gen-plan
```

#### 2. 启动 RLCR 开发循环

```bash
# 使用计划文件启动
/flow:humanize-rlcr path/to/plan.md

# 带选项
/flow:humanize-rlcr path/to/plan.md --max 20 --push-every-round

# 跳过实现阶段，直接进入代码审查
/flow:humanize-rlcr --skip-impl

# 作为标准 skill 加载（不自动执行）
/skill:humanize-rlcr
```

#### 3. 获取通用指导

```bash
/skill:humanize
```

## 命令选项

### RLCR 循环选项

| 选项 | 描述 | 默认值 |
|------|------|--------|
| `path/to/plan.md` | 计划文件路径 | 必需（除非 --skip-impl） |
| `--max N` | 最大迭代次数 | 84 |
| `--codex-model MODEL:EFFORT` | Codex 模型 | gpt-5.5:high |
| `--codex-timeout SECONDS` | 审查超时时间 | 5400 |
| `--base-branch BRANCH` | 代码审查的基础分支 | 自动检测 |
| `--full-review-round N` | 全面对齐检查间隔 | 5 |
| `--skip-impl` | 跳到代码审查 | false |
| `--push-every-round` | 每轮后推送 | false |

### 生成计划选项

| 选项 | 描述 | 必需 |
|------|------|------|
| `--input <path>` | 草稿文件路径 | 是 |
| `--output <path>` | 计划输出路径 | 是 |

## 前提条件

确保已安装 `codex` CLI：

```bash
codex --version
```

Skill 默认使用 `gpt-5.5` 和 `high` 推理强度。

## 卸载

要移除 skill：

```bash
rm -rf ~/.config/agents/skills/humanize
rm -rf ~/.config/agents/skills/humanize-gen-plan
rm -rf ~/.config/agents/skills/humanize-refine-plan
rm -rf ~/.config/agents/skills/humanize-rlcr
```

## 故障排除

### Skill 未显示

1. 检查 skills 目录是否存在：
   ```bash
   ls ~/.config/agents/skills/
   ```

2. 确保 SKILL.md 文件存在：
   ```bash
   cat ~/.config/agents/skills/humanize/SKILL.md | head -5
   ```

3. 完全重启 Kimi

### 找不到 Codex

Skill 期望 `codex` 在你的 PATH 中。如果使用代理，确保 `~/.zprofile` 已配置：

```bash
# 如果需要，添加到 ~/.zprofile
export OPENAI_API_KEY="your-api-key"
# 或其他代理设置
```

### 找不到脚本

如果 skill 报告缺少 `setup-rlcr-loop.sh` 等脚本，请验证：

```bash
ls -la ~/.config/agents/skills/humanize/scripts
```

### 安装程序选项

安装程序支持：

```bash
./scripts/install-skill.sh --help
```

常用示例：

```bash
# 仅预览
./scripts/install-skills-kimi.sh --dry-run

# 自定义 skills 目录
./scripts/install-skills-kimi.sh --skills-dir /custom/skills/dir
```

### 找不到输出文件

Skill 将输出保存到：
- 缓存：`~/.cache/humanize/<project>/<timestamp>/`
- 循环数据：`.humanize/rlcr/<timestamp>/`

确保这些目录可写。

## 另请参阅

- [Kimi CLI 文档](https://moonshotai.github.io/kimi-cli/)
- [Agent Skills 格式](https://agentskills.io/)
- [为 Codex 安装](./install-for-codex.md)
- [Humanize README](../README.md)
