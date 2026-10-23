#!/usr/bin/env python3
"""Deterministic completeness check for organized doc pages.

For each work-item (raw slice -> generated page), extract API-like identifiers
from the raw slice and verify each appears in the generated page. Catches
dropped function names / enums / env vars that an LLM verify pass might miss.

Usage:
  python3 scripts/check_doc_coverage.py            # check all, summary
  python3 scripts/check_doc_coverage.py --details  # list missing identifiers per page
  python3 scripts/check_doc_coverage.py --worklist /tmp/sdaa_pdf_txt/_worklist.json
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _wiki_root import WIKI_ROOT  # noqa: E402

DEFAULT_WORKLIST = str(WIKI_ROOT / "sources" / "docs" / "raw" / "_worklist.json")

# Identifier families that are meaningful API surface (not prose).
PATTERNS = [
    re.compile(r'\b(?:sdaa|teco|simd|tcc|sdpti|SDpti|tsmi|tsight)[A-Za-z0-9_]{2,}', re.I),
    re.compile(r'\b(?:thread_group|rma|dma|matmul|broadcast|memcpy|ldm)_[a-z0-9_]{2,}'),
    re.compile(r'\bSDAA_[A-Z][A-Z0-9_]{2,}\b'),         # env vars / macros
    re.compile(r'\b[A-Z][A-Z0-9_]{5,}\b'),              # ALL_CAPS enums / error codes
    re.compile(r'\b__[a-z][a-z0-9_]+__\b'),             # __global__ etc
]

# Tokens that are noise even if matched.
STOP = {
    'SDAARUNTIME', 'TECORIGIN', 'TECOSMI', 'COPYRIGHT', 'VERSION',
}


def extract_ids(text: str) -> set[str]:
    ids: set[str] = set()
    for pat in PATTERNS:
        for m in pat.findall(text):
            tok = m if isinstance(m, str) else m[0]
            if tok and tok.upper() not in STOP and len(tok) >= 4:
                ids.add(tok)
    return ids


def read_slice(raw_path: Path, start: int, end: int) -> str:
    lines = raw_path.read_text(encoding='utf-8', errors='ignore').splitlines()
    return '\n'.join(lines[start - 1:end])


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--worklist', default=DEFAULT_WORKLIST)
    ap.add_argument('--details', action='store_true')
    ap.add_argument('--threshold', type=float, default=0.95,
                    help='min fraction of a document\'s raw identifiers that must appear across its pages')
    args = ap.parse_args()

    wl = json.loads(Path(args.worklist).read_text(encoding='utf-8'))
    # Aggregate per parent document: union of all part pages vs the full raw text.
    # Document-level granularity avoids slice-boundary false positives.
    by_doc: dict[str, dict] = {}
    for it in wl:
        d = by_doc.setdefault(it['docid'], {'raw_path': Path(it['raw_path']), 'parts': []})
        d['parts'].append(it)

    total_missing = 0
    failed_docs = 0
    report = []
    for docid, info in sorted(by_doc.items()):
        raw_text = info['raw_path'].read_text(encoding='utf-8', errors='ignore')
        raw_ids = extract_ids(raw_text)
        # drop noise: pure ALL_CAPS test-suffix and truncated artifacts handled by union below
        page_blob_parts = []
        missing_pages = []
        for it in info['parts']:
            op = Path(it['out_path'])
            if op.exists():
                page_blob_parts.append(op.read_text(encoding='utf-8', errors='ignore'))
            else:
                missing_pages.append(it['part_id'])
        page_blob = '\n'.join(page_blob_parts)
        page_ids = extract_ids(page_blob)
        missing = sorted(t for t in raw_ids if t not in page_ids and t not in page_blob)
        coverage = 1.0 - len(missing) / len(raw_ids) if raw_ids else 1.0
        total_missing += len(missing)
        status = 'ok'
        if missing_pages:
            status = 'INCOMPLETE'
        elif coverage < args.threshold:
            status = 'LOW'
        if status != 'ok':
            failed_docs += 1
        report.append((docid, status, coverage, missing, missing_pages))

    for docid, status, cov, missing, missing_pages in report:
        flag = '  ' if status == 'ok' else '!!'
        print(f'{flag} [{status:>10}] {docid:<44} coverage={cov:5.1%} missing_ids={len(missing)} missing_pages={len(missing_pages)}')
        if missing_pages:
            print('        missing pages: ' + ', '.join(missing_pages))
        if args.details and missing:
            print('        missing ids: ' + ', '.join(missing[:50]) + ('...' if len(missing) > 50 else ''))

    print(f'\ndocs={len(report)}, total_missing_ids={total_missing}, failed_docs={failed_docs}')
    sys.exit(1 if failed_docs else 0)


if __name__ == '__main__':
    main()
