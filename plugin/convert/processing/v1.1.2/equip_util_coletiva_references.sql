alter table {schema}.equip_util_coletiva add column if not exists valor_tipo_equipamento_coletivo varchar(255);

insert into {schema}.lig_valor_tipo_equipamento_coletivo_equip_util_coletiva(equip_util_coletiva_id, valor_tipo_equipamento_coletivo_id)
select identificador as equip_util_coletiva_id, trim(unnest(regexp_split_to_array(valor_tipo_equipamento_coletivo, ','))) as valor_tipo_equipamento_coletivo_id from {dtable};
