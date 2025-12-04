alter table {schema}.seg_via_rodov add column if not exists valor_tipo_circulacao varchar(255);

alter table {schema}.seg_via_rodov add column if not exists import_ref varchar(255);

insert into {schema}.lig_valor_tipo_circulacao_seg_via_rodov(seg_via_rodov_id, valor_tipo_circulacao_id)
select identificador as seg_via_rodov_id, trim(unnest(regexp_split_to_array(valor_tipo_circulacao, ','))) as valor_tipo_circulacao_id from {dtable};
