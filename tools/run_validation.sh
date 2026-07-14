#!/usr/bin/bash

schema="public"

version="v2.0.1"
ndd1=false
args='{
    "rg1_ndd1": 4,
    "rg1_ndd2": 20,
    "re3_2_ndd1": 2,
    "re3_2_ndd2": 5,
    "re3_3_ndd1": 100,
    "re3_3_ndd2": 500,
    "re7_1_ndd1": 2000,
    "re7_1_ndd2": 5000,
    "re7_8_ndd1": 100,
    "re7_8_ndd2": 1000,
    "desvio_3D": '

if $ndd1; then
    args="${args}0.028
}"
else
    args="${args}0.141
}"
fi

file_rules="../plugin/validation_rules.sql"
file_setup="../plugin/validation_setup.sql"
file_reset="../plugin/validation_reset.sql"

reset=false
skip=false
report=false
report_title=""
output_dir=""

# parse bash script arguments, multiple flags allowed (-r reset, -s skip validated rules)
while getopts "rspo:t:" opt; do
    case "$opt" in
        r) reset=true ;;
        s) skip=true ;;
        p) report=true ;;
        o) output_dir="$OPTARG" ;;
        t) report_title="$OPTARG" ;;
    esac
done
shift $((OPTIND - 1))

if [ -z "${1:-}" ]; then
    echo "Erro: falta o nome do serviço PG." >&2
    echo "Uso: $0 [-r] [-s] [-p] [-o DIR] [-t TITLE] <pg_service>" >&2
    exit 1
fi

service="$1"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if $reset; then
    echo "Resetting validation and errors schema"
    psql service=$service -f $file_reset
    echo "Validation and errors schema reset"
fi

# read file in ../plugin/validation_rules.sql and apply substitutions for {schema}
# with -s, keep existing rules/totals; after -r the schema is empty so rules must be loaded
if $reset || ! $skip; then
    sed "s/{schema}/$schema/g" $file_rules > $file_rules.tmp
    psql service=$service -f $file_rules.tmp
    rm $file_rules.tmp
    echo "Validation rules created"
else
    echo "Skipping validation rules reload (-s); using existing rule totals"
fi

# read file in ../plugin/validation_setup.sql and apply substitutions for {schema}
sed "s/{schema}/$schema/g" $file_setup > $file_setup.tmp
psql service=$service -f $file_setup.tmp
rm $file_setup.tmp
echo "Validation setup applied"

psql service=$service -c "select validation.create_missing_gist_indexes()"

psql service=$service -c "VACUUM (VERBOSE, ANALYZE);"

export_constraints="$script_dir/reports/export_constraint_errors.py"
if [ -f "$export_constraints" ]; then
    constraint_tmp=$(mktemp /tmp/constraint_errors_XXXXXX.csv)
    echo "$(date +%Y-%m-%d\ %H:%M:%S) Checking schema constraints"
    if python3 "$export_constraints" \
        --service "$service" \
        --version "$version" \
        --output "$constraint_tmp"; then
        constraint_count=$(($(wc -l < "$constraint_tmp") - 1))
        if [ "$constraint_count" -gt 0 ]; then
            echo "Warning: $constraint_count constraint error(s) found (see $constraint_tmp)"
        else
            rm -f "$constraint_tmp"
        fi
    else
        echo "Warning: constraint validation failed" >&2
        rm -f "$constraint_tmp"
    fi
else
    echo "Warning: export_constraint_errors.py not found; skipping constraint check"
fi

# get rows in validation.rules for version and call do_validation for each row
rows=$(psql service=$service -t -A -F '|' -c "SELECT code, total FROM validation.rules WHERE '$version' = any(versoes) order by dorder;")

total=0
for row in $rows; do
    code=$(echo $row | cut -d '|' -f 1)
    total=$(echo $row | cut -d '|' -f 2)

    # if code does not start with rg, re, or pq then continue
    if [[ ! $code =~ ^(rg|re|pq) ]]; then
        continue
    fi

    # if total is a number and skip is true then skip
    if [[ $total =~ ^[0-9]+$ && $skip == true ]]; then
        echo "$(date +%Y-%m-%d\ %H:%M:%S) Skipping $code (total: $total)"
        continue
    fi

    echo "$(date +%Y-%m-%d\ %H:%M:%S) Running validation for $code"
    psql service=$service -c "CALL validation.do_validation($ndd1, '$version', '$code', '$args');"

    total=$((total + 1))
done
echo "Total validations: $total"

# --- report generation (optional, -p) ---
if $report; then
    report_dir="$script_dir/reports"
    generate_report="$report_dir/generate_report.py"

    if $ndd1; then
        ndd_label="NdD1"
        ndd_digit="1"
    else
        ndd_label="NdD2"
        ndd_digit="2"
    fi

    if [ -z "$output_dir" ]; then
        output_dir="$script_dir/reports/$(date +%Y%m%d_%H%M%S)"
    fi
    mkdir -p "$output_dir/data"

    echo "$(date +%Y-%m-%d\ %H:%M:%S) Running pre-report queries"
    psql service=$service -c "SELECT validation.check_geometries_extensions();" >/dev/null 2>&1 || true
    psql service=$service -c "SELECT validation.atualiza_consistencia_valores_report('${ndd_digit}', '${version}');"
    psql service=$service -c "ANALYZE errors;" >/dev/null 2>&1 || true

    report_timestamp="$(date +%Y-%m-%dT%H:%M:%S)"
    report_footnote="${report_timestamp} | Recart ${version} | ${ndd_label}"
    report_database="$(psql service=$service -t -A -c "SELECT current_database();")"

    REPORT_TITLE="Relatório Validação Automática" \
    SECTION_TITLE="$report_title" \
    FOOTNOTE="$report_footnote" \
    VERSION="$version" \
    NDD="$ndd_label" \
    SCHEMA="$schema" \
    SERVICE="$service" \
    DATABASE="$report_database" \
    TIMESTAMP="$report_timestamp" \
    python3 - <<'PY' > "$output_dir/data/metadata.json"
import json, os
print(json.dumps({
    "timestamp": os.environ["TIMESTAMP"],
    "footnote": os.environ["FOOTNOTE"],
    "version": os.environ["VERSION"],
    "ndd": os.environ["NDD"],
    "schema": os.environ["SCHEMA"],
    "service": os.environ["SERVICE"],
    "database": os.environ["DATABASE"],
    "report_title": os.environ["REPORT_TITLE"],
    "section_title": os.environ["SECTION_TITLE"],
}, ensure_ascii=False, indent=2))
PY

    export_report_csv() {
        echo "$1" > "$2"
        psql service=$service -t -A -F '|' -c "$3" >> "$2" 2>/dev/null || true
    }

    export_report_csv "code|name|total|good|bad" "$output_dir/data/summary.csv" \
        "SELECT code, name, COALESCE(total, 0), COALESCE(good, 0), COALESCE(bad, 0) FROM validation.rules WHERE '${version}' = ANY(versoes) ORDER BY dorder ASC;"

    export_report_csv "objeto1|objeto2|codigo1|codigo2|n_live_tup" "$output_dir/data/errors_by_table.csv" \
        "SELECT (REGEXP_MATCHES(relname, '([a-z_0-9]+)_rg|([a-z_0-9]+)_re'))[1] AS objeto1, (REGEXP_MATCHES(relname, '([a-z_0-9]+)_rg|([a-z_0-9]+)_re'))[2] AS objeto2, (REGEXP_MATCHES(relname, '[a-z_0-9]+_(rg[0-9_]*)|[a-z_0-9]+_(re[0-9_]*)'))[1] AS codigo1, (REGEXP_MATCHES(relname, '[a-z_0-9]+_(rg[0-9_]*)|[a-z_0-9]+_(re[0-9_]*)'))[2] AS codigo2, n_live_tup FROM pg_stat_user_tables WHERE schemaname = 'errors' AND n_live_tup > 0 ORDER BY codigo1, codigo2, n_live_tup DESC;"

    export_report_csv "tabela|atributo|valor|numero" "$output_dir/data/domain_errors.csv" \
        "SELECT tabela, atributo, valor, numero FROM validation.consistencia_valores_report ORDER BY tabela, atributo, valor;"

    export_report_csv "tabela|identificador|motivo" "$output_dir/data/invalid_geometries.csv" \
        "SELECT tabela, identificador::text, COALESCE(motivo, '') FROM validation.geometrias_invalidas_report ORDER BY tabela, identificador;"

    export_report_csv "rule_code|rule_name|entidade|numero" "$output_dir/data/errors_3d.csv" \
        "WITH normalized AS (
            SELECT
                COALESCE(
                    e.rule_code,
                    CASE
                        WHEN e.entidade = 'curva_de_nivel' AND e.motivo = 'Ponto fora da linha da área de trabalho' THEN 're3_1_1'
                        WHEN e.entidade = 'curva_de_nivel' AND e.motivo LIKE 'discrepância no valor de z:%' THEN 're3_1_2'
                        WHEN e.entidade = 'curso_de_agua_eixo' AND e.motivo = 'ponto de inflexão' THEN 're4_5_2'
                    END
                ) AS rule_code,
                e.entidade
            FROM errors.erros_3d e
        )
        SELECT
            n.rule_code,
            (SELECT r.name FROM validation.rules r WHERE r.code = n.rule_code AND '${version}' = ANY(r.versoes) LIMIT 1),
            n.entidade,
            COUNT(*)::text
        FROM normalized n
        WHERE n.rule_code IS NOT NULL
        GROUP BY n.rule_code, n.entidade
        ORDER BY n.rule_code, n.entidade;"

    export_value_lists="$report_dir/export_value_list_errors.py"
    export_structure="$report_dir/export_structure_errors.py"
    export_constraints="$report_dir/export_constraint_errors.py"
    if [ -f "$export_structure" ]; then
        python3 "$export_structure" \
            --service "$service" \
            --version "$version" \
            --output "$output_dir/data/structure_errors.csv"
    else
        echo "tabela|campos_esperados" > "$output_dir/data/structure_errors.csv"
    fi
    if [ -f "$export_value_lists" ]; then
        python3 "$export_value_lists" \
            --service "$service" \
            --version "$version" \
            --output "$output_dir/data/value_list_errors.csv"
    else
        echo "tabela|identificador|descricao" > "$output_dir/data/value_list_errors.csv"
    fi
    if [ -f "$export_constraints" ]; then
        python3 "$export_constraints" \
            --service "$service" \
            --version "$version" \
            --output "$output_dir/data/constraint_errors.csv"
    else
        echo "tabela|tipo|detalhe|estado" > "$output_dir/data/constraint_errors.csv"
    fi

    echo "$(date +%Y-%m-%d\ %H:%M:%S) Report data exported to $output_dir/data"

    if [ ! -f "$generate_report" ]; then
        echo "Erro: generate_report.py not found at $generate_report" >&2
        exit 1
    fi
    if ! python3 -c "import reportlab" 2>/dev/null; then
        echo "Erro: reportlab não instalado. Execute: pip install -r $report_dir/requirements.txt" >&2
        exit 1
    fi

    python3 "$generate_report" --input-dir "$output_dir/data" --output "$output_dir/relatorio_validacao.pdf"
    echo "$(date +%Y-%m-%d\ %H:%M:%S) PDF report: $output_dir/relatorio_validacao.pdf"
fi
