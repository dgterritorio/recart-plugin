#!/usr/bin/env python3
"""Export value-list validation errors (mirrors plugin/validation_dialog.py)."""

import argparse
import csv
import json
import re
import subprocess
import sys
from pathlib import Path


def sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def run_query(service: str, query: str) -> str | None:
    result = subprocess.run(
        ["psql", f"service={service}", "-t", "-A", "-c", query],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        return None
    return result.stdout.strip()


def normalize_list_name(name: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()


def expected_rows(lista: dict) -> str:
    rows = [
        {
            "identificador": val["Valores"],
            "descricao": val["Descrição"].replace("'", "''''"),
        }
        for val in lista["valores"]
    ]
    return json.dumps(rows, ensure_ascii=False)


def collect_errors(service: str, version: str, plugin_dir: Path) -> list[list[str]]:
    base_dir = plugin_dir / "convert" / "base" / version
    if not base_dir.is_dir():
        print(f"Error: schema base not found at {base_dir}", file=sys.stderr)
        sys.exit(1)

    validated: dict[str, bool] = {}
    errors: list[list[str]] = []

    for bfile in sorted(base_dir.glob("*.json")):
        if bfile.name == "relacoes.json":
            continue

        with bfile.open(encoding="utf-8") as fh:
            bfp = json.load(fh)

        objecto = bfp["objecto"]
        for lista in objecto.get("listas de códigos", []):
            ltnome = normalize_list_name(lista["nome"])
            if ltnome in validated:
                continue
            validated[ltnome] = True

            valores = expected_rows(lista)
            query = (
                "SELECT validation.validate_table_rows("
                f"{sql_literal(ltnome)}, {sql_literal(valores)});"
            )
            raw = run_query(service, query)
            if raw is None:
                continue

            try:
                parsed = json.loads(raw) if raw else []
            except json.JSONDecodeError:
                print(f"Warning: invalid JSON from validate_table_rows for {ltnome}: {raw!r}", file=sys.stderr)
                continue

            if not parsed:
                continue

            for err in parsed:
                errors.append([ltnome, err.get("identificador", ""), err.get("descricao", "")])

    return errors


def write_csv(path: Path, rows: list[list[str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh, delimiter="|")
        writer.writerow(["tabela", "identificador", "descricao"])
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description="Export value-list validation errors to CSV")
    parser.add_argument("--service", required=True, help="PostgreSQL service name (PGSERVICE)")
    parser.add_argument("--version", required=True, help="CartTop version, e.g. v2.0.1")
    parser.add_argument("--output", required=True, help="Output CSV path")
    parser.add_argument(
        "--plugin-dir",
        default=str(Path(__file__).resolve().parents[2] / "plugin"),
        help="Path to plugin directory (default: repo plugin/)",
    )
    args = parser.parse_args()

    errors = collect_errors(args.service, args.version, Path(args.plugin_dir))
    write_csv(Path(args.output), errors)
    print(f"Exported {len(errors)} value-list error(s) to {args.output}")


if __name__ == "__main__":
    main()
