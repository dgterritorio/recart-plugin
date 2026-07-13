#!/usr/bin/env python3
"""Export table column structure errors (mirrors plugin/validation_dialog.py)."""

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


def normalize_object_name(name: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z][a-z])|(?=[A-Z]{3,})", "_", name).lower()


def normalize_attribute_name(name: str) -> str:
    name = re.sub(r"iD", "id", name)
    name = re.sub(r"LAS", "Las", name)
    name = re.sub(r"valorElementoAssociadoPGQ", "valor_elemento_associado_pgq", name)
    name = re.sub(r"XY", "Xy", name)
    name = re.sub(r"datahomologacao", "data_homologacao", name)
    name = re.sub(r"nomeDoProdutor", "nome_produtor", name)
    name = re.sub(r"nomeDoProprietario", "nome_proprietario", name)
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()


def expected_columns(objecto: dict) -> list[str]:
    columns = []
    for attr in objecto.get("Atributos", []):
        if attr.get("Multip.") in ("[1..*]", "[0..*]"):
            continue
        columns.append(normalize_attribute_name(attr["Atributo"]))
    return columns


def collect_errors(service: str, version: str, plugin_dir: Path) -> list[list[str]]:
    base_dir = plugin_dir / "convert" / "base" / version
    if not base_dir.is_dir():
        print(f"Error: schema base not found at {base_dir}", file=sys.stderr)
        sys.exit(1)

    errors: list[list[str]] = []

    for bfile in sorted(base_dir.glob("*.json")):
        if bfile.name == "relacoes.json":
            continue

        with bfile.open(encoding="utf-8") as fh:
            bfp = json.load(fh)

        objecto = bfp["objecto"]
        table_name = normalize_object_name(objecto["objeto"])
        columns = expected_columns(objecto)
        columns_json = json.dumps(columns, ensure_ascii=False)

        query = (
            "SELECT validation.validate_table_columns("
            f"{sql_literal(table_name)}, {sql_literal(columns_json)}::jsonb);"
        )
        raw = run_query(service, query)
        if raw is None:
            continue

        if raw.lower() in ("t", "true"):
            continue

        errors.append([table_name, " | ".join(columns)])

    return errors


def write_csv(path: Path, rows: list[list[str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh, delimiter="|")
        writer.writerow(["tabela", "campos_esperados"])
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description="Export table structure validation errors to CSV")
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
    print(f"Exported {len(errors)} structure error(s) to {args.output}")


if __name__ == "__main__":
    main()
