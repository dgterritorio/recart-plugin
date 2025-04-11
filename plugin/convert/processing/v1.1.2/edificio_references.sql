alter table {schema}.edificio add column if not exists nome varchar(255);
alter table {schema}.edificio add column if not exists numero_policia varchar(255);
alter table {schema}.edificio add column if not exists valor_utilizacao_atual varchar(255);

insert into {schema}.nome_edificio(edificio_id, nome)
select identificador as edificio_id, nome from {schema}.edificio where nome is not null;

insert into {schema}.numero_policia_edificio(edificio_id, numero_policia)
select identificador as edificio_id, numero_policia from {schema}.edificio where numero_policia is not null;

alter table {schema}.equip_util_coletiva add column if not exists valor_tipo_equipamento_coletivo varchar(255);

select {schema}.insert_references('{schema}', '{dtable}');

insert into {schema}.lig_valor_utilizacao_atual_edificio(edificio_id, valor_utilizacao_atual_id)
select identificador as edificio_id, trim(unnest(regexp_split_to_array(valor_utilizacao_atual, ','))) as valor_utilizacao_atual_id from {dtable};
