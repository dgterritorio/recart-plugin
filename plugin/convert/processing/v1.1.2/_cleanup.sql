-- Toponimia
alter table {schema}.designacao_local drop constraint if exists valor_local_nomeado_id;
alter table {schema}.designacao_local alter column valor_local_nomeado type varchar(10) using valor_local_nomeado::varchar(10);
alter table {schema}.designacao_local add constraint valor_local_nomeado_id foreign key (valor_local_nomeado) references {schema}.valor_local_nomeado(identificador);

create index designacao_local_geom_idx ON {schema}.designacao_local using gist(geometria);

-- Ocupacao de Solos
alter table {schema}.area_agricola_florestal_mato drop constraint if exists valor_areas_agricolas_florestais_matos_id;
alter table {schema}.area_agricola_florestal_mato alter column valor_areas_agricolas_florestais_matos type varchar(10) using valor_areas_agricolas_florestais_matos::varchar(10);
alter table {schema}.area_agricola_florestal_mato add constraint valor_areas_agricolas_florestais_matos_id foreign key (valor_areas_agricolas_florestais_matos) references {schema}.valor_areas_agricolas_florestais_matos(identificador);

alter table {schema}.areas_artificializadas drop constraint if exists valor_areas_artificializadas_id;
alter table {schema}.areas_artificializadas alter column valor_areas_artificializadas type varchar(10) using valor_areas_artificializadas::varchar(10);
alter table {schema}.areas_artificializadas add constraint valor_areas_artificializadas_id foreign key (valor_areas_artificializadas) references {schema}.valor_areas_artificializadas(identificador);

alter table {schema}.areas_artificializadas drop constraint if exists localizacao_instalacao_ambiental;
alter table {schema}.areas_artificializadas add constraint localizacao_instalacao_ambiental foreign key (inst_gestao_ambiental_id) references {schema}.inst_gestao_ambiental(identificador);

alter table {schema}.areas_artificializadas drop constraint if exists localizacao_instalacao_producao;
alter table {schema}.areas_artificializadas add constraint localizacao_instalacao_producao foreign key (inst_producao_id) references {schema}.inst_producao(identificador);

alter table {schema}.areas_artificializadas drop constraint if exists localizacao_equip_util_coletiva;
alter table {schema}.areas_artificializadas add constraint localizacao_equip_util_coletiva foreign key (equip_util_coletiva_id) references {schema}.equip_util_coletiva(identificador);

create index area_agricola_florestal_mato_geom_idx ON {schema}.area_agricola_florestal_mato using gist(geometria);
create index areas_artificializadas_geom_idx ON {schema}.areas_artificializadas using gist(geometria);


-- Altimetria
alter table {schema}.linha_de_quebra drop constraint if exists valor_classifica_id;
alter table {schema}.linha_de_quebra alter column valor_classifica type varchar(10) using valor_classifica::varchar(10);
alter table {schema}.linha_de_quebra add constraint valor_classifica_id foreign key (valor_classifica) references {schema}.valor_classifica(identificador);

alter table {schema}.linha_de_quebra drop constraint if exists valor_natureza_linha_id;
alter table {schema}.linha_de_quebra alter column valor_natureza_linha type varchar(10) using valor_natureza_linha::varchar(10);
alter table {schema}.linha_de_quebra add constraint valor_natureza_linha_id foreign key (valor_natureza_linha) references {schema}.valor_natureza_linha(identificador);

alter table {schema}.ponto_cotado drop constraint if exists valor_classifica_las_id;
alter table {schema}.ponto_cotado alter column valor_classifica_las type varchar(10) using valor_classifica_las::varchar(10);
alter table {schema}.ponto_cotado add constraint valor_classifica_las_id foreign key (valor_classifica_las) references {schema}.valor_classifica_las(identificador);

alter table {schema}.curva_de_nivel drop constraint if exists valor_tipo_curva_id;
alter table {schema}.curva_de_nivel alter column valor_tipo_curva type varchar(10) using valor_tipo_curva::varchar(10);
alter table {schema}.curva_de_nivel add constraint valor_tipo_curva_id foreign key (valor_tipo_curva) references {schema}.valor_tipo_curva(identificador);

create index linha_de_quebra_geom_idx ON {schema}.linha_de_quebra using gist(geometria);
create index ponto_cotado_geom_idx ON {schema}.ponto_cotado using gist(geometria);
create index curva_de_nivel_geom_idx ON {schema}.curva_de_nivel using gist(geometria);


-- Mobiliario Urbano
alter table {schema}.mob_urbano_sinal drop constraint if exists valor_tipo_de_mob_urbano_sinal_id;
alter table {schema}.mob_urbano_sinal alter column valor_tipo_de_mob_urbano_sinal type varchar(10) using valor_tipo_de_mob_urbano_sinal::varchar(10);
alter table {schema}.mob_urbano_sinal add constraint valor_tipo_de_mob_urbano_sinal_id foreign key (valor_tipo_de_mob_urbano_sinal) references {schema}.valor_tipo_de_mob_urbano_sinal(identificador);

create index mob_urbano_sinal_geom_idx ON {schema}.mob_urbano_sinal using gist(geometria);


-- Unidades Administrativas
alter table {schema}.fronteira drop constraint if exists valor_estado_fronteira_id;
alter table {schema}.fronteira alter column valor_estado_fronteira type varchar(10) using valor_estado_fronteira::varchar(10);
alter table {schema}.fronteira add constraint valor_estado_fronteira_id foreign key (valor_estado_fronteira) references {schema}.valor_estado_fronteira(identificador);

create index distrito_geom_idx ON {schema}.distrito using gist(geometria);
create index concelho_geom_idx ON {schema}.concelho using gist(geometria);
create index freguesia_geom_idx ON {schema}.freguesia using gist(geometria);
create index fronteira_geom_idx ON {schema}.fronteira using gist(geometria);


-- Infrastruturas e Servicos Publicos
alter table {schema}.inst_gestao_ambiental drop constraint if exists valor_instalacao_gestao_ambiental_id;
alter table {schema}.inst_gestao_ambiental alter column valor_instalacao_gestao_ambiental type varchar(10) using valor_instalacao_gestao_ambiental::varchar(10);
alter table {schema}.inst_gestao_ambiental add constraint valor_instalacao_gestao_ambiental_id foreign key (valor_instalacao_gestao_ambiental) references {schema}.valor_instalacao_gestao_ambiental(identificador);

alter table {schema}.inst_producao drop constraint if exists valor_instalacao_producao_id;
alter table {schema}.inst_producao alter column valor_instalacao_producao type varchar(10) using valor_instalacao_producao::varchar(10);
alter table {schema}.inst_producao add constraint valor_instalacao_producao_id foreign key (valor_instalacao_producao) references {schema}.valor_instalacao_producao(identificador);

alter table {schema}.conduta_de_agua drop constraint if exists valor_conduta_agua_id;
alter table {schema}.conduta_de_agua alter column valor_conduta_agua type varchar(10) using valor_conduta_agua::varchar(10);
alter table {schema}.conduta_de_agua add constraint valor_conduta_agua_id foreign key (valor_conduta_agua) references {schema}.valor_conduta_agua(identificador);

alter table {schema}.conduta_de_agua drop constraint if exists valor_posicao_vertical_id;
alter table {schema}.conduta_de_agua alter column valor_posicao_vertical type varchar(10) using valor_posicao_vertical::varchar(10);
alter table {schema}.conduta_de_agua add constraint valor_posicao_vertical_id foreign key (valor_posicao_vertical) references {schema}.valor_posicao_vertical(identificador);

alter table {schema}.elem_assoc_pgq drop constraint if exists valor_elemento_associado_pgq_id;
alter table {schema}.elem_assoc_pgq alter column valor_elemento_associado_pgq type varchar(10) using valor_elemento_associado_pgq::varchar(10);
alter table {schema}.elem_assoc_pgq add constraint valor_elemento_associado_pgq_id foreign key (valor_elemento_associado_pgq) references {schema}.valor_elemento_associado_pgq(identificador);

alter table {schema}.oleoduto_gasoduto_subtancias_quimicas drop constraint if exists valor_gasoduto_oleoduto_sub_quimicas_id;
alter table {schema}.oleoduto_gasoduto_subtancias_quimicas alter column valor_gasoduto_oleoduto_sub_quimicas type varchar(10) using valor_gasoduto_oleoduto_sub_quimicas::varchar(10);
alter table {schema}.oleoduto_gasoduto_subtancias_quimicas add constraint valor_gasoduto_oleoduto_sub_quimicas_id foreign key (valor_gasoduto_oleoduto_sub_quimicas) references {schema}.valor_gasoduto_oleoduto_sub_quimicas(identificador);

alter table {schema}.oleoduto_gasoduto_subtancias_quimicas drop constraint if exists valor_posicao_vertical_id;
alter table {schema}.oleoduto_gasoduto_subtancias_quimicas alter column valor_posicao_vertical type varchar(10) using valor_posicao_vertical::varchar(10);
alter table {schema}.oleoduto_gasoduto_subtancias_quimicas add constraint valor_posicao_vertical_id foreign key (valor_posicao_vertical) references {schema}.valor_posicao_vertical(identificador);

alter table {schema}.elem_assoc_telecomunicacoes drop constraint if exists valor_elemento_associado_telecomunicacoes_id;
alter table {schema}.elem_assoc_telecomunicacoes alter column valor_elemento_associado_telecomunicacoes type varchar(10) using valor_elemento_associado_telecomunicacoes::varchar(10);
alter table {schema}.elem_assoc_telecomunicacoes add constraint valor_elemento_associado_telecomunicacoes_id foreign key (valor_elemento_associado_telecomunicacoes) references {schema}.valor_elemento_associado_telecomunicacoes(identificador);

alter table {schema}.adm_publica drop constraint if exists valor_tipo_adm_publica_id;
alter table {schema}.adm_publica alter column valor_tipo_adm_publica type varchar(10) using valor_tipo_adm_publica::varchar(10);
alter table {schema}.adm_publica add constraint valor_tipo_adm_publica_id foreign key (valor_tipo_adm_publica) references {schema}.valor_tipo_adm_publica(identificador);

alter table {schema}.elem_assoc_agua drop constraint if exists valor_elemento_associado_agua_id;
alter table {schema}.elem_assoc_agua alter column valor_elemento_associado_agua type varchar(10) using valor_elemento_associado_agua::varchar(10);
alter table {schema}.elem_assoc_agua add constraint valor_elemento_associado_agua_id foreign key (valor_elemento_associado_agua) references {schema}.valor_elemento_associado_agua(identificador);

alter table {schema}.elem_assoc_eletricidade drop constraint if exists valor_elemento_associado_electricidade_id;
alter table {schema}.elem_assoc_eletricidade alter column valor_elemento_associado_electricidade type varchar(10) using valor_elemento_associado_electricidade::varchar(10);
alter table {schema}.elem_assoc_eletricidade add constraint valor_elemento_associado_electricidade_id foreign key (valor_elemento_associado_electricidade) references {schema}.valor_elemento_associado_electricidade(identificador);

alter table {schema}.cabo_electrico drop constraint if exists valor_designacao_tensao_id;
alter table {schema}.cabo_electrico alter column valor_designacao_tensao type varchar(10) using valor_designacao_tensao::varchar(10);
alter table {schema}.cabo_electrico add constraint valor_designacao_tensao_id foreign key (valor_designacao_tensao) references {schema}.valor_designacao_tensao(identificador);

alter table {schema}.cabo_electrico drop constraint if exists valor_posicao_vertical_id;
alter table {schema}.cabo_electrico alter column valor_posicao_vertical type varchar(10) using valor_posicao_vertical::varchar(10);
alter table {schema}.cabo_electrico add constraint valor_posicao_vertical_id foreign key (valor_posicao_vertical) references {schema}.valor_posicao_vertical(identificador);

alter table {schema}.equip_util_coletiva drop column if exists valor_tipo_equipamento_coletivo;

create index conduta_de_agua_geom_idx ON {schema}.conduta_de_agua using gist(geometria);
create index elem_assoc_pgq_geom_idx ON {schema}.elem_assoc_pgq using gist(geometria);
create index oleoduto_gasoduto_subtancias_quimicas_geom_idx ON {schema}.oleoduto_gasoduto_subtancias_quimicas using gist(geometria);
create index elem_assoc_telecomunicacoes_geom_idx ON {schema}.elem_assoc_telecomunicacoes using gist(geometria);
create index elem_assoc_agua_geom_idx ON {schema}.elem_assoc_agua using gist(geometria);
create index elem_assoc_eletricidade_geom_idx ON {schema}.elem_assoc_eletricidade using gist(geometria);
create index cabo_electrico_geom_idx ON {schema}.cabo_electrico using gist(geometria);


-- Construcoes
alter table {schema}.sinal_geodesico drop constraint if exists valor_local_geodesico_id;
alter table {schema}.sinal_geodesico alter column valor_local_geodesico type varchar(10) using valor_local_geodesico::varchar(10);
alter table {schema}.sinal_geodesico add constraint valor_local_geodesico_id foreign key (valor_local_geodesico) references {schema}.valor_local_geodesico(identificador);

alter table {schema}.sinal_geodesico drop constraint if exists valor_ordem_id;
alter table {schema}.sinal_geodesico alter column valor_ordem type varchar(10) using valor_ordem::varchar(10);
alter table {schema}.sinal_geodesico add constraint valor_ordem_id foreign key (valor_ordem) references {schema}.valor_ordem(identificador);

alter table {schema}.sinal_geodesico drop constraint if exists valor_tipo_sinal_geodesico_id;
alter table {schema}.sinal_geodesico alter column valor_tipo_sinal_geodesico type varchar(10) using valor_tipo_sinal_geodesico::varchar(10);
alter table {schema}.sinal_geodesico add constraint valor_tipo_sinal_geodesico_id foreign key (valor_tipo_sinal_geodesico) references {schema}.valor_tipo_sinal_geodesico(identificador);

alter table {schema}.constru_linear drop constraint if exists valor_construcao_linear_id;
alter table {schema}.constru_linear alter column valor_construcao_linear type varchar(10) using valor_construcao_linear::varchar(10);
alter table {schema}.constru_linear add constraint valor_construcao_linear_id foreign key (valor_construcao_linear) references {schema}.valor_construcao_linear(identificador);

alter table {schema}.constru_polig drop constraint if exists valor_tipo_construcao_id;
alter table {schema}.constru_polig alter column valor_tipo_construcao type varchar(10) using valor_tipo_construcao::varchar(10);
alter table {schema}.constru_polig add constraint valor_tipo_construcao_id foreign key (valor_tipo_construcao) references {schema}.valor_tipo_construcao(identificador);

alter table {schema}.ponto_interesse drop constraint if exists valor_tipo_ponto_interesse_id;
alter table {schema}.ponto_interesse alter column valor_tipo_ponto_interesse type varchar(10) using valor_tipo_ponto_interesse::varchar(10);
alter table {schema}.ponto_interesse add constraint valor_tipo_ponto_interesse_id foreign key (valor_tipo_ponto_interesse) references {schema}.valor_tipo_ponto_interesse(identificador);

alter table {schema}.edificio drop constraint if exists valor_condicao_const_id;
alter table {schema}.edificio alter column valor_condicao_const type varchar(10) using valor_condicao_const::varchar(10);
alter table {schema}.edificio add constraint valor_condicao_const_id foreign key (valor_condicao_const) references {schema}.valor_condicao_const(identificador);

alter table {schema}.edificio drop constraint if exists valor_elemento_edificio_xy_id;
alter table {schema}.edificio alter column valor_elemento_edificio_xy type varchar(10) using valor_elemento_edificio_xy::varchar(10);
alter table {schema}.edificio add constraint valor_elemento_edificio_xy_id foreign key (valor_elemento_edificio_xy) references {schema}.valor_elemento_edificio_xy(identificador);

alter table {schema}.edificio drop constraint if exists valor_elemento_edificio_z_id;
alter table {schema}.edificio alter column valor_elemento_edificio_z type varchar(10) using valor_elemento_edificio_z::varchar(10);
alter table {schema}.edificio add constraint valor_elemento_edificio_z_id foreign key (valor_elemento_edificio_z) references {schema}.valor_elemento_edificio_z(identificador);

alter table {schema}.edificio drop constraint if exists valor_forma_edificio_id;
alter table {schema}.edificio alter column valor_forma_edificio type varchar(10) using valor_forma_edificio::varchar(10);
alter table {schema}.edificio add constraint valor_forma_edificio_id foreign key (valor_forma_edificio) references {schema}.valor_forma_edificio(identificador);

alter table {schema}.edificio drop constraint if exists localizacao_instalacao_producao;
alter table {schema}.edificio add constraint localizacao_instalacao_producao foreign key (inst_producao_id) references {schema}.inst_producao(identificador);

alter table {schema}.edificio drop constraint if exists localizacao_instalacao_ambiental;
alter table {schema}.edificio add constraint localizacao_instalacao_ambiental foreign key (inst_gestao_ambiental_id) references {schema}.inst_gestao_ambiental(identificador);

alter table {schema}.edificio drop column if exists nome;
alter table {schema}.edificio drop column if exists numero_policia;
alter table {schema}.edificio drop column if exists valor_utilizacao_atual;

create index sinal_geodesico_geom_idx ON {schema}.sinal_geodesico using gist(geometria);
create index constru_linear_geom_idx ON {schema}.constru_linear using gist(geometria);
create index constru_polig_geom_idx ON {schema}.constru_polig using gist(geometria);
create index ponto_interesse_geom_idx ON {schema}.ponto_interesse using gist(geometria);
create index edificio_geom_idx ON {schema}.edificio using gist(geometria);


-- Transporte
---- Transporte por Cabo
alter table {schema}.seg_via_cabo drop constraint if exists valor_tipo_via_cabo_id;
alter table {schema}.seg_via_cabo alter column valor_tipo_via_cabo type varchar(10) using valor_tipo_via_cabo::varchar(10);
alter table {schema}.seg_via_cabo add constraint valor_tipo_via_cabo_id foreign key (valor_tipo_via_cabo) references {schema}.valor_tipo_via_cabo(identificador);

create index area_infra_trans_cabo_geom_idx ON {schema}.area_infra_trans_cabo using gist(geometria);
create index seg_via_cabo_geom_idx ON {schema}.seg_via_cabo using gist(geometria);

---- Transporte por Via Navegavel
alter table {schema}.area_infra_trans_via_navegavel drop constraint if exists valor_tipo_area_infra_trans_via_navegavel_id;
alter table {schema}.area_infra_trans_via_navegavel alter column valor_tipo_area_infra_trans_via_navegavel type varchar(10) using valor_tipo_area_infra_trans_via_navegavel::varchar(10);
alter table {schema}.area_infra_trans_via_navegavel add constraint valor_tipo_area_infra_trans_via_navegavel_id foreign key (valor_tipo_area_infra_trans_via_navegavel) references {schema}.valor_tipo_area_infra_trans_via_navegavel(identificador);

alter table {schema}.infra_trans_via_navegavel drop constraint if exists valor_tipo_infra_trans_via_navegavel_id;
alter table {schema}.infra_trans_via_navegavel alter column valor_tipo_infra_trans_via_navegavel type varchar(10) using valor_tipo_infra_trans_via_navegavel::varchar(10);
alter table {schema}.infra_trans_via_navegavel add constraint valor_tipo_infra_trans_via_navegavel_id foreign key (valor_tipo_infra_trans_via_navegavel) references {schema}.valor_tipo_infra_trans_via_navegavel(identificador);

create index area_infra_trans_via_navegavel_geom_idx ON {schema}.area_infra_trans_via_navegavel using gist(geometria);
create index infra_trans_via_navegavel_geom_idx ON {schema}.infra_trans_via_navegavel using gist(geometria);

---- Transporte por Aereo
alter table {schema}.area_infra_trans_aereo drop constraint if exists valor_tipo_area_infra_trans_aereo_id;
alter table {schema}.area_infra_trans_aereo alter column valor_tipo_area_infra_trans_aereo type varchar(10) using valor_tipo_area_infra_trans_aereo::varchar(10);
alter table {schema}.area_infra_trans_aereo add constraint valor_tipo_area_infra_trans_aereo_id foreign key (valor_tipo_area_infra_trans_aereo) references {schema}.valor_tipo_area_infra_trans_aereo(identificador);

alter table {schema}.infra_trans_aereo drop constraint if exists valor_categoria_infra_trans_aereo_id;
alter table {schema}.infra_trans_aereo alter column valor_categoria_infra_trans_aereo type varchar(10) using valor_categoria_infra_trans_aereo::varchar(10);
alter table {schema}.infra_trans_aereo add constraint valor_categoria_infra_trans_aereo_id foreign key (valor_categoria_infra_trans_aereo) references {schema}.valor_categoria_infra_trans_aereo(identificador);

alter table {schema}.infra_trans_aereo drop constraint if exists valor_restricao_infra_trans_aereo_id;
alter table {schema}.infra_trans_aereo alter column valor_restricao_infra_trans_aereo type varchar(10) using valor_restricao_infra_trans_aereo::varchar(10);
alter table {schema}.infra_trans_aereo add constraint valor_restricao_infra_trans_aereo_id foreign key (valor_restricao_infra_trans_aereo) references {schema}.valor_restricao_infra_trans_aereo(identificador);

alter table {schema}.infra_trans_aereo drop constraint if exists valor_tipo_infra_trans_aereo_id;
alter table {schema}.infra_trans_aereo alter column valor_tipo_infra_trans_aereo type varchar(10) using valor_tipo_infra_trans_aereo::varchar(10);
alter table {schema}.infra_trans_aereo add constraint valor_tipo_infra_trans_aereo_id foreign key (valor_tipo_infra_trans_aereo) references {schema}.valor_tipo_infra_trans_aereo(identificador);

create index area_infra_trans_aereo_geom_idx ON {schema}.area_infra_trans_aereo using gist(geometria);
create index infra_trans_aereo_geom_idx ON {schema}.infra_trans_aereo using gist(geometria);

---- Transporte Ferroviario
alter table {schema}.seg_via_ferrea drop constraint if exists valor_categoria_bitola_id;
alter table {schema}.seg_via_ferrea alter column valor_categoria_bitola type varchar(10) using valor_categoria_bitola::varchar(10);
alter table {schema}.seg_via_ferrea add constraint valor_categoria_bitola_id foreign key (valor_categoria_bitola) references {schema}.valor_categoria_bitola(identificador);

alter table {schema}.seg_via_ferrea drop constraint if exists valor_estado_linha_ferrea_id;
alter table {schema}.seg_via_ferrea alter column valor_estado_linha_ferrea type varchar(10) using valor_estado_linha_ferrea::varchar(10);
alter table {schema}.seg_via_ferrea add constraint valor_estado_linha_ferrea_id foreign key (valor_estado_linha_ferrea) references {schema}.valor_estado_linha_ferrea(identificador);

alter table {schema}.seg_via_ferrea drop constraint if exists valor_posicao_vertical_transportes_id;
alter table {schema}.seg_via_ferrea alter column valor_posicao_vertical_transportes type varchar(10) using valor_posicao_vertical_transportes::varchar(10);
alter table {schema}.seg_via_ferrea add constraint valor_posicao_vertical_transportes_id foreign key (valor_posicao_vertical_transportes) references {schema}.valor_posicao_vertical_transportes(identificador);

alter table {schema}.seg_via_ferrea drop constraint if exists valor_tipo_linha_ferrea_id;
alter table {schema}.seg_via_ferrea alter column valor_tipo_linha_ferrea type varchar(10) using valor_tipo_linha_ferrea::varchar(10);
alter table {schema}.seg_via_ferrea add constraint valor_tipo_linha_ferrea_id foreign key (valor_tipo_linha_ferrea) references {schema}.valor_tipo_linha_ferrea(identificador);

alter table {schema}.seg_via_ferrea drop constraint if exists valor_tipo_troco_via_ferrea_id;
alter table {schema}.seg_via_ferrea alter column valor_tipo_troco_via_ferrea type varchar(10) using valor_tipo_troco_via_ferrea::varchar(10);
alter table {schema}.seg_via_ferrea add constraint valor_tipo_troco_via_ferrea_id foreign key (valor_tipo_troco_via_ferrea) references {schema}.valor_tipo_troco_via_ferrea(identificador);

alter table {schema}.seg_via_ferrea drop constraint if exists valor_via_ferrea_id;
alter table {schema}.seg_via_ferrea alter column valor_via_ferrea type varchar(10) using valor_via_ferrea::varchar(10);
alter table {schema}.seg_via_ferrea add constraint valor_via_ferrea_id foreign key (valor_via_ferrea) references {schema}.valor_via_ferrea(identificador);

alter table {schema}.infra_trans_ferrov drop constraint if exists valor_tipo_uso_infra_trans_ferrov_id;
alter table {schema}.infra_trans_ferrov alter column valor_tipo_uso_infra_trans_ferrov type varchar(10) using valor_tipo_uso_infra_trans_ferrov::varchar(10);
alter table {schema}.infra_trans_ferrov add constraint valor_tipo_uso_infra_trans_ferrov_id foreign key (valor_tipo_uso_infra_trans_ferrov) references {schema}.valor_tipo_uso_infra_trans_ferrov(identificador);

alter table {schema}.infra_trans_ferrov drop constraint if exists valor_tipo_infra_trans_ferrov_id;
alter table {schema}.infra_trans_ferrov alter column valor_tipo_infra_trans_ferrov type varchar(10) using valor_tipo_infra_trans_ferrov::varchar(10);
alter table {schema}.infra_trans_ferrov add constraint valor_tipo_infra_trans_ferrov_id foreign key (valor_tipo_infra_trans_ferrov) references {schema}.valor_tipo_infra_trans_ferrov(identificador);

alter table {schema}.no_trans_ferrov drop constraint if exists valor_tipo_no_trans_ferrov_id;
alter table {schema}.no_trans_ferrov alter column valor_tipo_no_trans_ferrov type varchar(10) using valor_tipo_no_trans_ferrov::varchar(10);
alter table {schema}.no_trans_ferrov add constraint valor_tipo_no_trans_ferrov_id foreign key (valor_tipo_no_trans_ferrov) references {schema}.valor_tipo_no_trans_ferrov(identificador);

alter table {schema}.area_infra_trans_ferrov drop constraint if exists area_infra_trans_ferrov;
alter table {schema}.area_infra_trans_ferrov add constraint area_infra_trans_ferrov foreign key (infra_trans_ferrov_id) references {schema}.infra_trans_ferrov(identificador);

create index seg_via_ferrea_geom_idx ON {schema}.seg_via_ferrea using gist(geometria);
create index area_infra_trans_ferrov_geom_idx ON {schema}.area_infra_trans_ferrov using gist(geometria);
create index infra_trans_ferrov_geom_idx ON {schema}.infra_trans_ferrov using gist(geometria);
create index no_trans_ferrov_geom_idx ON {schema}.no_trans_ferrov using gist(geometria);

---- Transporte Rodoviario
alter table {schema}.seg_via_rodov drop constraint if exists valor_caract_fisica_rodov_id;
alter table {schema}.seg_via_rodov alter column valor_caract_fisica_rodov type varchar(10) using valor_caract_fisica_rodov::varchar(10);
alter table {schema}.seg_via_rodov add constraint valor_caract_fisica_rodov_id foreign key (valor_caract_fisica_rodov) references {schema}.valor_caract_fisica_rodov(identificador);

alter table {schema}.seg_via_rodov drop constraint if exists valor_estado_via_rodov_id;
alter table {schema}.seg_via_rodov alter column valor_estado_via_rodov type varchar(10) using valor_estado_via_rodov::varchar(10);
alter table {schema}.seg_via_rodov add constraint valor_estado_via_rodov_id foreign key (valor_estado_via_rodov) references {schema}.valor_estado_via_rodov(identificador);

alter table {schema}.seg_via_rodov drop constraint if exists valor_posicao_vertical_transportes_id;
alter table {schema}.seg_via_rodov alter column valor_posicao_vertical_transportes type varchar(10) using valor_posicao_vertical_transportes::varchar(10);
alter table {schema}.seg_via_rodov add constraint valor_posicao_vertical_transportes_id foreign key (valor_posicao_vertical_transportes) references {schema}.valor_posicao_vertical_transportes(identificador);

alter table {schema}.seg_via_rodov drop constraint if exists valor_restricao_acesso_id;
alter table {schema}.seg_via_rodov alter column valor_restricao_acesso type varchar(10) using valor_restricao_acesso::varchar(10);
alter table {schema}.seg_via_rodov add constraint valor_restricao_acesso_id foreign key (valor_restricao_acesso) references {schema}.valor_restricao_acesso(identificador);

alter table {schema}.seg_via_rodov drop constraint if exists valor_sentido_id;
alter table {schema}.seg_via_rodov alter column valor_sentido type varchar(10) using valor_sentido::varchar(10);
alter table {schema}.seg_via_rodov add constraint valor_sentido_id foreign key (valor_sentido) references {schema}.valor_sentido(identificador);

alter table {schema}.seg_via_rodov drop constraint if exists valor_tipo_troco_rodoviario_id;
alter table {schema}.seg_via_rodov alter column valor_tipo_troco_rodoviario type varchar(10) using valor_tipo_troco_rodoviario::varchar(10);
alter table {schema}.seg_via_rodov add constraint valor_tipo_troco_rodoviario_id foreign key (valor_tipo_troco_rodoviario) references {schema}.valor_tipo_troco_rodoviario(identificador);

alter table {schema}.seg_via_rodov drop column if exists valor_tipo_circulacao;

alter table {schema}.infra_trans_rodov drop constraint if exists valor_tipo_infra_trans_rodov_id;
alter table {schema}.infra_trans_rodov alter column valor_tipo_infra_trans_rodov type varchar(10) using valor_tipo_infra_trans_rodov::varchar(10);
alter table {schema}.infra_trans_rodov add constraint valor_tipo_infra_trans_rodov_id foreign key (valor_tipo_infra_trans_rodov) references {schema}.valor_tipo_infra_trans_rodov(identificador);

alter table {schema}.no_trans_rodov drop constraint if exists valor_tipo_no_trans_rodov_id;
alter table {schema}.no_trans_rodov alter column valor_tipo_no_trans_rodov type varchar(10) using valor_tipo_no_trans_rodov::varchar(10);
alter table {schema}.no_trans_rodov add constraint valor_tipo_no_trans_rodov_id foreign key (valor_tipo_no_trans_rodov) references {schema}.valor_tipo_no_trans_rodov(identificador);

alter table {schema}.via_rodov_limite drop constraint if exists valor_tipo_limite_id;
alter table {schema}.via_rodov_limite alter column valor_tipo_limite type varchar(10) using valor_tipo_limite::varchar(10);
alter table {schema}.via_rodov_limite add constraint valor_tipo_limite_id foreign key (valor_tipo_limite) references {schema}.valor_tipo_limite(identificador);

alter table {schema}.obra_arte drop constraint if exists valor_tipo_obra_arte_id;
alter table {schema}.obra_arte alter column valor_tipo_obra_arte type varchar(10) using valor_tipo_obra_arte::varchar(10);
alter table {schema}.obra_arte add constraint valor_tipo_obra_arte_id foreign key (valor_tipo_obra_arte) references {schema}.valor_tipo_obra_arte(identificador);

alter table {schema}.area_infra_trans_rodov drop constraint if exists area_infra_trans_rodov;
alter table {schema}.area_infra_trans_rodov add constraint area_infra_trans_rodov foreign key (infra_trans_rodov_id) references {schema}.infra_trans_rodov(identificador);

alter table {schema}.infra_trans_rodov drop column if exists valor_tipo_servico;

create index seg_via_rodov_geom_idx ON {schema}.seg_via_rodov using gist(geometria);
create index area_infra_trans_rodov_geom_idx ON {schema}.area_infra_trans_rodov using gist(geometria);
create index infra_trans_rodov_geom_idx ON {schema}.infra_trans_rodov using gist(geometria);
create index no_trans_rodov_geom_idx ON {schema}.no_trans_rodov using gist(geometria);
create index via_rodov_limite_geom_idx ON {schema}.via_rodov_limite using gist(geometria);
create index obra_arte_geom_idx ON {schema}.obra_arte using gist(geometria);


-- Hidrografia
alter table {schema}.nascente drop constraint if exists valor_persistencia_hidrologica_id;
alter table {schema}.nascente alter column valor_persistencia_hidrologica type varchar(10) using valor_persistencia_hidrologica::varchar(10);
alter table {schema}.nascente add constraint valor_persistencia_hidrologica_id foreign key (valor_persistencia_hidrologica) references {schema}.valor_persistencia_hidrologica(identificador);

alter table {schema}.nascente drop constraint if exists valor_tipo_nascente_id;
alter table {schema}.nascente alter column valor_tipo_nascente type varchar(10) using valor_tipo_nascente::varchar(10);
alter table {schema}.nascente add constraint valor_tipo_nascente_id foreign key (valor_tipo_nascente) references {schema}.valor_tipo_nascente(identificador);

alter table {schema}.agua_lentica drop constraint if exists valor_agua_lentica_id;
alter table {schema}.agua_lentica alter column valor_agua_lentica type varchar(10) using valor_agua_lentica::varchar(10);
alter table {schema}.agua_lentica add constraint valor_agua_lentica_id foreign key (valor_agua_lentica) references {schema}.valor_agua_lentica(identificador);

alter table {schema}.agua_lentica drop constraint if exists valor_persistencia_hidrologica_id;
alter table {schema}.agua_lentica alter column valor_persistencia_hidrologica type varchar(10) using valor_persistencia_hidrologica::varchar(10);
alter table {schema}.agua_lentica add constraint valor_persistencia_hidrologica_id foreign key (valor_persistencia_hidrologica) references {schema}.valor_persistencia_hidrologica(identificador);

alter table {schema}.margem drop constraint if exists valor_tipo_margem_id;
alter table {schema}.margem alter column valor_tipo_margem type varchar(10) using valor_tipo_margem::varchar(10);
alter table {schema}.margem add constraint valor_tipo_margem_id foreign key (valor_tipo_margem) references {schema}.valor_tipo_margem(identificador);

alter table {schema}.curso_de_agua_eixo drop constraint if exists valor_curso_de_agua_id;
alter table {schema}.curso_de_agua_eixo alter column valor_curso_de_agua type varchar(10) using valor_curso_de_agua::varchar(10);
alter table {schema}.curso_de_agua_eixo add constraint valor_curso_de_agua_id foreign key (valor_curso_de_agua) references {schema}.valor_curso_de_agua(identificador);

alter table {schema}.curso_de_agua_eixo drop constraint if exists valor_persistencia_hidrologica_id;
alter table {schema}.curso_de_agua_eixo alter column valor_persistencia_hidrologica type varchar(10) using valor_persistencia_hidrologica::varchar(10);
alter table {schema}.curso_de_agua_eixo add constraint valor_persistencia_hidrologica_id foreign key (valor_persistencia_hidrologica) references {schema}.valor_persistencia_hidrologica(identificador);

alter table {schema}.curso_de_agua_eixo drop constraint if exists valor_posicao_vertical_id;
alter table {schema}.curso_de_agua_eixo alter column valor_posicao_vertical type varchar(10) using valor_posicao_vertical::varchar(10);
alter table {schema}.curso_de_agua_eixo add constraint valor_posicao_vertical_id foreign key (valor_posicao_vertical) references {schema}.valor_posicao_vertical(identificador);

alter table {schema}.zona_humida drop constraint if exists valor_zona_humida_id;
alter table {schema}.zona_humida alter column valor_zona_humida type varchar(10) using valor_zona_humida::varchar(10);
alter table {schema}.zona_humida add constraint valor_zona_humida_id foreign key (valor_zona_humida) references {schema}.valor_zona_humida(identificador);

alter table {schema}.no_hidrografico drop constraint if exists valor_tipo_no_hidrografico_id;
alter table {schema}.no_hidrografico alter column valor_tipo_no_hidrografico type varchar(10) using valor_tipo_no_hidrografico::varchar(10);
alter table {schema}.no_hidrografico add constraint valor_tipo_no_hidrografico_id foreign key (valor_tipo_no_hidrografico) references {schema}.valor_tipo_no_hidrografico(identificador);

alter table {schema}.barreira drop constraint if exists valor_barreira_id;
alter table {schema}.barreira alter column valor_barreira type varchar(10) using valor_barreira::varchar(10);
alter table {schema}.barreira add constraint valor_barreira_id foreign key (valor_barreira) references {schema}.valor_barreira(identificador);

create index nascente_geom_idx ON {schema}.nascente using gist(geometria);
create index agua_lentica_geom_idx ON {schema}.agua_lentica using gist(geometria);
create index margem_geom_idx ON {schema}.margem using gist(geometria);
create index curso_de_agua_eixo_geom_idx ON {schema}.curso_de_agua_eixo using gist(geometria);
create index curso_de_agua_area_geom_idx ON {schema}.curso_de_agua_area using gist(geometria);
create index queda_de_agua_geom_idx ON {schema}.queda_de_agua using gist(geometria);
create index zona_humida_geom_idx ON {schema}.zona_humida using gist(geometria);
create index no_hidrografico_geom_idx ON {schema}.no_hidrografico using gist(geometria);
create index barreira_geom_idx ON {schema}.barreira using gist(geometria);
create index fronteira_terra_agua_geom_idx ON {schema}.fronteira_terra_agua using gist(geometria);
