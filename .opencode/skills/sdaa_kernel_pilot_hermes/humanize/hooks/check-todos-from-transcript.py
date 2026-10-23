#!/usr/bin/env python3
"""
辅助脚本，用于检查 Claude Code 中未完成的任务。

同时支持：
- 旧版 TodoWrite 工具（从 transcript 中解析）
- 新版 Task 系统（直接从 ~/.claude/tasks/<session_id>/ 读取）

退出码：
  0 - 所有任务已完成（或不存在任务）
  1 - 存在未完成的任务（详情输出到 stdout）
  2 - 解析 hook 输入 JSON 时出错

用法：
    echo '{"session_id": "...", "transcript_path": "/path/to/transcript.jsonl"}' | python3 check-todos-from-transcript.py
"""
import json
import re
import sys
from pathlib import Path
from typing import List, Tuple


LANE_PREFIX_PATTERN = re.compile(r"^\s*\[(mainline|blocking|queued)\](?:\s|$)", re.IGNORECASE)


def classify_lane(*parts: str) -> str:
    """从内容推断任务通道，默认为 blocking 以确保安全。"""
    for part in parts:
        if not part:
            continue
        match = LANE_PREFIX_PATTERN.match(part)
        if match:
            return match.group(1).lower()
    return "blocking"


# 循环编排元任务模式：诸如 "Start RLCR and run Round 0" 这类任务代表“驱动整个
# RLCR 循环”，Codex 审查本身就是完成它的一部分。它在循环运行期间天然保持
# in_progress，若被待办门当作未完成任务，会导致循环永远进不了审查（死锁）。
# 因此把这类编排元任务排除在阻塞判定之外。内核实现任务不会以 RLCR/round 命名。
ORCHESTRATION_PATTERN = re.compile(
    r"(start\s+rlcr|rlcr\s+loop|run\s+(the\s+)?rlcr|run\s+round\s*\d|start[-\s]*rlcr[-\s]*loop)",
    re.IGNORECASE,
)


def is_loop_orchestration(*parts: str) -> bool:
    """判断任务是否为驱动 RLCR 循环本身的编排元任务（应排除出待办门）。"""
    for part in parts:
        if part and ORCHESTRATION_PATTERN.search(part):
            return True
    return False


def extract_tool_calls_from_entry(entry: dict) -> List[Tuple[str, dict]]:
    """
    从 transcript 条目中提取工具调用。
    返回 (tool_name, tool_input) 元组的列表。
    """
    tool_calls = []
    entry_type = entry.get("type", "")

    # 模式 1 和 2：从 assistant 或 message 条目中提取内容列表
    if entry_type == "assistant":
        content = entry.get("message", {}).get("content", [])
    elif entry_type == "message":
        content = entry.get("content", [])
    else:
        content = []

    # 从内容列表中提取工具调用
    if isinstance(content, list):
        for block in content:
            if isinstance(block, dict) and block.get("type") == "tool_use":
                tool_name = block.get("name", "")
                tool_input = block.get("input", {})
                if tool_name:
                    tool_calls.append((tool_name, tool_input))

    # 模式 3：直接的 tool_use 条目
    if entry_type == "tool_use":
        tool_name = entry.get("name", "") or entry.get("tool_name", "")
        tool_input = entry.get("input", {}) or entry.get("tool_input", {})
        if tool_name:
            tool_calls.append((tool_name, tool_input))

    return tool_calls


def find_incomplete_todos_from_transcript(transcript_path: Path) -> List[dict]:
    """
    解析 transcript JSONL 并查找未完成的旧版待办事项（仅 TodoWrite）。

    返回包含 'status' 和 'content' 键的未完成项目列表。
    """
    if not transcript_path.exists():
        return []

    # 旧版：跟踪最近的 TodoWrite 待办事项
    latest_todos = []

    with open(transcript_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            # 从此条目中提取所有工具调用
            for tool_name, tool_input in extract_tool_calls_from_entry(entry):
                # 旧版：TodoWrite
                if tool_name == "TodoWrite":
                    todos = tool_input.get("todos", [])
                    if todos:
                        latest_todos = todos

    # 从旧版待办事项构建未完成项目列表
    incomplete = []
    for todo in latest_todos:
        status = todo.get("status", "")
        content = todo.get("content", "")
        if status != "completed":
            lane = classify_lane(content)
            if lane == "queued":
                continue
            if is_loop_orchestration(content):
                continue
            incomplete.append({
                "status": status,
                "content": content,
                "source": "todo",
                "lane": lane,
            })

    return incomplete


def find_incomplete_tasks_from_directory(session_id: str, tasks_base_dir: str = "") -> List[dict]:
    """
    直接从 ~/.claude/tasks/<session_id>/ 目录读取任务文件。

    这是任务状态的权威来源，因为它反映了
    Claude Code 维护的实际内存中的任务列表。

    Args:
        session_id: Claude Code 的会话 ID
        tasks_base_dir: 可选的任务基础目录覆盖（用于测试）

    返回包含 'status' 和 'content' 键的未完成项目列表。
    """
    if tasks_base_dir:
        tasks_dir = Path(tasks_base_dir) / session_id
    else:
        tasks_dir = Path.home() / ".claude" / "tasks" / session_id
    if not tasks_dir.exists() or not tasks_dir.is_dir():
        return []

    incomplete = []
    for task_file in tasks_dir.glob("*.json"):
        try:
            with open(task_file, 'r', encoding='utf-8') as f:
                task = json.load(f)

            status = task.get("status", "pending")
            if status not in ("completed", "deleted"):
                # 任务未完成
                subject = task.get("subject", "")
                description = task.get("description", "")
                task_id = task_file.stem  # 文件名去掉 .json 后缀
                content = subject or description or f"Task {task_id}"
                lane = classify_lane(subject, description)
                if lane == "queued":
                    continue
                if is_loop_orchestration(subject, description, content):
                    continue
                incomplete.append({
                    "status": status,
                    "content": content,
                    "source": "task",
                    "task_id": task_id,
                    "lane": lane,
                })
        except (json.JSONDecodeError, OSError):
            # 跳过格式错误或无法读取的任务文件
            continue

    return incomplete


def main():
    # 从 stdin 读取 hook 输入
    try:
        stdin_content = sys.stdin.read().strip()
        if not stdin_content:
            # 空输入 - 没有可用数据，允许继续执行
            sys.exit(0)
        hook_input = json.loads(stdin_content)
    except json.JSONDecodeError as e:
        # 解析错误 - 以代码 2 退出
        print(f"PARSE_ERROR: {e}", file=sys.stderr)
        sys.exit(2)

    incomplete_items = []

    # 使用外部任务目录检查新版 Task 系统（权威来源）
    session_id = hook_input.get("session_id", "")
    tasks_base_dir = hook_input.get("tasks_base_dir", "")  # 用于测试
    if session_id:
        incomplete_items.extend(find_incomplete_tasks_from_directory(session_id, tasks_base_dir))

    # 从 transcript 检查旧版 TodoWrite
    transcript_path = hook_input.get("transcript_path", "")
    if transcript_path:
        transcript_path = Path(transcript_path).expanduser()
        incomplete_items.extend(find_incomplete_todos_from_transcript(transcript_path))

    if not incomplete_items:
        # 没有未完成的项目，允许继续执行
        sys.exit(0)

    # 格式化输出
    output_lines = []
    for item in incomplete_items:
        status = item.get("status", "unknown")
        content = item.get("content", "")
        source = item.get("source", "unknown")
        lane = item.get("lane", "blocking")
        lane_marker = f"[{lane}]"
        if source == "task":
            task_id = item.get("task_id", "?")
            output_lines.append(f"  - [{status}] {lane_marker} (Task #{task_id}) {content}")
        else:
            output_lines.append(f"  - [{status}] {lane_marker} {content}")

    # 将标记和未完成项目都输出到 stdout
    print("INCOMPLETE_TODOS")
    print("\n".join(output_lines))
    sys.exit(1)


if __name__ == "__main__":
    main()
