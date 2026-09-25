#!/usr/bin/env python3
"""Build strict and runtime-capable XBS tiers from validation JSONL reports."""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path


def codec():
    root = Path(__file__).resolve().parents[2]
    spec = importlib.util.spec_from_file_location("xsg_decode_xbs", root / "_tools" / "decode_xbs.py")
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load XBS codec")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def rows(paths: list[Path]) -> dict[str, set[str]]:
    out: dict[str, set[str]] = {}
    for path in paths:
        for line in path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            row = json.loads(line)
            alias = str(row.get("alias", ""))
            if alias:
                out.setdefault(alias, set()).add(str(row.get("status", row.get("classification", ""))))
            if row.get("classification"):
                out[alias].add(str(row["classification"]))
            if row.get("refined_category"):
                out[alias].add(str(row["refined_category"]))
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--text", type=Path, action="append", required=True)
    parser.add_argument("--media", type=Path, action="append", required=True)
    parser.add_argument("--strict", type=Path, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    args = parser.parse_args()
    c = codec()
    source = json.loads(c.xbs2json_bytes(args.input.read_bytes()).decode("utf-8"))
    statuses = rows(args.text + args.media)
    strict_statuses = {"ok", "retry_ok", "success"}
    runtime_statuses = strict_statuses | {"supported_by_swift_js"}
    strict = {alias: cfg for alias, cfg in source.items() if statuses.get(alias, set()) & strict_statuses}
    runtime = {alias: cfg for alias, cfg in source.items() if statuses.get(alias, set()) & runtime_statuses}
    for target, value in [(args.strict, strict), (args.runtime, runtime)]:
        target.write_bytes(c.json2xbs_bytes(json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")))
    report = {
        "input_count": len(source),
        "strict_count": len(strict),
        "runtime_count": len(runtime),
        "strict": str(args.strict),
        "runtime": str(args.runtime),
    }
    args.strict.with_suffix(".report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
