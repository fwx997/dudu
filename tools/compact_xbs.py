#!/usr/bin/env python3
"""Safely compact an XBS source bundle from independent validation reports.

The original bundle is copied to a backup before writing the compacted file.
Only hard failures are removed by default. Empty results, timeouts and 403/429
responses remain because one probe cannot prove that a source is unusable.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import shutil
from pathlib import Path


HARD_CLASSIFICATIONS = {
    "hard_invalid",
    "hard_failure",
    "missing_requestInfo",
    "request_function_or_javascript_only",
}


def load_codec():
    root = Path(__file__).resolve().parents[2]
    path = root / "_tools" / "decode_xbs.py"
    spec = importlib.util.spec_from_file_location("xsg_decode_xbs", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load XBS codec: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_bundle(path: Path) -> dict:
    codec = load_codec()
    data = codec.xbs2json_bytes(path.read_bytes())
    value = json.loads(data.decode("utf-8"))
    if not isinstance(value, dict):
        raise ValueError("XBS top-level value is not an object")
    return value


def load_reports(paths: list[Path]) -> dict[str, list[dict]]:
    reports: dict[str, list[dict]] = {}
    for path in paths:
        with path.open(encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                row = json.loads(line)
                alias = str(row.get("alias", ""))
                if alias:
                    reports.setdefault(alias, []).append(row)
    return reports


def compact(
    input_path: Path,
    output_path: Path,
    reports: list[Path],
    backup_path: Path,
    enabled_only: bool,
) -> dict:
    sources = load_bundle(input_path)
    validation = load_reports(reports)
    removed: list[dict] = []
    kept: dict = {}
    for alias, config in sources.items():
        rows = validation.get(alias, [])
        enabled = config.get("enable")
        is_enabled = (
            (isinstance(enabled, bool) and enabled)
            or (isinstance(enabled, int) and enabled != 0)
            or (isinstance(enabled, str) and enabled.lower() in {"1", "true"})
        )
        hard_reasons = set()
        for row in rows:
            classification = str(row.get("classification", row.get("refined_category", "")))
            status = str(row.get("status", "")).lower()
            http_status = row.get("http_status")
            if classification in HARD_CLASSIFICATIONS:
                hard_reasons.add(classification)
            if status == "http_error" and http_status in {404, 410}:
                hard_reasons.add(f"http_{http_status}")
        if (enabled_only and not is_enabled) or hard_reasons:
            removed.append({
                "alias": alias,
                "sourceName": config.get("sourceName", alias),
                "reasons": sorted(hard_reasons) if hard_reasons else ["disabled"],
            })
        else:
            kept[alias] = config

    shutil.copy2(input_path, backup_path)
    codec = load_codec()
    payload = json.dumps(kept, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    output_path.write_bytes(codec.json2xbs_bytes(payload))
    report = {
        "input": str(input_path),
        "output": str(output_path),
        "backup": str(backup_path),
        "input_count": len(sources),
        "output_count": len(kept),
        "removed_count": len(removed),
        "enabled_only": enabled_only,
        "unreported_count": sum(alias not in validation for alias in sources),
        "removed": removed,
    }
    output_path.with_suffix(".report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--backup", type=Path, required=True)
    parser.add_argument("--report", type=Path, action="append", default=[])
    parser.add_argument("--enabled-only", action="store_true")
    args = parser.parse_args()
    report = compact(args.input, args.output, args.report, args.backup, args.enabled_only)
    print(json.dumps({k: report[k] for k in report if k != "removed"}, ensure_ascii=False))


if __name__ == "__main__":
    main()
