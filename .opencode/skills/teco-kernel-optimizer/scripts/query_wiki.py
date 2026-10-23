#!/usr/bin/env python3
"""
Query teco-ops-wiki before each iteration to ensure Claude uses up-to-date hardware knowledge.
This script is called automatically by the optimization workflow.
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def find_wiki_dir():
    """Find teco-ops-wiki directory."""
    # Search in common locations
    search_paths = [
        Path.cwd() / "teco-ops-wiki",
        Path.cwd().parent / "teco-ops-wiki",
        Path("/data/application/xuelu/sdaa-optimized-skill/teco-ops-wiki"),
    ]

    for path in search_paths:
        if path.exists() and (path / "scripts" / "query.py").exists():
            return path

    return None


def query_wiki(topic: str, compact: bool = True) -> dict:
    """Query teco-ops-wiki for a specific topic."""
    wiki_dir = find_wiki_dir()
    if not wiki_dir:
        return {
            "success": False,
            "error": "teco-ops-wiki not found",
            "results": []
        }

    query_script = wiki_dir / "scripts" / "query.py"
    cmd = ["python3", str(query_script), topic]
    if compact:
        cmd.append("--compact")

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            return {
                "success": False,
                "error": result.stderr,
                "results": []
            }

        # Parse the output
        output = result.stdout
        results = []
        for line in output.split("\n"):
            if line.strip().startswith("[wiki-"):
                results.append(line.strip())

        return {
            "success": True,
            "topic": topic,
            "results": results,
            "raw_output": output
        }

    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "error": "Query timed out",
            "results": []
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "results": []
        }


def get_page(page_id: str) -> dict:
    """Get a specific wiki page."""
    wiki_dir = find_wiki_dir()
    if not wiki_dir:
        return {
            "success": False,
            "error": "teco-ops-wiki not found",
            "content": ""
        }

    get_page_script = wiki_dir / "scripts" / "get_page.py"
    cmd = ["python3", str(get_page_script), page_id]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            return {
                "success": False,
                "error": result.stderr,
                "content": ""
            }

        return {
            "success": True,
            "page_id": page_id,
            "content": result.stdout
        }

    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "content": ""
        }


def query_for_op(op: str, iter_num: int) -> dict:
    """Query wiki for operator-specific knowledge."""
    queries = {
        "gemm": [
            "GEMM FP16 FP32 memory optimization",
            "ACE double buffering",
            "RMA contention",
            "DMA bandwidth"
        ],
        "rms": [
            "RMSNorm reduction pattern",
            "LDM pressure optimization"
        ],
        "fla3": [
            "Flash Attention softmax",
            "tiling memory reuse"
        ],
        "reshape_and_cache_flash": [
            "paged KV cache optimization",
            "memory copy bandwidth",
            "SPE parallelization"
        ],
        "reshape_and_cache": [
            "paged KV cache optimization",
            "memory copy bandwidth",
            "SPE parallelization"
        ]
    }

    topics = queries.get(op, ["SDAA kernel optimization"])

    all_results = {}
    for topic in topics:
        result = query_wiki(topic)
        all_results[topic] = result

    # Also query for key pages
    key_pages = {
        "gemm": ["kernel-sdaa-gemm", "technique-ace-double-buffering", "pattern-rma-contention"],
        "rms": ["kernel-sdaa-rmsnorm"],
        "fla3": ["kernel-sdaa-flash-attention"],
        "reshape_and_cache_flash": ["kernel-sdaa-reshape-and-cache"],
        "reshape_and_cache": ["kernel-sdaa-reshape-and-cache"]
    }

    pages_content = {}
    for page_id in key_pages.get(op, []):
        page_result = get_page(page_id)
        pages_content[page_id] = page_result

    return {
        "iter": iter_num,
        "op": op,
        "queries": all_results,
        "pages": pages_content,
        "timestamp": subprocess.run(
            ["date", "+%Y-%m-%d %H:%M:%S"],
            capture_output=True,
            text=True
        ).stdout.strip()
    }


def main():
    parser = argparse.ArgumentParser(description="Query teco-ops-wiki before iteration")
    parser.add_argument("--op", required=True, help="Operator name (gemm, rms, fla3)")
    parser.add_argument("--iter", type=int, required=True, help="Iteration number")
    parser.add_argument("--out", required=True, help="Output JSON file path")
    parser.add_argument("--topic", help="Custom topic to query (optional)")

    args = parser.parse_args()

    # Query wiki
    if args.topic:
        result = {
            "iter": args.iter,
            "op": args.op,
            "custom_query": query_wiki(args.topic)
        }
    else:
        result = query_for_op(args.op, args.iter)

    # Save to file
    output_path = Path(args.out)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, "w") as f:
        json.dump(result, f, indent=2)

    # Print summary
    print(f"[wiki_query] Iteration {args.iter}: Queried wiki for op={args.op}")

    if args.topic:
        success = result["custom_query"]["success"]
        num_results = len(result["custom_query"].get("results", []))
        print(f"[wiki_query] Custom topic '{args.topic}': {'SUCCESS' if success else 'FAILED'}, {num_results} results")
    else:
        total_queries = len(result["queries"])
        successful_queries = sum(1 for q in result["queries"].values() if q["success"])
        total_pages = len(result["pages"])
        successful_pages = sum(1 for p in result["pages"].values() if p["success"])
        print(f"[wiki_query] Queries: {successful_queries}/{total_queries} successful")
        print(f"[wiki_query] Pages: {successful_pages}/{total_pages} retrieved")

    print(f"[wiki_query] Results saved to {args.out}")

    # Return success if at least one query succeeded
    if args.topic:
        return 0 if result["custom_query"]["success"] else 1
    else:
        any_success = any(q["success"] for q in result["queries"].values())
        return 0 if any_success else 1


if __name__ == "__main__":
    sys.exit(main())
