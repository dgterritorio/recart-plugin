#!/usr/bin/bash

if [ -z "${1:-}" ]; then
    echo "Erro: falta o nome do serviço PG." >&2
    echo "Uso: $0 <pg_service>" >&2
    exit 1
fi

service="$1"
schema="public"

version="v2.0.2"
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


# parse bash script arguments, multiple flags allowed (-r to reset, -s to skip rules if total > 0)
while getopts "rs" opt; do
    case "$opt" in
        r) reset=true ;;
        s) skip=true ;;
    esac
done

if $reset; then
    echo "Resetting validation and errors schema"
    psql service=$service -f $file_reset
    echo "Validation and errors schema reset"
fi

# read file in ../plugin/validation_rules.sql and apply substitutions for {schema}
sed "s/{schema}/$schema/g" $file_rules > $file_rules.tmp
psql service=$service -f $file_rules.tmp
rm $file_rules.tmp
echo "Validation rules created"

# read file in ../plugin/validation_setup.sql and apply substitutions for {schema}
sed "s/{schema}/$schema/g" $file_setup > $file_setup.tmp
psql service=$service -f $file_setup.tmp
rm $file_setup.tmp
echo "Validation setup applied"

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
