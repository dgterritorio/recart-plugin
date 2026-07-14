#!/usr/bin/env python3
"""Build validation PDF from CSV exports produced by run_validation.sh."""

import argparse
import csv
import json
import sys
from collections import defaultdict
from pathlib import Path
from xml.sax.saxutils import escape

try:
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4, landscape
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import mm
    from reportlab.platypus import (
        PageBreak,
        Paragraph,
        SimpleDocTemplate,
        Spacer,
        Table,
        TableStyle,
    )
except ImportError:
    print("Error: reportlab is required. Install with: pip install reportlab", file=sys.stderr)
    sys.exit(1)


def read_pipe_csv(path: Path):
    if not path.is_file():
        return []
    with path.open(encoding="utf-8", newline="") as f:
        reader = csv.reader(f, delimiter="|")
        rows = list(reader)
    if not rows:
        return []
    header = rows[0]
    if header and (header[0].startswith("code") or header[0] in ("tabela", "objeto1", "rule_code")):
        return [dict(zip(header, row)) for row in rows[1:] if any(cell.strip() for cell in row)]
    return [row for row in rows if any(cell.strip() for cell in row)]


def read_summary(path: Path):
    rows = read_pipe_csv(path)
    result = []
    for row in rows:
        if isinstance(row, dict):
            result.append([
                row.get("code", ""),
                row.get("name", ""),
                row.get("total", ""),
                row.get("good", ""),
                row.get("bad", ""),
            ])
        elif len(row) >= 5:
            result.append(row[:5])
    return result


def rule_name_map(summary_rows):
    return {r[0]: r[1] for r in summary_rows if r and r[0]}


def load_display_list(script_dir: Path):
    path = script_dir / "displayList.json"
    if path.is_file():
        with path.open(encoding="utf-8") as f:
            return json.load(f)
    return {}


def theme_for_entity(display_list, entity):
    if not entity:
        return "Outros"
    return display_list.get(entity, entity)


def build_theme_errors(error_rows, summary_names, display_list):
    themes = defaultdict(list)
    for row in error_rows:
        if isinstance(row, dict):
            o1 = row.get("objeto1") or ""
            o2 = row.get("objeto2") or ""
            c1 = row.get("codigo1") or ""
            c2 = row.get("codigo2") or ""
            count = row.get("n_live_tup") or row.get("error_count") or "0"
        else:
            o1, o2, c1, c2, count = (row + ["", "", "", "", "0"])[:5]

        if o1:
            slayer = o1
            code = c1
        elif o2:
            slayer = o2
            code = c2
        else:
            continue

        theme = theme_for_entity(display_list, slayer)
        name = summary_names.get(code, code)
        themes[theme].append([code, name, slayer, count])

    return dict(sorted(themes.items()))


def make_table(data, col_widths=None, table_styles=None):
    if not data:
        return Paragraph("<i>Sem registos.</i>", getSampleStyleSheet()["Normal"])

    if table_styles is None:
        table_styles = getSampleStyleSheet()

    header_style = ParagraphStyle(
        "TableHeader",
        parent=table_styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=8,
        leading=10,
        textColor=colors.white,
    )
    body_style = ParagraphStyle(
        "TableBody",
        parent=table_styles["Normal"],
        fontName="Helvetica",
        fontSize=8,
        leading=10,
        wordWrap="LTR",
    )

    wrapped = []
    for row_idx, row in enumerate(data):
        cell_style = header_style if row_idx == 0 else body_style
        wrapped.append([
            Paragraph(escape(str(cell if cell is not None else "")), cell_style)
            for cell in row
        ])

    table = Table(wrapped, colWidths=col_widths, repeatRows=1, splitByRow=1)
    table.setStyle(
        TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#4472C4")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 8),
            ("GRID", (0, 0), (-1, -1), 0.25, colors.grey),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("LEFTPADDING", (0, 0), (-1, -1), 3),
            ("RIGHTPADDING", (0, 0), (-1, -1), 3),
            ("TOPPADDING", (0, 0), (-1, -1), 3),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#EEF2FA")]),
        ])
    )
    return table


def chunk_rows(rows, size):
    for i in range(0, len(rows), size):
        yield rows[i:i + size]


def build_pdf(input_dir: Path, output_path: Path, metadata: dict):
    styles = getSampleStyleSheet()
    title_style = styles["Title"]
    heading_style = styles["Heading2"]

    footnote = metadata.get("footnote", "")
    report_title = metadata.get("report_title") or "Relatório Validação Automática"

    summary = read_summary(input_dir / "summary.csv")
    summary_names = rule_name_map(summary)

    structure_rows = read_pipe_csv(input_dir / "structure_errors.csv")
    constraint_rows = read_pipe_csv(input_dir / "constraint_errors.csv")
    value_list_rows = read_pipe_csv(input_dir / "value_list_errors.csv")
    domain_rows = read_pipe_csv(input_dir / "domain_errors.csv")
    geom_rows = read_pipe_csv(input_dir / "invalid_geometries.csv")
    errors_3d_rows = read_pipe_csv(input_dir / "errors_3d.csv")
    error_rows = read_pipe_csv(input_dir / "errors_by_table.csv")
    display_list = load_display_list(Path(__file__).resolve().parent)
    themes = build_theme_errors(error_rows, summary_names, display_list)

    doc = SimpleDocTemplate(
        str(output_path),
        pagesize=landscape(A4),
        leftMargin=12 * mm,
        rightMargin=12 * mm,
        topMargin=12 * mm,
        bottomMargin=15 * mm,
        title=report_title,
    )

    story = []
    story.append(Paragraph(report_title, title_style))
    if metadata.get("section_title"):
        story.append(Paragraph(metadata["section_title"], heading_style))
    story.append(Spacer(1, 6 * mm))
    story.append(Paragraph("Sumário", heading_style))
    story.append(Spacer(1, 3 * mm))

    summary_table = [["Código", "Regra", "Elementos", "Corretos", "Erros"]] + summary
    story.append(make_table(summary_table, [25 * mm, 110 * mm, 25 * mm, 25 * mm, 20 * mm], styles))
    story.append(Spacer(1, 4 * mm))

    if structure_rows:
        story.append(PageBreak())
        story.append(Paragraph("Erros de Estrutura da Base de Dados", heading_style))
        story.append(Spacer(1, 3 * mm))
        data = [["Tabela", "Campos esperados"]]
        for row in structure_rows:
            if isinstance(row, dict):
                data.append([
                    row.get("tabela", ""),
                    row.get("campos_esperados", ""),
                ])
        for chunk in chunk_rows(data[1:], 30):
            story.append(make_table([data[0]] + chunk, [45 * mm, 155 * mm], styles))
            story.append(Spacer(1, 4 * mm))

    if constraint_rows:
        story.append(PageBreak())
        story.append(Paragraph("Erros de Constraints da Base de Dados", heading_style))
        story.append(Spacer(1, 3 * mm))
        data = [["Tabela", "Tipo", "Detalhe", "Estado"]]
        for row in constraint_rows:
            if isinstance(row, dict):
                data.append([
                    row.get("tabela", ""),
                    row.get("tipo", ""),
                    row.get("detalhe", ""),
                    row.get("estado", ""),
                ])
        for chunk in chunk_rows(data[1:], 30):
            story.append(make_table([data[0]] + chunk, [40 * mm, 30 * mm, 90 * mm, 30 * mm], styles))
            story.append(Spacer(1, 4 * mm))

    if value_list_rows:
        story.append(PageBreak())
        story.append(Paragraph("Erros nas Listas de Valores", heading_style))
        story.append(Spacer(1, 3 * mm))
        data = [["Tabela", "Identificador esperado", "Descrição esperada"]]
        for row in value_list_rows:
            if isinstance(row, dict):
                data.append([
                    row.get("tabela", ""),
                    row.get("identificador", ""),
                    row.get("descricao", ""),
                ])
        for chunk in chunk_rows(data[1:], 30):
            story.append(make_table([data[0]] + chunk, [45 * mm, 35 * mm, 130 * mm], styles))
            story.append(Spacer(1, 4 * mm))

    if domain_rows:
        story.append(PageBreak())
        story.append(Paragraph("Erros de Consistência de Domínio", heading_style))
        story.append(Spacer(1, 3 * mm))
        data = [["Objeto", "Atributo", "Erro", "Número de Ocorrências"]]
        for row in domain_rows:
            if isinstance(row, dict):
                data.append([
                    row.get("tabela", ""),
                    row.get("atributo", ""),
                    row.get("valor", ""),
                    row.get("numero", ""),
                ])
        story.append(make_table(data, [45 * mm, 45 * mm, 35 * mm, 40 * mm], styles))

    if geom_rows:
        story.append(PageBreak())
        story.append(Paragraph("Geometrias inválidas", heading_style))
        story.append(Spacer(1, 3 * mm))
        data = [["Tabela", "Identificador", "Motivo"]]
        for row in geom_rows:
            if isinstance(row, dict):
                data.append([
                    row.get("tabela", ""),
                    row.get("identificador", ""),
                    row.get("motivo", ""),
                ])
        for chunk in chunk_rows(data[1:], 30):
            story.append(make_table([data[0]] + chunk, [45 * mm, 55 * mm, 120 * mm], styles))
            story.append(Spacer(1, 4 * mm))

    if errors_3d_rows:
        story.append(PageBreak())
        story.append(Paragraph("Erros 3D", heading_style))
        story.append(Spacer(1, 3 * mm))
        data = [["Código", "Regra", "Objeto", "Erros"]]
        for row in errors_3d_rows:
            if isinstance(row, dict):
                data.append([
                    row.get("rule_code", ""),
                    row.get("rule_name", ""),
                    row.get("entidade", ""),
                    row.get("numero", ""),
                ])
        story.append(make_table(data, [25 * mm, 110 * mm, 45 * mm, 20 * mm], styles))
        story.append(Spacer(1, 4 * mm))

    if themes:
        for theme, rows in themes.items():
            story.append(PageBreak())
            story.append(Paragraph(f"Erros no Tema {theme}", heading_style))
            story.append(Spacer(1, 3 * mm))
            data = [["Código", "Regra", "Objeto", "Erros"]] + rows
            for chunk in chunk_rows(data[1:], 30):
                story.append(make_table([data[0]] + chunk, [25 * mm, 110 * mm, 45 * mm, 20 * mm], styles))
                story.append(Spacer(1, 4 * mm))

    def draw_footer(canvas, _doc):
        canvas.saveState()
        canvas.setFont("Helvetica", 8)
        canvas.drawString(12 * mm, 8 * mm, footnote)
        canvas.restoreState()

    doc.build(story, onFirstPage=draw_footer, onLaterPages=draw_footer)
    print(f"Report written to {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Generate validation PDF from exported CSV data")
    parser.add_argument("--input-dir", required=True, help="Directory with exported CSV and metadata.json")
    parser.add_argument("--output", required=True, help="Output PDF path")
    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    metadata_path = input_dir / "metadata.json"
    metadata = {}
    if metadata_path.is_file():
        with metadata_path.open(encoding="utf-8") as f:
            metadata = json.load(f)

    build_pdf(input_dir, Path(args.output), metadata)


if __name__ == "__main__":
    main()
