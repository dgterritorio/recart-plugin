alter table {schema}.infra_trans_rodov add column if not exists valor_tipo_servico varchar(255);

select {schema}.insert_references('{schema}', '{dtable}');

insert into {schema}.lig_valor_tipo_servico_infra_trans_rodov(infra_trans_rodov_id, valor_tipo_servico_id)
select identificador as infra_trans_rodov_id, trim(unnest(regexp_split_to_array(valor_tipo_servico, ','))) as valor_tipo_servico_id from {schema}.infra_trans_rodov where identificador not in (select infra_trans_rodov_id from {schema}.lig_valor_tipo_servico_infra_trans_rodov);
