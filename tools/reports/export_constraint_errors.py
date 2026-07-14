#!/usr/bin/env python3
"""Export database constraint validation errors via validation.validate_schema_constraints()."""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from pathlib import Path


def sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def run_query(service: str, query: str) -> list[list[str]] | None:
    result = subprocess.run(
        ["psql", f"service={service}", "-t", "-A", "-F", "|", "-c", query],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        return None

    rows: list[list[str]] = []
    for line in result.stdout.splitlines():
        if not line.strip():
            continue
        rows.append(line.split("|"))
    return rows


def load_manifest(version: str, plugin_dir: Path) -> dict:
    path = plugin_dir / "convert" / "constraints" / f"{version}.json"
    if not path.is_file():
        print(f"Error: constraints manifest not found at {path}", file=sys.stderr)
        sys.exit(1)
    return json.loads(path.read_text(encoding="utf-8"))


def collect_errors(service: str, manifest: dict) -> list[list[str]]:
    manifest_json = json.dumps(manifest, ensure_ascii=False)
    query = (
        "SELECT validation.validate_schema_constraints("
        f"{sql_literal(manifest_json)}::jsonb);"
    )
    rows = run_query(service, query)
    if rows is None or not rows:
        sys.exit(1)

    raw = rows[0][0] if rows[0] else "[]"
    errors_data = json.loads(raw) if raw else []
    return [
        [
            item.get("tabela", ""),
            item.get("tipo", ""),
            item.get("detalhe", ""),
            item.get("estado", ""),
        ]
        for item in errors_data
    ]


def write_csv(path: Path, rows: list[list[str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh, delimiter="|")
        writer.writerow(["tabela", "tipo", "detalhe", "estado"])
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Export database constraint validation errors to CSV"
    )
    parser.add_argument("--service", required=True, help="PostgreSQL service name (PGSERVICE)")
    parser.add_argument("--version", required=True, help="CartTop version, e.g. v2.0.1")
    parser.add_argument("--output", required=True, help="Output CSV path")
    parser.add_argument(
        "--plugin-dir",
        default=str(Path(__file__).resolve().parents[2] / "plugin"),
        help="Path to plugin directory (default: repo plugin/)",
    )
    args = parser.parse_args()

    manifest = load_manifest(args.version, Path(args.plugin_dir))
    errors = collect_errors(args.service, manifest)
    write_csv(Path(args.output), errors)
    print(f"Exported {len(errors)} constraint error(s) to {args.output}")


if __name__ == "__main__":
    main()
