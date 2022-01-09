drop procedure IF EXISTS validation.do_validation (nd1 bool);

drop procedure IF EXISTS validation.do_validation (nd1 bool, _code varchar);

drop function IF EXISTS validation.initcap_pt (nome varchar);

drop function IF EXISTS validation.validcap_pt(nome character varying);

drop function IF EXISTS validation.valid_noabbr(nome character varying);

drop function IF EXISTS validation.rg1_2_validation (rg int, versao int, nd1 boolean);

drop function IF EXISTS validation.rg5_validation ();

drop function IF EXISTS validation.rg6_validation ();

drop function IF EXISTS validation.rg7_validation ();

drop function IF EXISTS validation.rg_min_area (rg text, tabela text, minv int);

drop function IF EXISTS validation.re3_2_validation (ndd integer);

drop function IF EXISTS validation.re4_10_validation ();

drop table if exists validation.curva_de_nivel_points_interval;

drop table if exists validation.curva_de_nivel_ponto_cotado;

drop TABLE IF EXISTS validation.tin;

drop TABLE IF EXISTS validation.no_hidro;

drop TABLE IF EXISTS validation.no_hidro_juncao;

drop TABLE IF EXISTS validation.interrupcao_fluxo;

drop TABLE IF EXISTS validation.juncao_fluxo_dattr;

drop schema IF EXISTS validation cascade;

drop schema IF EXISTS errors cascade;
