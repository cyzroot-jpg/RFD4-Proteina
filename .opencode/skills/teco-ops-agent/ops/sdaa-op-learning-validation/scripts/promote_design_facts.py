#!/usr/bin/env python3
"""Promote verified stage facts into design.json/design.md.

This is the explicit name for the design-fact promotion operation. The legacy
promote_stage_result.py entry point remains available for compatibility.
"""

from promote_stage_result import main


if __name__ == "__main__":
    raise SystemExit(main())
