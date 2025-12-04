alter table {schema}.infra_trans_rodov add column if not exists valor_tipo_servico varchar(255);

alter table {schema}.infra_trans_rodov add column if not exists import_ref varchar(255);

insert into {schema}.lig_valor_tipo_servico_infra_trans_rodov(infra_trans_rodov_id, valor_tipo_servico_id)
select identificador as infra_trans_rodov_id, trim(unnest(regexp_split_to_array(valor_tipo_servico, ','))) as valor_tipo_servico_id from {schema}.infra_trans_rodov;
