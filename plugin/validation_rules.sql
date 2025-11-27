create schema if not exists validation;

-- code HAS TO BE a valid PG identifier; it will be appended to the table name
create table if not exists validation.rules (
	code varchar not null,
	name varchar not null,
	rule text null,
	scope varchar null,
	theme varchar null, -- regra geral (null) ou regra especifica (theme != null)
	entity varchar null,
	query varchar null,
	query_nd2 varchar null,
	report varchar null,
	total int null,
	good int null,
	bad int null,
	required boolean not null default true, -- required by homologation process
	enabled boolean not null default true, -- can be disabled
	run boolean not null default false, -- can be checked/unchecked before each run,
	dorder int GENERATED ALWAYS AS IDENTITY,
	versoes text[] not null default '{ "v1.1.2", "v2.0.1", "v2.0.2" }'
);

ALTER TABLE validation.rules ADD CONSTRAINT rules_pky PRIMARY KEY (code, versoes);

create table if not exists validation.rules_area (
	code varchar not null,
	name varchar not null,
	rule text null,
	scope varchar null,
	theme varchar null,
	entity varchar null,
	query varchar null,
	query_nd2 varchar null,
	report varchar null,
	required boolean not null default true,
	enabled boolean not null default true,
	run boolean not null default false,
	is_global boolean not null default false,
	dorder int GENERATED ALWAYS AS IDENTITY,
	versoes text[] not null default '{ "v1.1.2", "v2.0.1", "v2.0.2" }'
);

ALTER TABLE validation.rules_area ADD CONSTRAINT rules_area_pky PRIMARY KEY (code, versoes);

create table if not exists validation.rules_area_report (
	rule_code varchar not null,
	geom_id uuid null,
	total int null,
	good int null,
	bad int null
);

-- Regras Gerais

delete from validation.rules where code = 'rg_1';
insert into validation.rules ( code, name, rule, scope, query, query_nd2 ) 
values ('rg_1', 'Dimensão mínima dos polígonos', 
$$A área mínima de uma entidade representada através de um objeto de
geometria polígono é:
 - NdD1: 4 m²;
 - NdD2: 20 m² .$$, 
$$Todas as entidades representadas exclusivamente através de objetos de
geometria polígono.$$,
$$select * from validation.rg1_2_validation (1, 1, true, '%s'::json )$$,
$$select * from validation.rg1_2_validation (1, 1, false, '%s'::json )$$ );

delete from validation.rules_area where code = 'rg_1';
insert into validation.rules_area ( code, name, rule, scope, query, query_nd2 ) 
values ('rg_1', 'Dimensão mínima dos polígonos', 
$$A área mínima de uma entidade representada através de um objeto de
geometria polígono é:
 - NdD1: 4 m²;
 - NdD2: 20 m² .$$, 
$$Todas as entidades representadas exclusivamente através de objetos de
geometria polígono.$$,
$$select * from validation.rg1_2_validation (1, 1, true, '%s'::geometry, '%s'::json)$$,
$$select * from validation.rg1_2_validation (1, 1, false, '%s'::geometry, '%s'::json)$$ );

delete from validation.rules where code = 'rg_2';
insert into validation.rules ( code, name, rule, scope, query, query_nd2 ) 
values ('rg_2', 'Dupla geometria ponto e polígono', 
$$Às entidades que são representadas através de objetos de geometria ponto ou
através de objetos de geometria polígono aplica-se a regra:
 - NdD1: a entidade é representada através de um polígono se a sua área for
igual ou superior a 4 m² e através de um ponto se a sua área for inferior a
4 m²;
 - NdD2: a entidade é representada através de um polígono se a sua área for
igual ou superior a 20 m² e através de um ponto se a sua área for inferior
a 20 m² .$$,
$$"Construção poligonal", "Edifício", "Ponto de interesse", "Elemento associado
de água", "Elementos associado de eletricidade", "Elementos associado de
petróleo, gás e substâncias químicas" e "Mobiliário urbano e sinalização".$$,
$$select * from validation.rg1_2_validation (2, 1, true, '%s'::json )$$,
$$select * from validation.rg1_2_validation (2, 1, false, '%s'::json )$$ );

delete from validation.rules_area where code = 'rg_2';
insert into validation.rules_area ( code, name, rule, scope, query, query_nd2 ) 
values ('rg_2', 'Dupla geometria ponto e polígono', 
$$Às entidades que são representadas através de objetos de geometria ponto ou
através de objetos de geometria polígono aplica-se a regra:
 - NdD1: a entidade é representada através de um polígono se a sua área for
igual ou superior a 4 m² e através de um ponto se a sua área for inferior a
4 m²;
 - NdD2: a entidade é representada através de um polígono se a sua área for
igual ou superior a 20 m² e através de um ponto se a sua área for inferior
a 20 m² .$$,
$$"Construção poligonal", "Edifício", "Ponto de interesse", "Elemento associado
de água", "Elementos associado de eletricidade", "Elementos associado de
petróleo, gás e substâncias químicas" e "Mobiliário urbano e sinalização".$$,
$$select * from validation.rg1_2_validation (2, 1, true, '%s'::geometry, '%s'::json )$$,
$$select * from validation.rg1_2_validation (2, 1, false, '%s'::geometry, '%s'::json )$$ );

-- TODO
-- Eventualmente criar topologia com tolerância 0
delete from validation.rules where code = 'rg_3';
insert into validation.rules ( code, name, rule, scope ) 
values ('rg_3', 'Tolerância de conetividade', 
$$A tolerância de conetividade é 0 (zero).$$,
$$Todas as entidades representadas através de objetos de geometria linha.$$ );

delete from validation.rules_area where code = 'rg_3';
insert into validation.rules_area ( code, name, rule, scope ) 
values ('rg_3', 'Tolerância de conetividade', 
$$A tolerância de conetividade é 0 (zero).$$,
$$Todas as entidades representadas através de objetos de geometria linha.$$ );

-- Regras auxiliares
-- Verificam outras caraterísticas que podem não estar explícitas nas Regras gerais e específicas da norma
--
-- Relacionada com a regra geral 3 e com a seção 6.3 EIXOS E CONETIVIDADE
-- Em qualquer situação, a existência de geometrias inválidas pode causar problemas
-- Na criação de redes topológicas, cria problemas com certeza
--
delete from validation.rules where code = 'ra_3_1';
insert into validation.rules ( code, name, rule, scope, entity,  query, report ) 
values ('ra_3_1', 'Tolerância de conetividade - Seção 6.3 EIXOS E CONETIVIDADE',
$$Os eixos de futuras redes não devem ter comprimento 0.$$,
$$Todas as entidades que representam futuras redes (hidrográfica, ferroviária e rodoviária).$$,
'curso_de_agua_eixo',
$$with 
total as (select count(*) from {schema}.curso_de_agua_eixo),
good as (select count(*) from {schema}.curso_de_agua_eixo a where st_isvalid(a.geometria)),
bad as (select count(*) from {schema}.curso_de_agua_eixo a where not st_isvalid(a.geometria))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select a.* from {schema}.curso_de_agua_eixo a where not st_isvalid(a.geometria)$$ );

delete from validation.rules_area where code = 'ra_3_1';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, report ) 
values ('ra_3_1', 'Tolerância de conetividade - Seção 6.3 EIXOS E CONETIVIDADE',
$$Os eixos de futuras redes não devem ter comprimento 0.$$,
$$Todas as entidades que representam futuras redes (hidrográfica, ferroviária e rodoviária).$$,
'curso_de_agua_eixo',
$$with 
total as (select count(*) from {schema}.curso_de_agua_eixo),
good as (select count(*) from {schema}.curso_de_agua_eixo a where st_isvalid(a.geometria) and ST_Intersects(geometria, '%1$s')),
bad as (select count(*) from {schema}.curso_de_agua_eixo a where not st_isvalid(a.geometria) and ST_Intersects(geometria, '%1$s'))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select a.* from {schema}.curso_de_agua_eixo a where not st_isvalid(a.geometria) and ST_Intersects(geometria, '%1$s')$$ );


delete from validation.rules where code = 'ra_3_2';
insert into validation.rules ( code, name, rule, scope, entity,  query, report ) 
values ('ra_3_2', 'Tolerância de conetividade - Seção 6.3 EIXOS E CONETIVIDADE',
$$Os eixos de futuras redes não devem ter comprimento 0.$$,
$$Todas as entidades que representam futuras redes (hidrográfica, ferroviária e rodoviária).$$,
'seg_via_rodov',
$$with 
total as (select count(*) from {schema}.seg_via_rodov),
good as (select count(*) from {schema}.seg_via_rodov a where st_isvalid(a.geometria)),
bad as (select count(*) from {schema}.seg_via_rodov a where not st_isvalid(a.geometria))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select a.* from {schema}.seg_via_rodov a where not st_isvalid(a.geometria)$$ );

delete from validation.rules_area where code = 'ra_3_2';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, report ) 
values ('ra_3_2', 'Tolerância de conetividade - Seção 6.3 EIXOS E CONETIVIDADE',
$$Os eixos de futuras redes não devem ter comprimento 0.$$,
$$Todas as entidades que representam futuras redes (hidrográfica, ferroviária e rodoviária).$$,
'seg_via_rodov',
$$with 
total as (select count(*) from {schema}.seg_via_rodov),
good as (select count(*) from {schema}.seg_via_rodov a where st_isvalid(a.geometria) and ST_Intersects(geometria, '%1$s')),
bad as (select count(*) from {schema}.seg_via_rodov a where not st_isvalid(a.geometria) and ST_Intersects(geometria, '%1$s'))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select a.* from {schema}.seg_via_rodov a where not st_isvalid(a.geometria) and ST_Intersects(geometria, '%1$s')$$ );


delete from validation.rules where code = 'ra_3_3';
insert into validation.rules ( code, name, rule, scope, entity,  query, report ) 
values ('ra_3_3', 'Tolerância de conetividade - Seção 6.3 EIXOS E CONETIVIDADE',
$$Os eixos de futuras redes não devem ter comprimento 0.$$,
$$Todas as entidades que representam futuras redes (hidrográfica, ferroviária e rodoviária).$$,
'seg_via_ferrea',
$$with 
total as (select count(*) from {schema}.seg_via_ferrea),
good as (select count(*) from {schema}.seg_via_ferrea a where st_isvalid(a.geometria)),
bad as (select count(*) from {schema}.seg_via_ferrea a where not st_isvalid(a.geometria))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select a.* from {schema}.seg_via_ferrea a where not st_isvalid(a.geometria)$$ );

delete from validation.rules_area where code = 'ra_3_3';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, report ) 
values ('ra_3_3', 'Tolerância de conetividade - Seção 6.3 EIXOS E CONETIVIDADE',
$$Os eixos de futuras redes não devem ter comprimento 0.$$,
$$Todas as entidades que representam futuras redes (hidrográfica, ferroviária e rodoviária).$$,
'seg_via_ferrea',
$$with 
total as (select count(*) from {schema}.seg_via_ferrea),
good as (select count(*) from {schema}.seg_via_ferrea a where st_isvalid(a.geometria) and ST_Intersects(geometria, '%1$s')),
bad as (select count(*) from {schema}.seg_via_ferrea a where not st_isvalid(a.geometria) and ST_Intersects(geometria, '%1$s'))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select a.* from {schema}.seg_via_ferrea a where not st_isvalid(a.geometria) and ST_Intersects(geometria, '%1$s')$$ );

-- TODO
-- Nova redação
-- delete from validation.rules where code = 'rg_4';
-- insert into validation.rules ( code, name, rule, scope ) 
-- values ('rg_4', 'Consistência tridimensional', 
-- $$Todos os objetos tridimensionais (3D) são consistentes entre si.
-- Quando os objetos se intersectam no espaço essa interseção está materializada através de vértices coincidentes e tridimensionalmente coerentes.$$,
-- $$Todos os objetos do Tema "Altimetria" e os objetos tridimensionais (3D) dos Temas "Hidrografia", "Transportes" e "Construções"$$);

-- consistência dos pontos cotados
delete from validation.rules where code = 'rg_4_1';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2 ) 
values ('rg_4_1', 'Consistência tridimensional (Parte 1 - Altimetria)',
$$Todos os objetos tridimensionais (3D) são consistentes entre si.
Quando os objetos se intersectam no espaço essa interseção está materializada através de vértices coincidentes e tridimensionalmente coerentes.$$,
$$Todos os objetos do Tema "Altimetria" e os objetos tridimensionais (3D) dos Temas "Hidrografia", "Transportes" e "Construções"$$, 'ponto_cotado',
$$select * from validation.rg4_1_validation(1, '%s'::json)$$,
$$select * from validation.rg4_1_validation(2, '%s'::json)$$ );

delete from validation.rules_area where code = 'rg_4_1';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2 ) 
values ('rg_4_1', 'Consistência tridimensional (Parte 1 - Altimetria)',
$$Todos os objetos tridimensionais (3D) são consistentes entre si.
Quando os objetos se intersectam no espaço essa interseção está materializada através de vértices coincidentes e tridimensionalmente coerentes.$$,
$$Todos os objetos do Tema "Altimetria" e os objetos tridimensionais (3D) dos Temas "Hidrografia", "Transportes" e "Construções"$$, 'ponto_cotado',
$$select * from validation.rg4_1_validation(1, '%s'::geometry, '%s'::json)$$,
$$select * from validation.rg4_1_validation(2, '%s'::geometry, '%s'::json)$$ );

-- "Transportes" NoTransRodov <-> SegViaRodov
-- "Transportes" NoTransFerrov <-> SegViaFerrea
-- "Hidrografia" os nós hidrográficos têm que coincidir com eixos de água
-- "Construções" só tem a entidade 3D SinalGeodesico, sem ter que ser coincidente com nada.
delete from validation.rules where code = 'rg_4_2_1';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('rg_4_2_1', 'Consistência tridimensional (Hidrografia)',
$$Todos os objetos tridimensionais (3D) são consistentes entre si.
Quando os objetos se intersectam no espaço essa interseção está materializada através de vértices coincidentes e tridimensionalmente coerentes.$$,
$$Todos os objetos do Tema "Altimetria" e os objetos tridimensionais (3D) dos Temas "Hidrografia", "Transportes" e "Construções"$$, 'no_hidrografico',
$$with nos as (
	SELECT identificador, geometria from {schema}.no_hidrografico nh
),
total as (select count(*) from {schema}.no_hidrografico),
good as (SELECT count(distinct(a.identificador))
   from {schema}.no_hidrografico a, {schema}.curso_de_agua_eixo b
     where st_3dintersects(a.geometria, b.geometria)),
bad as (select count(nh.*) 
from {schema}.no_hidrografico nh
where nh.identificador not in (
SELECT a.identificador
   from {schema}.no_hidrografico a, {schema}.curso_de_agua_eixo b
     where st_3dintersects(a.geometria, b.geometria)    
))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with nos as (
	SELECT identificador, geometria from {schema}.no_hidrografico nh
),
total as (select count(*) from {schema}.no_hidrografico),
good as (SELECT count(distinct(a.identificador))
   from {schema}.no_hidrografico a, {schema}.curso_de_agua_eixo b
     where st_3dintersects(a.geometria, b.geometria)),
bad as (select count(nh.*) 
from {schema}.no_hidrografico nh
where nh.identificador not in (
SELECT a.identificador
   from {schema}.no_hidrografico a, {schema}.curso_de_agua_eixo b
     where st_3dintersects(a.geometria, b.geometria)    
))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select nh.* 
from {schema}.no_hidrografico nh
where nh.identificador not in (
SELECT a.identificador
   from {schema}.no_hidrografico a, {schema}.curso_de_agua_eixo b
     where st_3dintersects(a.geometria, b.geometria)    
) $$ );

delete from validation.rules_area where code = 'rg_4_2_1';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('rg_4_2_1', 'Consistência tridimensional (Hidrografia)',
$$Todos os objetos tridimensionais (3D) são consistentes entre si.
Quando os objetos se intersectam no espaço essa interseção está materializada através de vértices coincidentes e tridimensionalmente coerentes.$$,
$$Todos os objetos do Tema "Altimetria" e os objetos tridimensionais (3D) dos Temas "Hidrografia", "Transportes" e "Construções"$$, 'no_hidrografico',
$$with nos as (
	SELECT identificador, geometria from {schema}.no_hidrografico nh
	where ST_Intersects(geometria, '%1$s')
),
total as (select count(*) from {schema}.no_hidrografico where ST_Intersects(geometria, '%1$s')),
good as (SELECT count(distinct(a.identificador))
   from {schema}.no_hidrografico a, {schema}.curso_de_agua_eixo b
     where st_3dintersects(a.geometria, b.geometria) and ST_Intersects(a.geometria, '%1$s')),
bad as (select count(nh.*) 
from {schema}.no_hidrografico nh
where nh.identificador not in (
SELECT a.identificador
   from {schema}.no_hidrografico a, {schema}.curso_de_agua_eixo b
     where st_3dintersects(a.geometria, b.geometria)    
) and ST_Intersects(geometria, '%1$s'))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with nos as (
	SELECT identificador, geometria from {schema}.no_hidrografico nh
	where ST_Intersects(geometria, '%1$s')
),
total as (select count(*) from {schema}.no_hidrografico where ST_Intersects(geometria, '%1$s')),
good as (SELECT count(distinct(a.identificador))
   from {schema}.no_hidrografico a, {schema}.curso_de_agua_eixo b
     where st_3dintersects(a.geometria, b.geometria) and ST_Intersects(a.geometria, '%1$s')),
bad as (select count(nh.*) 
from {schema}.no_hidrografico nh
where nh.identificador not in (
SELECT a.identificador
   from {schema}.no_hidrografico a, {schema}.curso_de_agua_eixo b
     where st_3dintersects(a.geometria, b.geometria)    
) and ST_Intersects(geometria, '%1$s'))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select nh.* 
from {schema}.no_hidrografico nh
where nh.identificador not in (
SELECT a.identificador
   from {schema}.no_hidrografico a, {schema}.curso_de_agua_eixo b
     where st_3dintersects(a.geometria, b.geometria)    
) and ST_Intersects(geometria, '%1$s') $$ );
--
delete from validation.rules where code = 'rg_4_2_2';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('rg_4_2_2', 'Consistência tridimensional (Transportes)',
$$Todos os objetos tridimensionais (3D) são consistentes entre si.
Quando os objetos se intersectam no espaço essa interseção está materializada através de vértices coincidentes e tridimensionalmente coerentes.$$,
$$Todos os objetos do Tema "Altimetria" e os objetos tridimensionais (3D) dos Temas "Hidrografia", "Transportes" e "Construções"$$, 'no_trans_rodov',
$$with nos as (
	SELECT identificador, geometria from {schema}.no_trans_rodov nh
),
total as (select count(*) from {schema}.no_trans_rodov),
good as (SELECT count(distinct(a.identificador))
   from {schema}.no_trans_rodov a, {schema}.seg_via_rodov b
     where st_3dintersects(a.geometria, b.geometria)),
bad as (select count(nh.*) 
from {schema}.no_trans_rodov nh
where nh.identificador not in (
SELECT a.identificador
   from {schema}.no_trans_rodov a, {schema}.seg_via_rodov b
     where st_3dintersects(a.geometria, b.geometria)    
))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with nos as (
	SELECT identificador, geometria from {schema}.no_trans_rodov nh
),
total as (select count(*) from {schema}.no_trans_rodov),
good as (SELECT count(distinct(a.identificador))
   from {schema}.no_trans_rodov a, {schema}.seg_via_rodov b
     where st_3dintersects(a.geometria, b.geometria)),
bad as (select count(nh.*) 
from {schema}.no_trans_rodov nh
where nh.identificador not in (
SELECT a.identificador
   from {schema}.no_trans_rodov a, {schema}.seg_via_rodov b
     where st_3dintersects(a.geometria, b.geometria)    
))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select nh.* 
from {schema}.no_trans_rodov nh
where nh.identificador not in (
SELECT a.identificador
   from {schema}.no_trans_rodov a, {schema}.seg_via_rodov b
     where st_3dintersects(a.geometria, b.geometria)    
) $$ );

delete from validation.rules_area where code = 'rg_4_2_2';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('rg_4_2_2', 'Consistência tridimensional (Transportes)',
$$Todos os objetos tridimensionais (3D) são consistentes entre si.
Quando os objetos se intersectam no espaço essa interseção está materializada através de vértices coincidentes e tridimensionalmente coerentes.$$,
$$Todos os objetos do Tema "Altimetria" e os objetos tridimensionais (3D) dos Temas "Hidrografia", "Transportes" e "Construções"$$, 'no_trans_rodov',
$$with nos as (
	SELECT identificador, geometria from {schema}.no_trans_rodov nh
	where ST_Intersects(geometria, '%1$s')
),
total as (select count(*) from {schema}.no_trans_rodov where ST_Intersects(geometria, '%1$s')),
good as (SELECT count(distinct(a.identificador))
   from nos a, {schema}.seg_via_rodov b
     where st_3dintersects(a.geometria, b.geometria)),
bad as (select count(nh.*) 
from nos nh
where nh.identificador not in (
SELECT a.identificador
   from nos a, {schema}.seg_via_rodov b
     where st_3dintersects(a.geometria, b.geometria)    
))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with nos as (
	SELECT identificador, geometria from {schema}.no_trans_rodov nh
	where ST_Intersects(geometria, '%1$s')
),
total as (select count(*) from {schema}.no_trans_rodov where ST_Intersects(geometria, '%1$s')),
good as (SELECT count(distinct(a.identificador))
   from nos a, {schema}.seg_via_rodov b
     where st_3dintersects(a.geometria, b.geometria)),
bad as (select count(nh.*) 
from nos nh
where nh.identificador not in (
SELECT a.identificador
   from nos a, {schema}.seg_via_rodov b
     where st_3dintersects(a.geometria, b.geometria)    
))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select nh.* 
from {schema}.no_trans_rodov nh
where nh.identificador not in (
SELECT a.identificador
   from {schema}.no_trans_rodov a, {schema}.seg_via_rodov b
     where st_3dintersects(a.geometria, b.geometria)    
) and ST_Intersects(nh.geometria, '%1$s')$$ );
--
delete from validation.rules where code = 'rg_4_2_3';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('rg_4_2_3', 'Consistência tridimensional (Transportes)',
$$Todos os objetos tridimensionais (3D) são consistentes entre si.
Quando os objetos se intersectam no espaço essa interseção está materializada através de vértices coincidentes e tridimensionalmente coerentes.$$,
$$Todos os objetos do Tema "Altimetria" e os objetos tridimensionais (3D) dos Temas "Hidrografia", "Transportes" e "Construções"$$, 'no_trans_ferrov',
$$with nos as (
	SELECT identificador, geometria from {schema}.no_trans_ferrov nh
),
total as (select count(*) from {schema}.no_trans_ferrov),
good as (SELECT count(distinct(a.identificador))
   from {schema}.no_trans_ferrov a, {schema}.seg_via_ferrea b
     where st_3dintersects(a.geometria, b.geometria)),
bad as (select count(nh.*) 
from {schema}.no_trans_ferrov nh
where nh.identificador not in (
SELECT a.identificador
   from {schema}.no_trans_ferrov a, {schema}.seg_via_ferrea b
     where st_3dintersects(a.geometria, b.geometria)    
))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with nos as (
	SELECT identificador, geometria from {schema}.no_trans_ferrov nh
),
total as (select count(*) from {schema}.no_trans_ferrov),
good as (SELECT count(distinct(a.identificador))
   from {schema}.no_trans_ferrov a, {schema}.seg_via_ferrea b
     where st_3dintersects(a.geometria, b.geometria)),
bad as (select count(nh.*) 
from {schema}.no_trans_ferrov nh
where nh.identificador not in (
SELECT a.identificador
   from {schema}.no_trans_ferrov a, {schema}.seg_via_ferrea b
     where st_3dintersects(a.geometria, b.geometria)    
))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select nh.* 
from {schema}.no_trans_ferrov nh
where nh.identificador not in (
SELECT a.identificador
   from {schema}.no_trans_ferrov a, {schema}.seg_via_ferrea b
     where st_3dintersects(a.geometria, b.geometria)    
) $$ );

delete from validation.rules_area where code = 'rg_4_2_3';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('rg_4_2_3', 'Consistência tridimensional (Transportes)',
$$Todos os objetos tridimensionais (3D) são consistentes entre si.
Quando os objetos se intersectam no espaço essa interseção está materializada através de vértices coincidentes e tridimensionalmente coerentes.$$,
$$Todos os objetos do Tema "Altimetria" e os objetos tridimensionais (3D) dos Temas "Hidrografia", "Transportes" e "Construções"$$, 'no_trans_ferrov',
$$with nos as (
	SELECT identificador, geometria from {schema}.no_trans_ferrov nh
	where ST_Intersects(geometria, '%1$s')
),
total as (select count(*) from {schema}.no_trans_ferrov where ST_Intersects(geometria, '%1$s')),
good as (SELECT count(distinct(a.identificador))
   from {schema}.no_trans_ferrov a, {schema}.seg_via_ferrea b
     where st_3dintersects(a.geometria, b.geometria) and ST_Intersects(a.geometria, '%1$s')),
bad as (select count(nh.*) 
from {schema}.no_trans_ferrov nh
where nh.identificador not in (
SELECT a.identificador
   from {schema}.no_trans_ferrov a, {schema}.seg_via_ferrea b
     where st_3dintersects(a.geometria, b.geometria)    
) and ST_Intersects(geometria, '%1$s'))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with nos as (
	SELECT identificador, geometria from {schema}.no_trans_ferrov nh
	where ST_Intersects(geometria, '%1$s')
),
total as (select count(*) from {schema}.no_trans_ferrov where ST_Intersects(geometria, '%1$s')),
good as (SELECT count(distinct(a.identificador))
   from {schema}.no_trans_ferrov a, {schema}.seg_via_ferrea b
     where st_3dintersects(a.geometria, b.geometria) and ST_Intersects(a.geometria, '%1$s')),
bad as (select count(nh.*) 
from {schema}.no_trans_ferrov nh
where nh.identificador not in (
SELECT a.identificador
   from {schema}.no_trans_ferrov a, {schema}.seg_via_ferrea b
     where st_3dintersects(a.geometria, b.geometria)    
) and ST_Intersects(geometria, '%1$s'))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select nh.* 
from {schema}.no_trans_ferrov nh
where nh.identificador not in (
SELECT a.identificador
   from {schema}.no_trans_ferrov a, {schema}.seg_via_ferrea b
     where st_3dintersects(a.geometria, b.geometria)    
) and ST_Intersects(geometria, '%1$s') $$ );


delete from validation.rules where code = 'rg_4_3_2';
insert into validation.rules ( code, name, rule, scope, entity, query, report ) 
values ('rg_4_3_2', 'Consistência tridimensional entre Altimetria e Hidrografia',
$$As curva_de_nivel e curso_de_agua_eixo, quando se cruzam, têm que ter o mesmo valor Z. 
Estas só se devem cruzar quando o curso_de_agua_eixo.valor_posicao_vertical tem valor '0'.$$,
$$Todos os objetos do Tema "Altimetria" e os objetos tridimensionais (3D) dos Temas "Hidrografia", "Transportes" e "Construções"$$, 'validation.intersecoes_3d',
$$with linhas1 as (
	select identificador, geometria, 'curva_de_nivel' as tabela from {schema}.curva_de_nivel
),
linhas2 as (
	select identificador, geometria, 'curso_de_agua_eixo' as tabela from {schema}.curso_de_agua_eixo where valor_posicao_vertical = '0' and delimitacao_conhecida and not ficticio
),
allintersections as (
	SELECT linhas1.tabela as tabela_1, linhas2.tabela as tabela_2, 
	linhas1.identificador as id_1, linhas1.geometria as geom_1, 
	linhas2.identificador as id_2, linhas2.geometria as geom_2, 
	ST_DumpPoints( ST_Intersection(linhas1.geometria, linhas2.geometria) ) as dp
	FROM linhas1, linhas2
	where ST_Intersects(linhas1.geometria, linhas2.geometria)
),
confirmacoes as (
	select tabela_1, tabela_2, id_1, id_2, geom_1, geom_2, 
			ST_3DIntersects(geom_1, (dp).geom ) as l1_intersection, 
			ST_3DIntersects(geom_2, (dp).geom ) as l2_intersection,
		ST_LineInterpolatePoint( geom_1, ST_LineLocatePoint(geom_1, (dp).geom)) as p1_intersecao, 
		ST_LineInterpolatePoint( geom_2, ST_LineLocatePoint(geom_2, (dp).geom)) as p2_intersecao, 
		(dp).geom as geometria
	from allintersections
),
verificar as (select id_1, id_2, tabela_1, tabela_2, geom_1, geom_2, geometria, p1_intersecao, p2_intersecao, 
	abs( st_z( p1_intersecao ) - st_z( p2_intersecao ) ) as delta_z
	from confirmacoes where not l1_intersection and not l2_intersection),
total as (select count(*) from confirmacoes),
verygood as (select count(*) from confirmacoes where l1_intersection or l2_intersection),
good as (select count(*) from verificar where delta_z <= ('%1$s'::json->>'desvio_3D')::numeric),
bad as (select count(*) from verificar where delta_z > ('%1$s'::json->>'desvio_3D')::numeric)
select total.count as total, verygood.count + good.count as good, bad.count as bad
from total, verygood, good, bad$$,
$$with linhas1 as (
	select identificador, geometria, 'curva_de_nivel' as tabela from {schema}.curva_de_nivel
),
linhas2 as (
	select identificador, geometria, 'curso_de_agua_eixo' as tabela from {schema}.curso_de_agua_eixo where valor_posicao_vertical = '0' and delimitacao_conhecida and not ficticio
),
allintersections as (
	SELECT linhas1.tabela as tabela_1, linhas2.tabela as tabela_2, 
	linhas1.identificador as id_1, linhas1.geometria as geom_1, 
	linhas2.identificador as id_2, linhas2.geometria as geom_2, 
	ST_DumpPoints( ST_Intersection(linhas1.geometria, linhas2.geometria) ) as dp
	FROM linhas1, linhas2
	where ST_Intersects(linhas1.geometria, linhas2.geometria)
),
confirmacoes as (
	select tabela_1, tabela_2, id_1, id_2, geom_1, geom_2, 
			ST_3DIntersects(geom_1, (dp).geom ) as l1_intersection, 
			ST_3DIntersects(geom_2, (dp).geom ) as l2_intersection,
		ST_LineInterpolatePoint( geom_1, ST_LineLocatePoint(geom_1, (dp).geom)) as p1_intersecao, 
		ST_LineInterpolatePoint( geom_2, ST_LineLocatePoint(geom_2, (dp).geom)) as p2_intersecao, 
		(dp).geom as geometria
	from allintersections
),
verificar as (select id_1, id_2, tabela_1, tabela_2, geom_1, geom_2, geometria, p1_intersecao, p2_intersecao, 
	st_z( p1_intersecao ) - st_z( p2_intersecao ) as delta_z
	from confirmacoes where not l1_intersection and not l2_intersection),
bad as (select * from verificar where delta_z > ('%1$s'::json->>'desvio_3D')::numeric)
select * from bad$$ );

delete from validation.rules_area where code = 'rg_4_3_2';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, report ) 
values ('rg_4_3_2', 'Consistência tridimensional entre Altimetria e Hidrografia',
$$As curva_de_nivel e curso_de_agua_eixo, quando se cruzam, têm que ter o mesmo valor Z. 
Estas só se devem cruzar quando o curso_de_agua_eixo.valor_posicao_vertical tem valor '0'.$$,
$$Todos os objetos do Tema "Altimetria" e os objetos tridimensionais (3D) dos Temas "Hidrografia", "Transportes" e "Construções"$$, 'validation.intersecoes_3d',
$$with linhas1 as (
	select identificador, geometria, 'curva_de_nivel' as tabela from {schema}.curva_de_nivel where ST_Intersects(geometria, '%1$s')
),
linhas2 as (
	select identificador, geometria, 'curso_de_agua_eixo' as tabela from {schema}.curso_de_agua_eixo where valor_posicao_vertical = '0' and delimitacao_conhecida and not ficticio and ST_Intersects(geometria, '%1$s')
),
allintersections as (
	SELECT linhas1.tabela as tabela_1, linhas2.tabela as tabela_2, 
	linhas1.identificador as id_1, linhas1.geometria as geom_1, 
	linhas2.identificador as id_2, linhas2.geometria as geom_2, 
	ST_DumpPoints( ST_Intersection(linhas1.geometria, linhas2.geometria) ) as dp
	FROM linhas1, linhas2
	where ST_Intersects(linhas1.geometria, linhas2.geometria)
),
confirmacoes as (
	select tabela_1, tabela_2, id_1, id_2, geom_1, geom_2, 
			ST_3DIntersects(geom_1, (dp).geom ) as l1_intersection, 
			ST_3DIntersects(geom_2, (dp).geom ) as l2_intersection,
		ST_LineInterpolatePoint( geom_1, ST_LineLocatePoint(geom_1, (dp).geom)) as p1_intersecao, 
		ST_LineInterpolatePoint( geom_2, ST_LineLocatePoint(geom_2, (dp).geom)) as p2_intersecao, 
		(dp).geom as geometria
	from allintersections
),
verificar as (select id_1, id_2, tabela_1, tabela_2, geom_1, geom_2, geometria, p1_intersecao, p2_intersecao, 
	abs( st_z( p1_intersecao ) - st_z( p2_intersecao ) ) as delta_z
	from confirmacoes where not l1_intersection and not l2_intersection),
total as (select count(*) from confirmacoes),
verygood as (select count(*) from confirmacoes where l1_intersection or l2_intersection),
good as (select count(*) from verificar where delta_z <= ('%2$s'::json->>'desvio_3D')::numeric),
bad as (select count(*) from verificar where delta_z > ('%2$s'::json->>'desvio_3D')::numeric)
select total.count as total, verygood.count + good.count as good, bad.count as bad
from total, verygood, good, bad$$,
$$with linhas1 as (
	select identificador, geometria, 'curva_de_nivel' as tabela from {schema}.curva_de_nivel where ST_Intersects(geometria, '%1$s')
),
linhas2 as (
	select identificador, geometria, 'curso_de_agua_eixo' as tabela from {schema}.curso_de_agua_eixo where valor_posicao_vertical = '0' and delimitacao_conhecida and not ficticio and ST_Intersects(geometria, '%1$s')
),
allintersections as (
	SELECT linhas1.tabela as tabela_1, linhas2.tabela as tabela_2, 
	linhas1.identificador as id_1, linhas1.geometria as geom_1, 
	linhas2.identificador as id_2, linhas2.geometria as geom_2, 
	ST_DumpPoints( ST_Intersection(linhas1.geometria, linhas2.geometria) ) as dp
	FROM linhas1, linhas2
	where ST_Intersects(linhas1.geometria, linhas2.geometria)
),
confirmacoes as (
	select tabela_1, tabela_2, id_1, id_2, geom_1, geom_2, 
			ST_3DIntersects(geom_1, (dp).geom ) as l1_intersection, 
			ST_3DIntersects(geom_2, (dp).geom ) as l2_intersection,
		ST_LineInterpolatePoint( geom_1, ST_LineLocatePoint(geom_1, (dp).geom)) as p1_intersecao, 
		ST_LineInterpolatePoint( geom_2, ST_LineLocatePoint(geom_2, (dp).geom)) as p2_intersecao, 
		(dp).geom as geometria
	from allintersections
),
verificar as (select id_1, id_2, tabela_1, tabela_2, geom_1, geom_2, geometria, p1_intersecao, p2_intersecao, 
	st_z( p1_intersecao ) - st_z( p2_intersecao ) as delta_z
	from confirmacoes where not l1_intersection and not l2_intersection),
bad as (select * from verificar where delta_z > ('%2$s'::json->>'desvio_3D')::numeric)
select * from bad$$ );

--
--
--

delete from validation.rules where code = 'rg_4_3_3';
insert into validation.rules ( code, name, rule, scope, entity, query, report ) 
values ('rg_4_3_3', 'Consistência tridimensional entre Altimetria e Hidrografia',
$$As curva_de_nivel e curso_de_agua_eixo não se podem cruzar quando o 
curso_de_agua_eixo.valor_posicao_vertical tem valor diferente de '0' (acima ou abaixo do solo).$$,
$$Todos os objetos do Tema "Altimetria" e os objetos tridimensionais (3D) dos Temas "Hidrografia", "Transportes" e "Construções"$$, 'validation.intersecoes_3d',
$$with linhas1 as (
	select identificador, geometria, 'curva_de_nivel' as tabela from {schema}.curva_de_nivel
),
linhas2 as (
	select identificador, geometria, 'curso_de_agua_eixo' as tabela from {schema}.curso_de_agua_eixo where valor_posicao_vertical != '0' and delimitacao_conhecida and not ficticio
),
allintersections as (
	SELECT linhas1.tabela as tabela_1, linhas2.tabela as tabela_2, 
	linhas1.identificador as id_1, linhas1.geometria as geom_1, 
	linhas2.identificador as id_2, linhas2.geometria as geom_2, 
	ST_DumpPoints( ST_Intersection(linhas1.geometria, linhas2.geometria) ) as dp
	FROM linhas1, linhas2
	where ST_Intersects(linhas1.geometria, linhas2.geometria)
),
confirmacoes as (
	select tabela_1, tabela_2, id_1, id_2, geom_1, geom_2, 
			ST_3DIntersects(geom_1, (dp).geom ) as l1_intersection, 
			ST_3DIntersects(geom_2, (dp).geom ) as l2_intersection,
		ST_LineInterpolatePoint( geom_1, ST_LineLocatePoint(geom_1, (dp).geom)) as p1_intersecao, 
		ST_LineInterpolatePoint( geom_2, ST_LineLocatePoint(geom_2, (dp).geom)) as p2_intersecao, 
		(dp).geom as geometria
	from allintersections
),
verificar as (select id_1, id_2, tabela_1, tabela_2, geom_1, geom_2, geometria, p1_intersecao, p2_intersecao, 
	abs( st_z( p1_intersecao ) - st_z( p2_intersecao ) ) as delta_z
	from confirmacoes where not l1_intersection and not l2_intersection),
total as (select count(*) from confirmacoes),
verybad as (select count(*) from confirmacoes where l1_intersection or l2_intersection),
bad as (select count(*) from verificar where delta_z <= ('%1$s'::json->>'desvio_3D')::numeric),
good as (select count(*) from verificar where delta_z > ('%1$s'::json->>'desvio_3D')::numeric)
select total.count as total, good.count as good, verybad.count + bad.count as bad
from total, verybad, good, bad$$,
$$with linhas1 as (
	select identificador, geometria, 'curva_de_nivel' as tabela from {schema}.curva_de_nivel
),
linhas2 as (
	select identificador, geometria, 'curso_de_agua_eixo' as tabela from {schema}.curso_de_agua_eixo where valor_posicao_vertical != '0' and delimitacao_conhecida and not ficticio
),
allintersections as (
	SELECT linhas1.tabela as tabela_1, linhas2.tabela as tabela_2, 
	linhas1.identificador as id_1, linhas1.geometria as geom_1, 
	linhas2.identificador as id_2, linhas2.geometria as geom_2, 
	ST_DumpPoints( ST_Intersection(linhas1.geometria, linhas2.geometria) ) as dp
	FROM linhas1, linhas2
	where ST_Intersects(linhas1.geometria, linhas2.geometria)
),
confirmacoes as (
	select tabela_1, tabela_2, id_1, id_2, geom_1, geom_2, 
			ST_3DIntersects(geom_1, (dp).geom ) as l1_intersection, 
			ST_3DIntersects(geom_2, (dp).geom ) as l2_intersection,
		ST_LineInterpolatePoint( geom_1, ST_LineLocatePoint(geom_1, (dp).geom)) as p1_intersecao, 
		ST_LineInterpolatePoint( geom_2, ST_LineLocatePoint(geom_2, (dp).geom)) as p2_intersecao, 
		(dp).geom as geometria
	from allintersections
),
verificar as (select id_1, id_2, tabela_1, tabela_2, geom_1, geom_2, geometria, p1_intersecao, p2_intersecao, 
	abs( st_z( p1_intersecao ) - st_z( p2_intersecao ) ) as delta_z
	from confirmacoes where not l1_intersection and not l2_intersection),
bad as (select * from verificar where delta_z <= ('%1$s'::json->>'desvio_3D')::numeric)
select * from bad$$ );

delete from validation.rules_area where code = 'rg_4_3_3';
insert into validation.rules_area ( code, name, rule, scope, entity, query, report ) 
values ('rg_4_3_3', 'Consistência tridimensional entre Altimetria e Hidrografia',
$$As curva_de_nivel e curso_de_agua_eixo não se podem cruzar quando o 
curso_de_agua_eixo.valor_posicao_vertical tem valor diferente de '0' (acima ou abaixo do solo).$$,
$$Todos os objetos do Tema "Altimetria" e os objetos tridimensionais (3D) dos Temas "Hidrografia", "Transportes" e "Construções"$$, 'validation.intersecoes_3d',
$$with linhas1 as (
	select identificador, geometria, 'curva_de_nivel' as tabela from {schema}.curva_de_nivel where ST_Intersects(geometria, '%1$s')
),
linhas2 as (
	select identificador, geometria, 'curso_de_agua_eixo' as tabela from {schema}.curso_de_agua_eixo where valor_posicao_vertical != '0' and delimitacao_conhecida and not ficticio and ST_Intersects(geometria, '%1$s')
),
allintersections as (
	SELECT linhas1.tabela as tabela_1, linhas2.tabela as tabela_2, 
	linhas1.identificador as id_1, linhas1.geometria as geom_1, 
	linhas2.identificador as id_2, linhas2.geometria as geom_2, 
	ST_DumpPoints( ST_Intersection(linhas1.geometria, linhas2.geometria) ) as dp
	FROM linhas1, linhas2
	where ST_Intersects(linhas1.geometria, linhas2.geometria)
),
confirmacoes as (
	select tabela_1, tabela_2, id_1, id_2, geom_1, geom_2, 
			ST_3DIntersects(geom_1, (dp).geom ) as l1_intersection, 
			ST_3DIntersects(geom_2, (dp).geom ) as l2_intersection,
		ST_LineInterpolatePoint( geom_1, ST_LineLocatePoint(geom_1, (dp).geom)) as p1_intersecao, 
		ST_LineInterpolatePoint( geom_2, ST_LineLocatePoint(geom_2, (dp).geom)) as p2_intersecao, 
		(dp).geom as geometria
	from allintersections
),
verificar as (select id_1, id_2, tabela_1, tabela_2, geom_1, geom_2, geometria, p1_intersecao, p2_intersecao, 
	abs( st_z( p1_intersecao ) - st_z( p2_intersecao ) ) as delta_z
	from confirmacoes where not l1_intersection and not l2_intersection),
total as (select count(*) from confirmacoes),
verybad as (select count(*) from confirmacoes where l1_intersection or l2_intersection),
bad as (select count(*) from verificar where delta_z <= ('%2$s'::json->>'desvio_3D')::numeric),
good as (select count(*) from verificar where delta_z > ('%2$s'::json->>'desvio_3D')::numeric)
select total.count as total, good.count as good, verybad.count + bad.count as bad
from total, verybad, good, bad$$,
$$with linhas1 as (
	select identificador, geometria, 'curva_de_nivel' as tabela from {schema}.curva_de_nivel where ST_Intersects(geometria, '%1$s')
),
linhas2 as (
	select identificador, geometria, 'curso_de_agua_eixo' as tabela from {schema}.curso_de_agua_eixo where valor_posicao_vertical != '0' and delimitacao_conhecida and not ficticio and ST_Intersects(geometria, '%1$s')
),
allintersections as (
	SELECT linhas1.tabela as tabela_1, linhas2.tabela as tabela_2, 
	linhas1.identificador as id_1, linhas1.geometria as geom_1, 
	linhas2.identificador as id_2, linhas2.geometria as geom_2, 
	ST_DumpPoints( ST_Intersection(linhas1.geometria, linhas2.geometria) ) as dp
	FROM linhas1, linhas2
	where ST_Intersects(linhas1.geometria, linhas2.geometria)
),
confirmacoes as (
	select tabela_1, tabela_2, id_1, id_2, geom_1, geom_2, 
			ST_3DIntersects(geom_1, (dp).geom ) as l1_intersection, 
			ST_3DIntersects(geom_2, (dp).geom ) as l2_intersection,
		ST_LineInterpolatePoint( geom_1, ST_LineLocatePoint(geom_1, (dp).geom)) as p1_intersecao, 
		ST_LineInterpolatePoint( geom_2, ST_LineLocatePoint(geom_2, (dp).geom)) as p2_intersecao, 
		(dp).geom as geometria
	from allintersections
),
verificar as (select id_1, id_2, tabela_1, tabela_2, geom_1, geom_2, geometria, p1_intersecao, p2_intersecao, 
	abs( st_z( p1_intersecao ) - st_z( p2_intersecao ) ) as delta_z
	from confirmacoes where not l1_intersection and not l2_intersection),
bad as (select * from verificar where delta_z <= ('%2$s'::json->>'desvio_3D')::numeric)
select * from bad$$ );


delete from validation.rules where code = 'rg_5';
insert into validation.rules ( code, versoes, name, rule, scope, query, query_nd2 )
values ('rg_5', '{v1.1.2}', 'Polígonos "fechados artificialmente"',
$$As entidades "Água lêntica", "Curso de água - área", "Margem", "Zona
húmida", "Área da infraestrutura de transporte aéreo", "Área agrícola,
florestal ou mato" e "Área artificializada" podem, quando são representados
através de objetos de geometria polígono e a sua representação extravasa a
"Área de trabalho", ser "fechados artificialmente" nos exatos limites desta
área.$$,
$$"Água lêntica", "Curso de água - área", "Margem", "Zona húmida", "Área da
infraestrutura de transporte aéreo", "Área agrícola, florestal ou mato", "Área
artificializada" e "Área de trabalho".$$,
$$ select * from validation.rg5_validation () $$,
$$ select * from validation.rg5_validation () $$ );
insert into validation.rules ( code, versoes, name, rule, scope, query, query_nd2 )
values ('rg_5', '{v2.0.1,v2.0.2}', 'Polígonos "fechados artificialmente"',
$$As entidades "Água lêntica", "Curso de água - área", "Margem", "Zona
húmida", "Área da infraestrutura de transporte aéreo", "Área agrícola,
florestal ou mato" e "Área artificializada" podem, quando são representados
através de objetos de geometria polígono e a sua representação extravasa a
"Área de trabalho", ser "fechados artificialmente" nos exatos limites desta
área.$$,
$$"Água lêntica", "Curso de água - área", "Margem", "Zona húmida", "Área da
infraestrutura de transporte aéreo", "Área agrícola, florestal ou mato", "Área
artificializada" e "Área de trabalho".$$,
$$ select * from validation.rg5_validation_v2 () $$,
$$ select * from validation.rg5_validation_v2 () $$ );

delete from validation.rules_area where code = 'rg_5';
insert into validation.rules_area ( code, versoes, name, rule, scope, query, query_nd2 )
values ('rg_5', '{v1.1.2}', 'Polígonos "fechados artificialmente"',
$$As entidades "Água lêntica", "Curso de água - área", "Margem", "Zona
húmida", "Área da infraestrutura de transporte aéreo", "Área agrícola,
florestal ou mato" e "Área artificializada" podem, quando são representados
através de objetos de geometria polígono e a sua representação extravasa a
"Área de trabalho", ser "fechados artificialmente" nos exatos limites desta
área.$$,
$$"Água lêntica", "Curso de água - área", "Margem", "Zona húmida", "Área da
infraestrutura de transporte aéreo", "Área agrícola, florestal ou mato", "Área
artificializada" e "Área de trabalho".$$,
$$ select * from validation.rg5_validation ('%s'::geometry) $$,
$$ select * from validation.rg5_validation ('%s'::geometry) $$ );
insert into validation.rules_area ( code, versoes, name, rule, scope, query, query_nd2 )
values ('rg_5', '{v2.0.1,v2.0.2}', 'Polígonos "fechados artificialmente"',
$$As entidades "Água lêntica", "Curso de água - área", "Margem", "Zona
húmida", "Área da infraestrutura de transporte aéreo", "Área agrícola,
florestal ou mato" e "Área artificializada" podem, quando são representados
através de objetos de geometria polígono e a sua representação extravasa a
"Área de trabalho", ser "fechados artificialmente" nos exatos limites desta
área.$$,
$$"Água lêntica", "Curso de água - área", "Margem", "Zona húmida", "Área da
infraestrutura de transporte aéreo", "Área agrícola, florestal ou mato", "Área
artificializada" e "Área de trabalho".$$,
$$ select * from validation.rg5_validation_v2 ('%s'::geometry) $$,
$$ select * from validation.rg5_validation_v2 ('%s'::geometry) $$ );


delete from validation.rules where code = 'rg_6';
insert into validation.rules ( code, name, rule, scope, query, query_nd2 ) 
values ('rg_6', 'Utilização da letra maiúscula inicial', 
$$A letra maiúscula inicial é obrigatória nos nomes de locais ou regiões, quando
designam siglas, símbolos ou abreviaturas internacionais e nos nomes das
instituições públicas e privadas (Serra da Estrela; Comissão de Coordenação e
Desenvolvimento Regional; Serviço de Estrangeiros e Fronteiras; etc.).$$,
$$Todos os atributos "nome" (tipo texto).$$,
$$ select * from validation.rg6_validation () $$,
$$ select * from validation.rg6_validation () $$ );

delete from validation.rules_area where code = 'rg_6';
insert into validation.rules_area ( code, name, rule, scope, query, query_nd2, is_global )
values ('rg_6', 'Utilização da letra maiúscula inicial', 
$$A letra maiúscula inicial é obrigatória nos nomes de locais ou regiões, quando
designam siglas, símbolos ou abreviaturas internacionais e nos nomes das
instituições públicas e privadas (Serra da Estrela; Comissão de Coordenação e
Desenvolvimento Regional; Serviço de Estrangeiros e Fronteiras; etc.).$$,
$$Todos os atributos "nome" (tipo texto).$$,
$$ select * from validation.rg6_validation () $$,
$$ select * from validation.rg6_validation () $$, true );


delete from validation.rules where code = 'rg_7';
insert into validation.rules ( code, name, rule, scope, query, query_nd2 ) 
values ('rg_7', 'Atribuição de nomes', 
$$O nome dos objetos é inscrito por extenso, sem abreviaturas e com recurso a
caracteres portugueses (ex. Ribeira Grande, Praia Verde, Sapal da Ilha do
Coco, Aeroporto Francisco Sá Carneiro, Estação de Caminhos de Ferro de
Abrantes, Ponte Vasco da Gama, etc.).$$,
$$Todos os atributos "nome", "nomeAlternativo", "nomeDoProprietario" e
"nomeDoProdutor", à exceção do atributo "nome" da "Via rodoviária". $$,
$$ select * from validation.rg7_validation () $$,
$$ select * from validation.rg7_validation () $$ );

delete from validation.rules_area where code = 'rg_7';
insert into validation.rules_area ( code, name, rule, scope, query, query_nd2, is_global )
values ('rg_7', 'Atribuição de nomes', 
$$O nome dos objetos é inscrito por extenso, sem abreviaturas e com recurso a
caracteres portugueses (ex. Ribeira Grande, Praia Verde, Sapal da Ilha do
Coco, Aeroporto Francisco Sá Carneiro, Estação de Caminhos de Ferro de
Abrantes, Ponte Vasco da Gama, etc.).$$,
$$Todos os atributos "nome", "nomeAlternativo", "nomeDoProprietario" e
"nomeDoProdutor", à exceção do atributo "nome" da "Via rodoviária". $$,
$$ select * from validation.rg7_validation () $$,
$$ select * from validation.rg7_validation () $$, true );

-- Regras Específicas

-- Regras do tema Altimetria


delete from validation.rules where code = 're3_1_1';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re3_1_1', 'Continuidade das curvas de nível (Parte 1)', 
$$A "Curva de nível" é representada por uma linha contínua sem interrupção.$$, 
$$"Curva de nível".$$, 'curva_de_nivel',
$$with 
total as (select count(*) from {schema}.curva_de_nivel),
good as (select count(cdn.identificador)
	from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
	where ST_IsClosed(cdn.geometria) or (ST_IsClosed(cdn.geometria) is not true
		and st_intersects(cdn.geometria, ST_Boundary(adt.geometria)))
),
bad as (select count(cdn.identificador) 
	from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
	where ST_IsClosed(cdn.geometria) is not true
		and st_intersects(cdn.geometria, ST_Boundary(adt.geometria)) is not true
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.curva_de_nivel),
good as (select count(cdn.identificador)
	from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
	where ST_IsClosed(cdn.geometria) or (ST_IsClosed(cdn.geometria) is not true
		and st_intersects(cdn.geometria, ST_Boundary(adt.geometria)))
),
bad as (select count(cdn.identificador) 
	from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
	where ST_IsClosed(cdn.geometria) is not true
		and st_intersects(cdn.geometria, ST_Boundary(adt.geometria)) is not true
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select cdn.*
	from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
	where ST_IsClosed(cdn.geometria) is not true
		and st_intersects(cdn.geometria, ST_Boundary(adt.geometria)) is not true$$ );

delete from validation.rules_area where code = 're3_1_1';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re3_1_1', 'Continuidade das curvas de nível (Parte 1)', 
$$A "Curva de nível" é representada por uma linha contínua sem interrupção.$$, 
$$"Curva de nível".$$, 'curva_de_nivel',
$$with 
total as (select count(*) from {schema}.curva_de_nivel),
good as (select count(cdn.identificador)
	from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
	where ST_IsClosed(cdn.geometria) or (ST_IsClosed(cdn.geometria) is not true
		and st_intersects(cdn.geometria, ST_Boundary(adt.geometria))
		and ST_Intersects(cdn.geometria, '%1$s'::geometry))
),
bad as (select count(cdn.identificador) 
	from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
	where ST_IsClosed(cdn.geometria) is not true
		and st_intersects(cdn.geometria, ST_Boundary(adt.geometria)) is not true and ST_Intersects(cdn.geometria, '%1$s'::geometry)
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.curva_de_nivel),
good as (select count(cdn.identificador)
	from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
	where ST_IsClosed(cdn.geometria) or (ST_IsClosed(cdn.geometria) is not true
		and st_intersects(cdn.geometria, ST_Boundary(adt.geometria))
		and ST_Intersects(cdn.geometria, '%1$s'::geometry))
),
bad as (select count(cdn.identificador) 
	from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
	where ST_IsClosed(cdn.geometria) is not true
		and st_intersects(cdn.geometria, ST_Boundary(adt.geometria)) is not true
		and ST_Intersects(cdn.geometria, '%1$s'::geometry)
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select cdn.*
	from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
	where ST_IsClosed(cdn.geometria) is not true
		and st_intersects(cdn.geometria, ST_Boundary(adt.geometria)) is not true and ST_Intersects(cdn.geometria, '%1$s'::geometry)$$ );


delete from validation.rules where code = 're3_1_2';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re3_1_2', 'Continuidade das curvas de nível (Parte 2)', 
$$Todos os vértices de uma "Curva de nível" devem apresentar o mesmo valor
altimétrico.$$, 
$$"Curva de nível".$$, 'curva_de_nivel',
$$with 
total as (select count(*) from {schema}.curva_de_nivel),
good as (select count(*) from {schema}.curva_de_nivel where ST_ZMax(geometria) = ST_ZMin(geometria)),
bad as (select count(*) from {schema}.curva_de_nivel where ST_ZMax(geometria) != ST_ZMin(geometria))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.curva_de_nivel),
good as (select count(*) from {schema}.curva_de_nivel where ST_ZMax(geometria) = ST_ZMin(geometria)),
bad as (select count(*) from {schema}.curva_de_nivel where ST_ZMax(geometria) != ST_ZMin(geometria))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select * from {schema}.curva_de_nivel where ST_ZMax(geometria) != ST_ZMin(geometria)$$ );

delete from validation.rules_area where code = 're3_1_2';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re3_1_2', 'Continuidade das curvas de nível (Parte 2)', 
$$Todos os vértices de uma "Curva de nível" devem apresentar o mesmo valor
altimétrico.$$, 
$$"Curva de nível".$$, 'curva_de_nivel',
$$with 
total as (select count(*) from {schema}.curva_de_nivel),
good as (select count(*) from {schema}.curva_de_nivel where ST_ZMax(geometria) = ST_ZMin(geometria) and ST_Intersects(geometria, '%1$s'::geometry)),
bad as (select count(*) from {schema}.curva_de_nivel where ST_ZMax(geometria) != ST_ZMin(geometria) and ST_Intersects(geometria, '%1$s'::geometry))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.curva_de_nivel),
good as (select count(*) from {schema}.curva_de_nivel where ST_ZMax(geometria) = ST_ZMin(geometria) and ST_Intersects(geometria, '%1$s'::geometry)),
bad as (select count(*) from {schema}.curva_de_nivel where ST_ZMax(geometria) != ST_ZMin(geometria) and ST_Intersects(geometria, '%1$s'::geometry))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select * from {schema}.curva_de_nivel where ST_ZMax(geometria) != ST_ZMin(geometria) and ST_Intersects(geometria, '%1$s'::geometry)$$ );

-- Só verifico as mestres e secundárias
-- select count(*) from {schema}.curva_de_nivel where valor_tipo_curva <= 2
delete from validation.rules where code = 're3_2';
insert into validation.rules ( code, name, rule, scope,  query, query_nd2 ) 
values ('re3_2', 'Equidistância natural', 
$$A equidistância natural entre os objetos "Curva de nível" é:
 - NdD1: 2 m;
 - NdD2: 5 m.$$, 
$$"Curva de nível".$$,
$$select * from validation.re3_2_validation (1, '%s'::json)$$,
$$select * from validation.re3_2_validation (2, '%s'::json)$$ );

delete from validation.rules_area where code = 're3_2';
insert into validation.rules_area ( code, name, rule, scope,  query, query_nd2 ) 
values ('re3_2', 'Equidistância natural', 
$$A equidistância natural entre os objetos "Curva de nível" é:
 - NdD1: 2 m;
 - NdD2: 5 m.$$, 
$$"Curva de nível".$$,
$$select * from validation.re3_2_validation(1, '%s'::geometry, '%s'::json)$$,
$$select * from validation.re3_2_validation(2, '%s'::geometry, '%s'::json)$$ );

-- Pontos cotados
delete from validation.rules where code = 're3_3';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re3_3', 'Pontos cotados', 
$$É recolhido pelo menos um "Ponto cotado" nas zonas planas onde a distância
horizontal entre os objetos "Curva de nível" exceda os seguintes valores:
NdD1: 100 m;
NdD2: 500 m.$$, 
$$"Ponto cotado".$$, 'ponto_cotado',
$$with 
total as (select count(*) from {schema}.ponto_cotado),
good as (select count(*) from {schema}.ponto_cotado),
bad as (with cdn_buffer as (select st_union(st_buffer(cdn.geometria, ('%1$s'::json->>'re3_3_ndd1')::int)) as geometria from {schema}.curva_de_nivel cdn),
	pc_buffer as (select st_union(st_buffer(pc.geometria, ('%1$s'::json->>'re3_3_ndd1')::int)) as geometria from {schema}.ponto_cotado pc),
	difference as (select (st_dump(st_difference( st_difference(adt.geometria, cdn_buffer.geometria), pc_buffer.geometria))).*
		from validation.area_trabalho_multi adt, cdn_buffer, pc_buffer)
	select count(d.*)
	from difference d
	where st_area(d.geom) > 3000 and ST_MaxDistance(d.geom, d.geom) < (st_area(d.geom)/10))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.ponto_cotado),
good as (select count(*) from {schema}.ponto_cotado),
bad as (with cdn_buffer as (select st_union(st_buffer(cdn.geometria, ('%1$s'::json->>'re3_3_ndd2')::int)) as geometria from {schema}.curva_de_nivel cdn),
	pc_buffer as (select st_union(st_buffer(pc.geometria, ('%1$s'::json->>'re3_3_ndd2')::int)) as geometria from {schema}.ponto_cotado pc),
	difference as (select (st_dump(st_difference( st_difference(adt.geometria, cdn_buffer.geometria), pc_buffer.geometria))).*
		from validation.area_trabalho_multi adt, cdn_buffer, pc_buffer)
	select count(d.*)
	from difference d
	where st_area(d.geom) > 3000 and ST_MaxDistance(d.geom, d.geom) < (st_area(d.geom)/10))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with cdn_buffer as (select st_union(st_buffer(cdn.geometria, ('%1$s'::json->>'re3_3_ndd1')::int)) as geometria from {schema}.curva_de_nivel cdn),
pc_buffer as (select st_union(st_buffer(pc.geometria, ('%1$s'::json->>'re3_3_ndd1')::int)) as geometria from {schema}.ponto_cotado pc),
difference as (select (st_dump(st_difference( st_difference(adt.geometria, cdn_buffer.geometria), pc_buffer.geometria))).*
	from validation.area_trabalho_multi adt, cdn_buffer, pc_buffer)
select uuid_generate_v1mc() as identificador, now() as inicio_objeto, null as fim_objeto, 1 as valor_classifica_las, ST_Force3D(st_centroid(d.geom)) as geometria
from difference d
where st_area(d.geom) > 3000 and ST_MaxDistance(d.geom, d.geom) < (st_area(d.geom)/10)$$ );

delete from validation.rules_area where code = 're3_3';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re3_3', 'Pontos cotados', 
$$É recolhido pelo menos um "Ponto cotado" nas zonas planas onde a distância
horizontal entre os objetos "Curva de nível" exceda os seguintes valores:
NdD1: 100 m;
NdD2: 500 m.$$, 
$$"Ponto cotado".$$, 'ponto_cotado',
$$with 
total as (select count(*) from {schema}.ponto_cotado),
good as (select count(*) from {schema}.ponto_cotado where ST_Intersects(geometria, '%1$s'::geometry)),
bad as (with cdn_buffer as (select st_union(st_buffer(cdn.geometria, ('%2$s'::json->>'re3_3_ndd1')::int)) as geometria from {schema}.curva_de_nivel cdn where ST_Intersects(geometria, '%1$s'::geometry)),
	pc_buffer as (select st_union(st_buffer(pc.geometria, ('%2$s'::json->>'re3_3_ndd1')::int)) as geometria from {schema}.ponto_cotado pc where ST_Intersects(geometria, '%1$s'::geometry)),
	difference as (select (st_dump(st_difference( st_difference('%1$s', cdn_buffer.geometria), pc_buffer.geometria))).*
		from cdn_buffer, pc_buffer)
	select count(d.*)
	from difference d
	where st_area(d.geom) > 3000 and ST_MaxDistance(d.geom, d.geom) < (st_area(d.geom)/10))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.ponto_cotado),
good as (select count(*) from {schema}.ponto_cotado where ST_Intersects(geometria, '%1$s'::geometry)),
bad as (with cdn_buffer as (select st_union(st_buffer(cdn.geometria, ('%2$s'::json->>'re3_3_ndd2')::int)) as geometria from {schema}.curva_de_nivel cdn where ST_Intersects(geometria, '%1$s'::geometry)),
	pc_buffer as (select st_union(st_buffer(pc.geometria, ('%2$s'::json->>'re3_3_ndd2')::int)) as geometria from {schema}.ponto_cotado pc where ST_Intersects(geometria, '%1$s'::geometry)),
	difference as (select (st_dump(st_difference( st_difference('%1$s', cdn_buffer.geometria), pc_buffer.geometria))).*
		from cdn_buffer, pc_buffer)
	select count(d.*)
	from difference d
	where st_area(d.geom) > 3000 and ST_MaxDistance(d.geom, d.geom) < (st_area(d.geom)/10))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with cdn_buffer as (select st_union(st_buffer(cdn.geometria, ('%2$s'::json->>'re3_3_ndd1')::int)) as geometria from {schema}.curva_de_nivel cdn where ST_Intersects(geometria, '%1$s'::geometry)),
pc_buffer as (select st_union(st_buffer(pc.geometria, ('%2$s'::json->>'re3_3_ndd1')::int)) as geometria from {schema}.ponto_cotado pc where ST_Intersects(geometria, '%1$s'::geometry)),
difference as (select (st_dump(st_difference( st_difference('%1$s', cdn_buffer.geometria), pc_buffer.geometria))).*
	from cdn_buffer, pc_buffer)
select uuid_generate_v1mc() as identificador, now() as inicio_objeto, null as fim_objeto, 1 as valor_classifica_las, ST_Force3D(st_centroid(d.geom)) as geometria
from difference d
where st_area(d.geom) > 3000 and ST_MaxDistance(d.geom, d.geom) < (st_area(d.geom)/10)$$ );

-- Regras do tema Hidrografia

delete from validation.rules where code = 're4_1_1';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re4_1_1', 'Representação de água lêntica (Parte 1)', 
$$A representação de "Água lêntica" ("Lagoa", "Albufeira" ou "Charca") é
sempre feita à custa da cota plena de armazenamento. Se este valor
for desconhecido, é feita a partir da informação visual disponível.$$, 
$$"Água lêntica".$$, 'agua_lentica',
$$with 
total as (select count(*) from {schema}.agua_lentica),
good as (select count(*) from {schema}.agua_lentica al where (cota_plena_armazenamento=true) or (cota_plena_armazenamento=false and data_fonte_dados is not null)),
bad as (select count(*) from {schema}.agua_lentica al where (cota_plena_armazenamento=false and data_fonte_dados is null))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.agua_lentica),
good as (select count(*) from {schema}.agua_lentica al where (cota_plena_armazenamento=true) or (cota_plena_armazenamento=false and data_fonte_dados is not null)),
bad as (select count(*) from {schema}.agua_lentica al where (cota_plena_armazenamento=false and data_fonte_dados is null))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select * from {schema}.agua_lentica al where (cota_plena_armazenamento=false and data_fonte_dados is null)$$ );

delete from validation.rules_area where code = 're4_1_1';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re4_1_1', 'Representação de água lêntica (Parte 1)', 
$$A representação de "Água lêntica" ("Lagoa", "Albufeira" ou "Charca") é
sempre feita à custa da cota plena de armazenamento. Se este valor
for desconhecido, é feita a partir da informação visual disponível.$$, 
$$"Água lêntica".$$, 'agua_lentica',
$$with 
total as (select count(*) from {schema}.agua_lentica where ST_Intersects(geometria, '%1$s')),
good as (select count(*) from {schema}.agua_lentica al where (cota_plena_armazenamento=true) or (cota_plena_armazenamento=false and data_fonte_dados is not null) and ST_Intersects(geometria, '%1$s')),
bad as (select count(*) from {schema}.agua_lentica al where (cota_plena_armazenamento=false and data_fonte_dados is null) and ST_Intersects(geometria, '%1$s'))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.agua_lentica where ST_Intersects(geometria, '%1$s')),
good as (select count(*) from {schema}.agua_lentica al where (cota_plena_armazenamento=true) or (cota_plena_armazenamento=false and data_fonte_dados is not null) and ST_Intersects(geometria, '%1$s')),
bad as (select count(*) from {schema}.agua_lentica al where (cota_plena_armazenamento=false and data_fonte_dados is null) and ST_Intersects(geometria, '%1$s'))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select * from {schema}.agua_lentica al where (cota_plena_armazenamento=false and data_fonte_dados is null) and ST_Intersects(geometria, '%1$s')$$ );


delete from validation.rules where code = 're4_1_2';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re4_1_2', 'Representação de água lêntica (Parte 2 - geometria)', 
$$A representação de "Água lêntica" ("Lagoa", "Albufeira" ou "Charca") é
sempre feita à custa da cota plena de armazenamento. Este valor deve ser consistente na sua geometria (constante).$$, 
$$"Água lêntica".$$, 'agua_lentica',
$$with 
total as (select count(*) from {schema}.agua_lentica),
good as (select count(*) from {schema}.agua_lentica al where ST_ZMax(geometria) = ST_ZMin(geometria)),
bad as (select count(*) from {schema}.agua_lentica al where ST_ZMax(geometria) != ST_ZMin(geometria))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.agua_lentica),
good as (select count(*) from {schema}.agua_lentica al where ST_ZMax(geometria) = ST_ZMin(geometria)),
bad as (select count(*) from {schema}.agua_lentica al where ST_ZMax(geometria) != ST_ZMin(geometria))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select * from {schema}.agua_lentica al where ST_ZMax(geometria) != ST_ZMin(geometria)$$ );

delete from validation.rules_area where code = 're4_1_2';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re4_1_2', 'Representação de água lêntica (Parte 2 - geometria)', 
$$A representação de "Água lêntica" ("Lagoa", "Albufeira" ou "Charca") é
sempre feita à custa da cota plena de armazenamento. Este valor deve ser consistente na sua geometria (constante).$$, 
$$"Água lêntica".$$, 'agua_lentica',
$$with 
total as (select count(*) from {schema}.agua_lentica where ST_Intersects(geometria, '%1$s')),
good as (select count(*) from {schema}.agua_lentica al where ST_ZMax(geometria) = ST_ZMin(geometria) and ST_Intersects(geometria, '%1$s')),
bad as (select count(*) from {schema}.agua_lentica al where ST_ZMax(geometria) != ST_ZMin(geometria) and ST_Intersects(geometria, '%1$s'))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.agua_lentica where ST_Intersects(geometria, '%1$s')),
good as (select count(*) from {schema}.agua_lentica al where ST_ZMax(geometria) = ST_ZMin(geometria) and ST_Intersects(geometria, '%1$s')),
bad as (select count(*) from {schema}.agua_lentica al where ST_ZMax(geometria) != ST_ZMin(geometria) and ST_Intersects(geometria, '%1$s'))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select * from {schema}.agua_lentica al where ST_ZMax(geometria) != ST_ZMin(geometria) and ST_Intersects(geometria, '%1$s')$$ );


delete from validation.rules where code = 're4_2';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re4_2', 'Representação do dique, da comporta e da eclusa', 
$$A representação do "Dique" é sempre feita através de uma linha.
A representação da "Comporta" é sempre feita através de uma única linha
(independentemente da área que ocupa, do número de comportas individuais e do nível de detalhe).
A representação da "Eclusa" é sempre feita através de um polígono.$$, 
$$"Barreira".$$, 'barreira',
$$with 
total_a as (select count(*) from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (lower(vb.descricao) = 'dique' or lower(vb.descricao) = 'comporta')),
good_a as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and (lower(vb.descricao) = 'dique' or lower(vb.descricao) = 'comporta')
	and geometrytype(b.geometria) = 'LINESTRING'),
bad_a as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and (lower(vb.descricao) = 'dique' or lower(vb.descricao) = 'comporta')
	and geometrytype(b.geometria) != 'LINESTRING'),
total_b as (select count(*) from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and lower(vb.descricao) = 'eclusa'),
good_b as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and lower(vb.descricao) = 'eclusa'
	and geometrytype(b.geometria) = 'POLYGON'),
bad_b as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and lower(vb.descricao) = 'eclusa'
	and geometrytype(b.geometria) != 'POLYGON')
select total_a.count + total_b.count as total, good_a.count + good_b.count as good, bad_a.count + bad_b.count as bad
from total_a, good_a, bad_a, total_b, good_b, bad_b $$,
$$with 
total_a as (select count(*) from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (lower(vb.descricao) = 'dique' or lower(vb.descricao) = 'comporta')),
good_a as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and (lower(vb.descricao) = 'dique' or lower(vb.descricao) = 'comporta')
	and geometrytype(b.geometria) = 'LINESTRING'),
bad_a as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and (lower(vb.descricao) = 'dique' or lower(vb.descricao) = 'comporta')
	and geometrytype(b.geometria) != 'LINESTRING'),
total_b as (select count(*) from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and lower(vb.descricao) = 'eclusa'),
good_b as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and lower(vb.descricao) = 'eclusa'
	and geometrytype(b.geometria) = 'POLYGON'),
bad_b as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and lower(vb.descricao) = 'eclusa'
	and geometrytype(b.geometria) != 'POLYGON')
select total_a.count + total_b.count as total, good_a.count + good_b.count as good, bad_a.count + bad_b.count as bad
from total_a, good_a, bad_a, total_b, good_b, bad_b $$,
$$select b.*
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and (lower(vb.descricao) = 'dique' or lower(vb.descricao) = 'comporta')
	and geometrytype(b.geometria) != 'LINESTRING'
union	
select b.*	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and lower(vb.descricao) = 'eclusa'
	and geometrytype(b.geometria) != 'POLYGON' $$ );

delete from validation.rules_area where code = 're4_2';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re4_2', 'Representação do dique, da comporta e da eclusa', 
$$A representação do "Dique" é sempre feita através de uma linha.
A representação da "Comporta" é sempre feita através de uma única linha
(independentemente da área que ocupa, do número de comportas individuais e do nível de detalhe).
A representação da "Eclusa" é sempre feita através de um polígono.$$, 
$$"Barreira".$$, 'barreira',
$$with 
total_a as (select count(*) from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (lower(vb.descricao) = 'dique' or lower(vb.descricao) = 'comporta') and ST_Intersects(geometria, '%1$s')),
good_a as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and (lower(vb.descricao) = 'dique' or lower(vb.descricao) = 'comporta')
	and geometrytype(b.geometria) = 'LINESTRING' and ST_Intersects(geometria, '%1$s')),
bad_a as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and (lower(vb.descricao) = 'dique' or lower(vb.descricao) = 'comporta')
	and geometrytype(b.geometria) != 'LINESTRING' and ST_Intersects(geometria, '%1$s')),
total_b as (select count(*) from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and lower(vb.descricao) = 'eclusa' and ST_Intersects(geometria, '%1$s')),
good_b as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and lower(vb.descricao) = 'eclusa'
	and geometrytype(b.geometria) = 'POLYGON' and ST_Intersects(geometria, '%1$s')),
bad_b as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and lower(vb.descricao) = 'eclusa'
	and geometrytype(b.geometria) != 'POLYGON' and ST_Intersects(geometria, '%1$s'))
select total_a.count + total_b.count as total, good_a.count + good_b.count as good, bad_a.count + bad_b.count as bad
from total_a, good_a, bad_a, total_b, good_b, bad_b $$,
$$with 
total_a as (select count(*) from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (lower(vb.descricao) = 'dique' or lower(vb.descricao) = 'comporta') and ST_Intersects(geometria, '%1$s')),
good_a as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and (lower(vb.descricao) = 'dique' or lower(vb.descricao) = 'comporta')
	and geometrytype(b.geometria) = 'LINESTRING' and ST_Intersects(geometria, '%1$s')),
bad_a as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and (lower(vb.descricao) = 'dique' or lower(vb.descricao) = 'comporta')
	and geometrytype(b.geometria) != 'LINESTRING' and ST_Intersects(geometria, '%1$s')),
total_b as (select count(*) from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and lower(vb.descricao) = 'eclusa' and ST_Intersects(geometria, '%1$s')),
good_b as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and lower(vb.descricao) = 'eclusa'
	and geometrytype(b.geometria) = 'POLYGON' and ST_Intersects(geometria, '%1$s')),
bad_b as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and lower(vb.descricao) = 'eclusa'
	and geometrytype(b.geometria) != 'POLYGON' and ST_Intersects(geometria, '%1$s'))
select total_a.count + total_b.count as total, good_a.count + good_b.count as good, bad_a.count + bad_b.count as bad
from total_a, good_a, bad_a, total_b, good_b, bad_b $$,
$$select b.*
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and (lower(vb.descricao) = 'dique' or lower(vb.descricao) = 'comporta')
	and geometrytype(b.geometria) != 'LINESTRING' and ST_Intersects(geometria, '%1$s')
union	
select b.*	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador 
	and lower(vb.descricao) = 'eclusa'
	and geometrytype(b.geometria) != 'POLYGON' and ST_Intersects(geometria, '%1$s')$$ );

-- TODO
--Sempre que for possível, a representação desta linha deve coincidir com o
--nível pleno de armazenamento (representada na zona mais a montante) e,
--num dos seus vértices, com o objeto "Nó hidrográfico" ("Regulação de fluxo").

delete from validation.rules where code = 're4_3_1';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re4_3_1', 'Representação da barreira da barragem de betão ou terra e da barreira do açude ou represa (Parte 1)', 
$$A representação da "Barreira da barragem de betão", "Barreira da barragem
de terra" e "Barreira do açude ou represa" é sempre feita através de uma
única linha (independentemente da área que ocupa e do nível de detalhe).
Sempre que for possível, a representação desta linha deve coincidir com o
nível pleno de armazenamento (representada na zona mais a montante) e,
num dos seus vértices, com o objeto "Nó hidrográfico" ("Regulação de fluxo").$$,
$$"Barreira" e "Edifício".$$, 'barreira',
$$with 
total as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra' or vb.descricao ilike '%%açude ou represa')),
good as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra' or vb.descricao ilike '%%açude ou represa') and geometrytype(b.geometria) = 'LINESTRING'),
bad as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra' or vb.descricao ilike '%%açude ou represa') and geometrytype(b.geometria) != 'LINESTRING')
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra' or vb.descricao ilike '%%açude ou represa')),
good as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra' or vb.descricao ilike '%%açude ou represa') and geometrytype(b.geometria) = 'LINESTRING'),
bad as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra' or vb.descricao ilike '%%açude ou represa') and geometrytype(b.geometria) != 'LINESTRING')
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select b.*
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra' or vb.descricao ilike '%%açude ou represa') and geometrytype(b.geometria) != 'LINESTRING'$$ );

delete from validation.rules_area where code = 're4_3_1';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re4_3_1', 'Representação da barreira da barragem de betão ou terra e da barreira do açude ou represa (Parte 1)', 
$$A representação da "Barreira da barragem de betão", "Barreira da barragem
de terra" e "Barreira do açude ou represa" é sempre feita através de uma
única linha (independentemente da área que ocupa e do nível de detalhe).
Sempre que for possível, a representação desta linha deve coincidir com o
nível pleno de armazenamento (representada na zona mais a montante) e,
num dos seus vértices, com o objeto "Nó hidrográfico" ("Regulação de fluxo").$$,
$$"Barreira" e "Edifício".$$, 'barreira',
$$with 
total as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra' or vb.descricao ilike '%%açude ou represa')
	and ST_Intersects(geometria, '%1$s')),
good as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra' or vb.descricao ilike '%%açude ou represa') and geometrytype(b.geometria) = 'LINESTRING'
	and ST_Intersects(geometria, '%1$s')),
bad as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra' or vb.descricao ilike '%%açude ou represa') and geometrytype(b.geometria) != 'LINESTRING'
	and ST_Intersects(geometria, '%1$s'))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra' or vb.descricao ilike '%%açude ou represa')
	and ST_Intersects(geometria, '%1$s')),
good as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra' or vb.descricao ilike '%%açude ou represa') and geometrytype(b.geometria) = 'LINESTRING'
	and ST_Intersects(geometria, '%1$s')),
bad as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra' or vb.descricao ilike '%%açude ou represa') and geometrytype(b.geometria) != 'LINESTRING'
	and ST_Intersects(geometria, '%1$s'))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select b.*
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra' or vb.descricao ilike '%%açude ou represa') and geometrytype(b.geometria) != 'LINESTRING' and ST_Intersects(geometria, '%1$s')$$ );


delete from validation.rules where code = 're4_3_2';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re4_3_2', 'Representação da barreira da barragem de betão ou terra e da barreira do açude ou represa (Parte 2)', 
$$Se estivermos perante uma "Barreira da barragem de betão" ou uma
"Barreira da barragem de terra" terá ainda de ser feita a representação da
construção "Barragem" referida no atributo "valorFormaEdificio" do objeto
"Edificio".$$,
$$"Barreira" e "Edifício".$$, 'barreira',
$$with 
total as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra')),
good as (select count(*)
		from {schema}.barreira b, {schema}.valor_barreira vb
		where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra')
		and exists (select e.* 
	from {schema}.edificio e, {schema}.valor_forma_edificio vfe
	where e.valor_forma_edificio = vfe.identificador and lower(vfe.descricao) = 'barragem' and st_within(b.geometria, e.geometria ) )),
bad as (select count(*)
		from {schema}.barreira b, {schema}.valor_barreira vb
		where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra')
		and not exists (select e.* 
	from {schema}.edificio e, {schema}.valor_forma_edificio vfe
	where e.valor_forma_edificio = vfe.identificador and lower(vfe.descricao) = 'barragem' and st_within(b.geometria, e.geometria ) ))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra')),
good as (select count(*)
		from {schema}.barreira b, {schema}.valor_barreira vb
		where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra')
		and exists (select e.* 
	from {schema}.edificio e, {schema}.valor_forma_edificio vfe
	where e.valor_forma_edificio = vfe.identificador and lower(vfe.descricao) = 'barragem' and st_within(b.geometria, e.geometria ) )),
bad as (select count(*)
		from {schema}.barreira b, {schema}.valor_barreira vb
		where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra')
		and not exists (select e.* 
	from {schema}.edificio e, {schema}.valor_forma_edificio vfe
	where e.valor_forma_edificio = vfe.identificador and lower(vfe.descricao) = 'barragem' and st_within(b.geometria, e.geometria ) ))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select b.*
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra')
	and not exists (select e.* 
from {schema}.edificio e, {schema}.valor_forma_edificio vfe
where e.valor_forma_edificio = vfe.identificador and lower(vfe.descricao) = 'barragem' and st_within(b.geometria, e.geometria ) )$$ );

delete from validation.rules_area where code = 're4_3_2';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re4_3_2', 'Representação da barreira da barragem de betão ou terra e da barreira do açude ou represa (Parte 2)', 
$$Se estivermos perante uma "Barreira da barragem de betão" ou uma
"Barreira da barragem de terra" terá ainda de ser feita a representação da
construção "Barragem" referida no atributo "valorFormaEdificio" do objeto
"Edificio".$$,
$$"Barreira" e "Edifício".$$, 'barreira',
$$with 
total as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra')
	and ST_Intersects(geometria, '%1$s')),
good as (select count(*)
		from {schema}.barreira b, {schema}.valor_barreira vb
		where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra')
		and ST_Intersects(geometria, '%1$s')
		and exists (select e.* 
	from {schema}.edificio e, {schema}.valor_forma_edificio vfe
	where e.valor_forma_edificio = vfe.identificador and lower(vfe.descricao) = 'barragem' and st_within(b.geometria, e.geometria ) )),
bad as (select count(*)
		from {schema}.barreira b, {schema}.valor_barreira vb
		where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra')
		and ST_Intersects(geometria, '%1$s')
		and not exists (select e.* 
	from {schema}.edificio e, {schema}.valor_forma_edificio vfe
	where e.valor_forma_edificio = vfe.identificador and lower(vfe.descricao) = 'barragem' and st_within(b.geometria, e.geometria ) ))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*)
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra')
	and ST_Intersects(geometria, '%1$s')),
good as (select count(*)
		from {schema}.barreira b, {schema}.valor_barreira vb
		where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra')
		and ST_Intersects(geometria, '%1$s')
		and exists (select e.* 
	from {schema}.edificio e, {schema}.valor_forma_edificio vfe
	where e.valor_forma_edificio = vfe.identificador and lower(vfe.descricao) = 'barragem' and st_within(b.geometria, e.geometria ) )),
bad as (select count(*)
		from {schema}.barreira b, {schema}.valor_barreira vb
		where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra')
		and ST_Intersects(geometria, '%1$s')
		and not exists (select e.* 
	from {schema}.edificio e, {schema}.valor_forma_edificio vfe
	where e.valor_forma_edificio = vfe.identificador and lower(vfe.descricao) = 'barragem' and st_within(b.geometria, e.geometria ) ))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select b.*
	from {schema}.barreira b, {schema}.valor_barreira vb
	where b.valor_barreira = vb.identificador and (vb.descricao ilike '%%betão' or vb.descricao ilike '%%terra')
	and ST_Intersects(geometria, '%1$s')
	and not exists (select e.* 
from {schema}.edificio e, {schema}.valor_forma_edificio vfe
where e.valor_forma_edificio = vfe.identificador and lower(vfe.descricao) = 'barragem' and st_within(b.geometria, e.geometria ) )$$ );


-- TODO
delete from validation.rules where code = 're4_4';
insert into validation.rules ( code, name, rule, scope, entity ) 
values ('re4_4', 'Representação da área e do eixo do curso de água', 
$$A representação do curso de água resulta da aplicação dos critérios:
NdD1: o "Curso de água - área" é representado através de um polígono,
que traduz o limite das suas margens, se a distância entre as margens for
igual ou superior a 1 m; se a distância entre as margens for inferior a 1 m
o curso de água é representado através de uma linha que traduz o seu
eixo ("Curso de água - eixo");
NdD2: o "Curso de água - área" é representado através de um polígono,
que traduz o limite das suas margens, se a distância entre as margens for
igual ou superior a 5 m; se a distância entre as margens for inferior a 5 m
então o curso de água é representado através de uma linha que traduz o
seu eixo ("Curso de água – eixo").$$,
$$"Curso de água - eixo" e "Curso de água - área".$$, 'curso_de_agua_area' );

-- TODO
delete from validation.rules_area where code = 're4_4';
insert into validation.rules_area ( code, name, rule, scope, entity ) 
values ('re4_4', 'Representação da área e do eixo do curso de água', 
$$A representação do curso de água resulta da aplicação dos critérios:
NdD1: o "Curso de água - área" é representado através de um polígono,
que traduz o limite das suas margens, se a distância entre as margens for
igual ou superior a 1 m; se a distância entre as margens for inferior a 1 m
o curso de água é representado através de uma linha que traduz o seu
eixo ("Curso de água - eixo");
NdD2: o "Curso de água - área" é representado através de um polígono,
que traduz o limite das suas margens, se a distância entre as margens for
igual ou superior a 5 m; se a distância entre as margens for inferior a 5 m
então o curso de água é representado através de uma linha que traduz o
seu eixo ("Curso de água – eixo").$$,
$$"Curso de água - eixo" e "Curso de água - área".$$, 'curso_de_agua_area' );


-- TODO
-- Verificação muito limitada
-- O âmbito de aplicação são duas tabelas e não uma
-- O exemplo de estarreja2020 tem uma curso_de_agua_area com três fluxos diferentes. É excelente para desenvolver um teste.
-- Para já, neste teste limitado não se testa se os eixos são fictícios
-- Testar fictícios dentro e ausência de fisctícios fora.
delete from validation.rules where code = 're4_5_1';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re4_5_1', 'Representação do eixo do curso de água (Parte 1)', 
$$Um "Curso de água - eixo" é sempre representado pelo seu eixo mesmo
quando (também) é representado através de um polígono "Curso de água -
área".$$,
$$"Curso de água - eixo".$$, 'curso_de_agua_area',
$$with 
total as (select count(*) from {schema}.curso_de_agua_area),
good as (select count(*) from {schema}.curso_de_agua_area cdaa 
	where exists (select * from {schema}.curso_de_agua_eixo cdae where st_within( cdae.geometria, cdaa.geometria))),
bad as (select count(*) from {schema}.curso_de_agua_area cdaa 
	where not exists (select * from {schema}.curso_de_agua_eixo cdae where st_within( cdae.geometria, cdaa.geometria)))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.curso_de_agua_area),
good as (select count(*) from {schema}.curso_de_agua_area cdaa 
	where exists (select * from {schema}.curso_de_agua_eixo cdae where st_within( cdae.geometria, cdaa.geometria))),
bad as (select count(*) from {schema}.curso_de_agua_area cdaa 
	where not exists (select * from {schema}.curso_de_agua_eixo cdae where st_within( cdae.geometria, cdaa.geometria)))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select * from {schema}.curso_de_agua_area cdaa 
where not exists (select * from {schema}.curso_de_agua_eixo cdae where st_within( cdae.geometria, cdaa.geometria))$$ );

delete from validation.rules_area where code = 're4_5_1';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re4_5_1', 'Representação do eixo do curso de água (Parte 1)', 
$$Um "Curso de água - eixo" é sempre representado pelo seu eixo mesmo
quando (também) é representado através de um polígono "Curso de água -
área".$$,
$$"Curso de água - eixo".$$, 'curso_de_agua_area',
$$with 
total as (select count(*) from {schema}.curso_de_agua_area where st_intersects(geometria, '%1$s')),
good as (select count(*) from {schema}.curso_de_agua_area cdaa 
	where st_intersects(geometria, '%1$s') and exists (select * from {schema}.curso_de_agua_eixo cdae where st_within( cdae.geometria, cdaa.geometria))),
bad as (select count(*) from {schema}.curso_de_agua_area cdaa 
	where st_intersects(geometria, '%1$s') and not exists (select * from {schema}.curso_de_agua_eixo cdae where st_within( cdae.geometria, cdaa.geometria)))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.curso_de_agua_area where st_intersects(geometria, '%1$s')),
good as (select count(*) from {schema}.curso_de_agua_area cdaa 
	where st_intersects(geometria, '%1$s') and exists (select * from {schema}.curso_de_agua_eixo cdae where st_within( cdae.geometria, cdaa.geometria))),
bad as (select count(*) from {schema}.curso_de_agua_area cdaa 
	where st_intersects(geometria, '%1$s') and not exists (select * from {schema}.curso_de_agua_eixo cdae where st_within( cdae.geometria, cdaa.geometria)))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select * from {schema}.curso_de_agua_area cdaa 
where st_intersects(geometria, '%1$s') and not exists (select * from {schema}.curso_de_agua_eixo cdae where st_within( cdae.geometria, cdaa.geometria))$$ );

-- TODO
-- Garantir a monotonia de uma LineString
-- As LineString estão orientadas?
-- Percorrer todos os vértices da geometria, ou seja, todos os pontos da LineString
delete from validation.rules where code = 're4_5_2';
insert into validation.rules ( code, name, rule, scope, entity ) 
values ('re4_5_2', 'Representação do eixo do curso de água (Parte 2 - Vértices)', 
$$Todos os vértices do "Curso de água - eixo" devem ser coerentes entre si
também na componente tridimensional.$$,
$$"Curso de água - eixo".$$, 'curso_de_agua_area' );

delete from validation.rules_area where code = 're4_5_2';
insert into validation.rules_area ( code, name, rule, scope, entity ) 
values ('re4_5_2', 'Representação do eixo do curso de água (Parte 2 - Vértices)', 
$$Todos os vértices do "Curso de água - eixo" devem ser coerentes entre si
também na componente tridimensional.$$,
$$"Curso de água - eixo".$$, 'curso_de_agua_area' );

-- TODO
-- O que podemos testar? Se há eixos a chegar ou a sair de uma água lêntica?
-- Testar se há águas lênticas isoladas...
-- Assumir que tem que ter
delete from validation.rules where code = 're4_6';
insert into validation.rules ( code, name, rule, scope, entity ) 
values ('re4_6', 'Representação do curso de água quando atravessa uma massa de água', 
$$Quando um curso de água atravessa uma massa de água totalmente rodeada
por terra ou localizada junto à costa ("Água lêntica") então também é
representado o curso de água pelo seu eixo através do objeto "Curso de água -
eixo" (Figura 29).$$,
$$"Curso de água - eixo" e "Água lêntica".$$, 'curso_de_agua_eixo' );

delete from validation.rules_area where code = 're4_6';
insert into validation.rules_area ( code, name, rule, scope, entity ) 
values ('re4_6', 'Representação do curso de água quando atravessa uma massa de água', 
$$Quando um curso de água atravessa uma massa de água totalmente rodeada
por terra ou localizada junto à costa ("Água lêntica") então também é
representado o curso de água pelo seu eixo através do objeto "Curso de água -
eixo" (Figura 29).$$,
$$"Curso de água - eixo" e "Água lêntica".$$, 'curso_de_agua_eixo' );

-- TODO
-- Tem alaguma coisa a ver com a verificação em re4_5_1
-- Eventualmente usar o pgRouting para estabelecer a rede entre os pontos de entrada e de saída
-- E depois, confirmar que todos os troços estão dentro
delete from validation.rules where code = 're4_7';
insert into validation.rules ( code, name, rule, scope, entity ) 
values ('re4_7', 'Traçado do eixo do curso de água quando atravessa uma massa de água', 
$$O eixo de curso de água ("Curso de água - eixo") está totalmente incluído nos
polígonos que representam o "Curso de água - área" ou a "Água lêntica"
(Figura 30).$$,
$$"Curso de água - eixo".$$, 'curso_de_agua_eixo' );

delete from validation.rules_area where code = 're4_7';
insert into validation.rules_area ( code, name, rule, scope, entity ) 
values ('re4_7', 'Traçado do eixo do curso de água quando atravessa uma massa de água', 
$$O eixo de curso de água ("Curso de água - eixo") está totalmente incluído nos
polígonos que representam o "Curso de água - área" ou a "Água lêntica"
(Figura 30).$$,
$$"Curso de água - eixo".$$, 'curso_de_agua_eixo' );

/* delete from validation.rules where code = 're4_8';
insert into validation.rules (code, name, rule, scope, entity, query, query_nd2, report) 
values ('re4_8', 'Interrupção do curso de água', 
$$O "Curso de água- eixo" e o "Curso de água - área" são interrompidos
quando:
 - Existe uma interceção com outro curso de água;
 - Existe uma alteração do valor de qualquer um dos atributos que
caracteriza o "Curso de água - eixo";
- Existe uma variação ("Queda de água" ou "Zona húmida") ou
regulação de fluxo ("Barreira").$$,
$$"Curso de água - eixo", "Curso de água - área", "Queda de água", "Zona
húmida" e "Barreira".$$, 'curso_de_agua_eixo',
$$with
total as (select count(a.*)
	from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
	where ST_intersects(a.geometria, b.geometria) and a.identificador != b.identificador
),
good as (select count(a.*)
	from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
	where (ST_intersects(a.geometria, b.geometria) and a.identificador != b.identificador) and
		((select ST_intersects(ST_intersection(a.geometria, b.geometria), f.geometria) from 
			(select geom_col as geometria from validation.no_hidro) as f) or
		not (coalesce(a.nome, '') = coalesce(b.nome, '') and
			coalesce(a.delimitacao_conhecida, false) = coalesce(b.delimitacao_conhecida, false) and
			coalesce(a.ficticio, false) = coalesce(b.ficticio, false) and
			coalesce(a.largura, 0) = coalesce(b.largura, 0) and
			coalesce(a.id_hidrografico, '') = coalesce(b.id_hidrografico, '') and
			coalesce(a.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = coalesce(b.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') and
			coalesce(a.ordem_hidrologica, '') = coalesce(b.ordem_hidrologica, '') and
			coalesce(a.origem_natural, false) = coalesce(b.origem_natural, false) and
			coalesce(a.valor_curso_de_agua, '') = coalesce(b.valor_curso_de_agua, '') and
			coalesce(a.valor_persistencia_hidrologica, '') = coalesce(b.valor_persistencia_hidrologica, '') and
			coalesce(a.valor_posicao_vertical, '') = coalesce(b.valor_posicao_vertical, ''))
		or (select ST_intersects(a.geometria, i.geometria) from 
				(select geom_col as geometria from validation.interrupcao_fluxo) as i)
		)
),
bad as (select count(a.*)
	from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
	where (ST_intersects(a.geometria, b.geometria) and a.identificador != b.identificador) and
		not (select ST_intersects(ST_intersection(a.geometria, b.geometria), f.geometria) from 
			(select geom_col as geometria from validation.no_hidro) as f) and
		(coalesce(a.nome, '') = coalesce(b.nome, '') and
			coalesce(a.delimitacao_conhecida, false) = coalesce(b.delimitacao_conhecida, false) and
			coalesce(a.ficticio, false) = coalesce(b.ficticio, false) and
			coalesce(a.largura, 0) = coalesce(b.largura, 0) and
			coalesce(a.id_hidrografico, '') = coalesce(b.id_hidrografico, '') and
			coalesce(a.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = coalesce(b.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') and
			coalesce(a.ordem_hidrologica, '') = coalesce(b.ordem_hidrologica, '') and
			coalesce(a.origem_natural, false) = coalesce(b.origem_natural, false) and
			coalesce(a.valor_curso_de_agua, '') = coalesce(b.valor_curso_de_agua, '') and
			coalesce(a.valor_persistencia_hidrologica, '') = coalesce(b.valor_persistencia_hidrologica, '') and
			coalesce(a.valor_posicao_vertical, '') = coalesce(b.valor_posicao_vertical, ''))
		and not (select ST_intersects(a.geometria, i.geometria) from 
				(select geom_col as geometria from validation.interrupcao_fluxo) as i)
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$with
total as (select count(a.*)
	from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
	where ST_intersects(a.geometria, b.geometria) and a.identificador != b.identificador
),
good as (select count(a.*)
	from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
	where (ST_intersects(a.geometria, b.geometria) and a.identificador != b.identificador) and
		((select ST_intersects(ST_intersection(a.geometria, b.geometria), f.geometria) from 
			(select geom_col as geometria from validation.no_hidro) as f) or
		not (coalesce(a.nome, '') = coalesce(b.nome, '') and
			coalesce(a.delimitacao_conhecida, false) = coalesce(b.delimitacao_conhecida, false) and
			coalesce(a.ficticio, false) = coalesce(b.ficticio, false) and
			coalesce(a.largura, 0) = coalesce(b.largura, 0) and
			coalesce(a.id_hidrografico, '') = coalesce(b.id_hidrografico, '') and
			coalesce(a.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = coalesce(b.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') and
			coalesce(a.ordem_hidrologica, '') = coalesce(b.ordem_hidrologica, '') and
			coalesce(a.origem_natural, false) = coalesce(b.origem_natural, false) and
			coalesce(a.valor_curso_de_agua, '') = coalesce(b.valor_curso_de_agua, '') and
			coalesce(a.valor_persistencia_hidrologica, '') = coalesce(b.valor_persistencia_hidrologica, '') and
			coalesce(a.valor_posicao_vertical, '') = coalesce(b.valor_posicao_vertical, ''))
		or (select ST_intersects(a.geometria, i.geometria) from 
				(select geom_col as geometria from validation.interrupcao_fluxo) as i)
		)
),
bad as (select count(a.*)
	from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
	where (ST_intersects(a.geometria, b.geometria) and a.identificador != b.identificador) and
		not (select ST_intersects(ST_intersection(a.geometria, b.geometria), f.geometria) from 
			(select geom_col as geometria from validation.no_hidro) as f) and
		(coalesce(a.nome, '') = coalesce(b.nome, '') and
			coalesce(a.delimitacao_conhecida, false) = coalesce(b.delimitacao_conhecida, false) and
			coalesce(a.ficticio, false) = coalesce(b.ficticio, false) and
			coalesce(a.largura, 0) = coalesce(b.largura, 0) and
			coalesce(a.id_hidrografico, '') = coalesce(b.id_hidrografico, '') and
			coalesce(a.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = coalesce(b.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') and
			coalesce(a.ordem_hidrologica, '') = coalesce(b.ordem_hidrologica, '') and
			coalesce(a.origem_natural, false) = coalesce(b.origem_natural, false) and
			coalesce(a.valor_curso_de_agua, '') = coalesce(b.valor_curso_de_agua, '') and
			coalesce(a.valor_persistencia_hidrologica, '') = coalesce(b.valor_persistencia_hidrologica, '') and
			coalesce(a.valor_posicao_vertical, '') = coalesce(b.valor_posicao_vertical, ''))
		and not (select ST_intersects(a.geometria, i.geometria) from 
				(select geom_col as geometria from validation.interrupcao_fluxo) as i)
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$select a.*
	from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
	where (ST_intersects(a.geometria, b.geometria) and a.identificador != b.identificador) and
		not (select ST_intersects(ST_intersection(a.geometria, b.geometria), f.geometria) from 
			(select geom_col as geometria from validation.no_hidro) as f) and
		(coalesce(a.nome, '') = coalesce(b.nome, '') and
			coalesce(a.delimitacao_conhecida, false) = coalesce(b.delimitacao_conhecida, false) and
			coalesce(a.ficticio, false) = coalesce(b.ficticio, false) and
			coalesce(a.largura, 0) = coalesce(b.largura, 0) and
			coalesce(a.id_hidrografico, '') = coalesce(b.id_hidrografico, '') and
			coalesce(a.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = coalesce(b.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') and
			coalesce(a.ordem_hidrologica, '') = coalesce(b.ordem_hidrologica, '') and
			coalesce(a.origem_natural, false) = coalesce(b.origem_natural, false) and
			coalesce(a.valor_curso_de_agua, '') = coalesce(b.valor_curso_de_agua, '') and
			coalesce(a.valor_persistencia_hidrologica, '') = coalesce(b.valor_persistencia_hidrologica, '') and
			coalesce(a.valor_posicao_vertical, '') = coalesce(b.valor_posicao_vertical, ''))
		and not (select ST_intersects(a.geometria, i.geometria) from 
				(select geom_col as geometria from validation.interrupcao_fluxo) as i)$$);
 */

delete from validation.rules where code = 're4_8_1';
insert into validation.rules (code, name, rule, scope, entity, query, query_nd2, report ) 
values ('re4_8_1', 'Interrupção do curso de água', 
$$O "Curso de água- eixo" e o "Curso de água - área" são interrompidos
quando:
 - Existe uma interceção com outro curso de água;
 - Existe uma alteração do valor de qualquer um dos atributos que
caracteriza o "Curso de água - eixo";
- Existe uma variação ("Queda de água" ou "Zona húmida") ou
regulação de fluxo ("Barreira").$$,
$$"Curso de água - eixo", "Curso de água - área", "Queda de água", "Zona
húmida" e "Barreira".$$, 'curso_de_agua_eixo',
$$with
total as (select count(distinct a.identificador)
	from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
	where ST_intersects(a.geometria, b.geometria)),
good as (select count(distinct a.identificador)
	from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
	where a.identificador != b.identificador and 
		ST_intersects(a.geometria, b.geometria) and ST_Touches(a.geometria, b.geometria)
),
bad as (select count(distinct a.identificador)
	from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
	where a.identificador != b.identificador and 
		ST_intersects(a.geometria, b.geometria) and not ST_Touches(a.geometria, b.geometria)
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
NULL,
$$select distinct a.*
	from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
	where a.identificador != b.identificador and 
		ST_intersects(a.geometria, b.geometria) and not ST_Touches(a.geometria, b.geometria)$$ );

delete from validation.rules_area where code = 're4_8_1';
insert into validation.rules_area (code, name, rule, scope, entity, query, query_nd2, report ) 
values ('re4_8_1', 'Interrupção do curso de água', 
$$O "Curso de água- eixo" e o "Curso de água - área" são interrompidos
quando:
 - Existe uma interceção com outro curso de água;
 - Existe uma alteração do valor de qualquer um dos atributos que
caracteriza o "Curso de água - eixo";
- Existe uma variação ("Queda de água" ou "Zona húmida") ou
regulação de fluxo ("Barreira").$$,
$$"Curso de água - eixo", "Curso de água - área", "Queda de água", "Zona
húmida" e "Barreira".$$, 'curso_de_agua_eixo',
$$with
total as (select count(distinct a.identificador)
	from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
	where ST_Intersects(a.geometria, '%1$s') and ST_intersects(a.geometria, b.geometria)),
good as (select count(distinct a.identificador)
	from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
	where a.identificador != b.identificador and 
		ST_Intersects(a.geometria, '%1$s') and
		ST_intersects(a.geometria, b.geometria) and ST_Touches(a.geometria, b.geometria)
),
bad as (select count(distinct a.identificador)
	from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
	where a.identificador != b.identificador and 
		ST_Intersects(a.geometria, '%1$s') and
		ST_intersects(a.geometria, b.geometria) and not ST_Touches(a.geometria, b.geometria)
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
NULL,
$$select distinct a.*
	from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
	where a.identificador != b.identificador and 
		ST_Intersects(a.geometria, '%1$s') and
		ST_intersects(a.geometria, b.geometria) and not ST_Touches(a.geometria, b.geometria)$$ );


delete from validation.rules where code = 're4_8_2';
insert into validation.rules (code, name, rule, scope, entity, query, query_nd2, report ) 
values ('re4_8_2', 'Interrupção do curso de água', 
$$O "Curso de água- eixo" e o "Curso de água - área" são interrompidos
quando:
 - Existe uma interceção com outro curso de água;
 - Existe uma alteração do valor de qualquer um dos atributos que
caracteriza o "Curso de água - eixo";
- Existe uma variação ("Queda de água" ou "Zona húmida") ou
regulação de fluxo ("Barreira").$$,
$$"Curso de água - eixo", "Curso de água - área", "Queda de água", "Zona
húmida" e "Barreira".$$, 'curso_de_agua_eixo',
$$with
changes as (
	select a.identificador from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
		where a.identificador<>b.identificador and st_intersects(a.geometria, b.geometria)
		and not (coalesce(a.nome, '') = coalesce(b.nome, '') and
				coalesce(a.delimitacao_conhecida, false) = coalesce(b.delimitacao_conhecida, false) and
				coalesce(a.ficticio, false) = coalesce(b.ficticio, false) and
				coalesce(a.largura, 0) = coalesce(b.largura, 0) and
				coalesce(a.id_hidrografico, '') = coalesce(b.id_hidrografico, '') and
				coalesce(a.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = coalesce(b.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') and
				coalesce(a.ordem_hidrologica, '') = coalesce(b.ordem_hidrologica, '') and
				coalesce(a.origem_natural, false) = coalesce(b.origem_natural, false) and
				coalesce(a.valor_curso_de_agua, '') = coalesce(b.valor_curso_de_agua, '') and
				coalesce(a.valor_persistencia_hidrologica, '') = coalesce(b.valor_persistencia_hidrologica, '') and
				coalesce(a.valor_posicao_vertical, '') = coalesce(b.valor_posicao_vertical, ''))),
total as (with multipontos as (
	select a.identificador, st_intersection(a.geometria, ST_Boundary(b.geometria)) as geometria
		from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_area b
		where ST_intersects(a.geometria, ST_Boundary(b.geometria))),
	pontos as (select (ST_Dump(multipontos.geometria)).geom as geometria
	from multipontos)
	select count(distinct pontos.*)
	from pontos),
good as (with multipontos as (
	select a.identificador, st_intersection(a.geometria, ST_Boundary(b.geometria)) as geometria
		from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_area b
		where ST_intersects(a.geometria, ST_Boundary(b.geometria))),
	pontos as (select (ST_Dump(multipontos.geometria)).geom as geometria
	from multipontos)
	select count(distinct pontos.*)
	from pontos, {schema}.curso_de_agua_eixo e
	where pontos.geometria = ST_StartPoint(e.geometria) 
		or pontos.geometria = ST_EndPoint(e.geometria) or e.identificador in (select identificador from changes)),
bad as (with multipontos as (
	select a.identificador, st_intersection(a.geometria, ST_Boundary(b.geometria)) as geometria
		from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_area b
		where ST_intersects(a.geometria, ST_Boundary(b.geometria))),
	pontos as (select multipontos.identificador, (ST_Dump(multipontos.geometria)).geom as geometria
	from multipontos)
	select count(distinct pontos.*) from pontos
	where pontos.identificador not in (select identificador from changes) and not exists (select * 
		from {schema}.curso_de_agua_eixo e
		where pontos.geometria = ST_StartPoint(e.geometria) 
		or pontos.geometria = ST_EndPoint(e.geometria)))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
NULL,
$$with changes as (
	select a.identificador from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
		where a.identificador<>b.identificador and st_intersects(a.geometria, b.geometria)
		and not (coalesce(a.nome, '') = coalesce(b.nome, '') and
				coalesce(a.delimitacao_conhecida, false) = coalesce(b.delimitacao_conhecida, false) and
				coalesce(a.ficticio, false) = coalesce(b.ficticio, false) and
				coalesce(a.largura, 0) = coalesce(b.largura, 0) and
				coalesce(a.id_hidrografico, '') = coalesce(b.id_hidrografico, '') and
				coalesce(a.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = coalesce(b.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') and
				coalesce(a.ordem_hidrologica, '') = coalesce(b.ordem_hidrologica, '') and
				coalesce(a.origem_natural, false) = coalesce(b.origem_natural, false) and
				coalesce(a.valor_curso_de_agua, '') = coalesce(b.valor_curso_de_agua, '') and
				coalesce(a.valor_persistencia_hidrologica, '') = coalesce(b.valor_persistencia_hidrologica, '') and
				coalesce(a.valor_posicao_vertical, '') = coalesce(b.valor_posicao_vertical, ''))),
multipontos as (
select a.identificador, st_intersection(a.geometria, ST_Boundary(b.geometria)) as geometria
	from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_area b
	where ST_intersects(a.geometria, ST_Boundary(b.geometria))),
pontos as (select multipontos.identificador, (ST_Dump(multipontos.geometria)).geom as geometria
from multipontos)
select distinct c.*
from pontos, {schema}.curso_de_agua_eixo c
where pontos.identificador = c.identificador and c.identificador not in (select identificador from changes) and not exists (select * 
	from {schema}.curso_de_agua_eixo e
	where pontos.geometria = ST_StartPoint(e.geometria) 
	or pontos.geometria = ST_EndPoint(e.geometria))$$ );

delete from validation.rules_area where code = 're4_8_2';
insert into validation.rules_area (code, name, rule, scope, entity, query, query_nd2, report ) 
values ('re4_8_2', 'Interrupção do curso de água', 
$$O "Curso de água- eixo" e o "Curso de água - área" são interrompidos
quando:
 - Existe uma interceção com outro curso de água;
 - Existe uma alteração do valor de qualquer um dos atributos que
caracteriza o "Curso de água - eixo";
- Existe uma variação ("Queda de água" ou "Zona húmida") ou
regulação de fluxo ("Barreira").$$,
$$"Curso de água - eixo", "Curso de água - área", "Queda de água", "Zona
húmida" e "Barreira".$$, 'curso_de_agua_eixo',
$$with
changes as (
	select a.identificador from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
		where a.identificador<>b.identificador and st_intersects(a.geometria, b.geometria)
		and not (coalesce(a.nome, '') = coalesce(b.nome, '') and
				coalesce(a.delimitacao_conhecida, false) = coalesce(b.delimitacao_conhecida, false) and
				coalesce(a.ficticio, false) = coalesce(b.ficticio, false) and
				coalesce(a.largura, 0) = coalesce(b.largura, 0) and
				coalesce(a.id_hidrografico, '') = coalesce(b.id_hidrografico, '') and
				coalesce(a.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = coalesce(b.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') and
				coalesce(a.ordem_hidrologica, '') = coalesce(b.ordem_hidrologica, '') and
				coalesce(a.origem_natural, false) = coalesce(b.origem_natural, false) and
				coalesce(a.valor_curso_de_agua, '') = coalesce(b.valor_curso_de_agua, '') and
				coalesce(a.valor_persistencia_hidrologica, '') = coalesce(b.valor_persistencia_hidrologica, '') and
				coalesce(a.valor_posicao_vertical, '') = coalesce(b.valor_posicao_vertical, ''))),
total as (with multipontos as (
	select a.identificador, st_intersection(a.geometria, ST_Boundary(b.geometria)) as geometria
		from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_area b
		where ST_Intersects(a.geometria, '%1$s') and ST_intersects(a.geometria, ST_Boundary(b.geometria))),
	pontos as (select (ST_Dump(multipontos.geometria)).geom as geometria
	from multipontos)
	select count(distinct pontos.*)
	from pontos),
good as (with multipontos as (
	select a.identificador, st_intersection(a.geometria, ST_Boundary(b.geometria)) as geometria
		from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_area b
		where ST_Intersects(a.geometria, '%1$s') and ST_intersects(a.geometria, ST_Boundary(b.geometria))),
	pontos as (select (ST_Dump(multipontos.geometria)).geom as geometria
	from multipontos)
	select count(distinct pontos.*)
	from pontos, {schema}.curso_de_agua_eixo e
	where pontos.geometria = ST_StartPoint(e.geometria) 
		or pontos.geometria = ST_EndPoint(e.geometria) or e.identificador in (select identificador from changes)),
bad as (with multipontos as (
	select a.identificador, st_intersection(a.geometria, ST_Boundary(b.geometria)) as geometria
		from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_area b
		where ST_Intersects(a.geometria, '%1$s') and ST_intersects(a.geometria, ST_Boundary(b.geometria))),
	pontos as (select multipontos.identificador, (ST_Dump(multipontos.geometria)).geom as geometria
	from multipontos)
	select count(distinct pontos.*)
	from pontos
	where pontos.identificador not in (select identificador from changes) and not exists (select * 
		from {schema}.curso_de_agua_eixo e
		where ST_Intersects(e.geometria, '%1$s') and (pontos.geometria = ST_StartPoint(e.geometria) 
		or pontos.geometria = ST_EndPoint(e.geometria))))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
NULL,
$$with changes as (
	select a.identificador from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_eixo b
		where a.identificador<>b.identificador and st_intersects(a.geometria, b.geometria)
		and not (coalesce(a.nome, '') = coalesce(b.nome, '') and
				coalesce(a.delimitacao_conhecida, false) = coalesce(b.delimitacao_conhecida, false) and
				coalesce(a.ficticio, false) = coalesce(b.ficticio, false) and
				coalesce(a.largura, 0) = coalesce(b.largura, 0) and
				coalesce(a.id_hidrografico, '') = coalesce(b.id_hidrografico, '') and
				coalesce(a.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = coalesce(b.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') and
				coalesce(a.ordem_hidrologica, '') = coalesce(b.ordem_hidrologica, '') and
				coalesce(a.origem_natural, false) = coalesce(b.origem_natural, false) and
				coalesce(a.valor_curso_de_agua, '') = coalesce(b.valor_curso_de_agua, '') and
				coalesce(a.valor_persistencia_hidrologica, '') = coalesce(b.valor_persistencia_hidrologica, '') and
				coalesce(a.valor_posicao_vertical, '') = coalesce(b.valor_posicao_vertical, ''))),
multipontos as (
select a.identificador, st_intersection(a.geometria, ST_Boundary(b.geometria)) as geometria
	from {schema}.curso_de_agua_eixo a, {schema}.curso_de_agua_area b
	where ST_Intersects(a.geometria, '%1$s') and ST_intersects(a.geometria, ST_Boundary(b.geometria))),
pontos as (select multipontos.identificador, (ST_Dump(multipontos.geometria)).geom as geometria
from multipontos)
select distinct c.*
from pontos, {schema}.curso_de_agua_eixo c
where pontos.identificador = c.identificador and c.identificador not in (select identificador from changes) and not exists (select * 
	from {schema}.curso_de_agua_eixo e
	where ST_Intersects(e.geometria, '%1$s') and (pontos.geometria = ST_StartPoint(e.geometria) 
	or pontos.geometria = ST_EndPoint(e.geometria)))$$ );


-- Regras semelhantes: re4_9_1, re5_2_3, re5_5_3
delete from validation.rules where code = 're4_9_1';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re4_9_1', 'Conexão entre o eixo de curso de água e os nós hidrográficos (Parte 1 - Eixos)', 
$$Cada "Curso de água - eixo" conecta obrigatoriamente com dois objetos "Nó hidrográfico".$$, 
$$"Curso de água - eixo" e "Nó hidrográfico".$$, 'curso_de_agua_eixo',
$$with 
total as (select count(*) from {schema}.curso_de_agua_eixo),
good as (select count(cdae.*)
	from {schema}.curso_de_agua_eixo cdae, validation.area_trabalho_multi adt
	where (ST_StartPoint(cdae.geometria) in (select geometria from {schema}.no_hidrografico) and ST_EndPoint(cdae.geometria) in (select geometria from {schema}.no_hidrografico))
		or st_intersects(cdae.geometria, ST_Boundary(adt.geometria))
),
bad as (select count(cdae.*)
	from {schema}.curso_de_agua_eixo cdae, validation.area_trabalho_multi adt
	where (ST_StartPoint(cdae.geometria) not in (select geometria from {schema}.no_hidrografico) or ST_EndPoint(cdae.geometria) not in (select geometria from {schema}.no_hidrografico))
		and st_intersects(cdae.geometria, ST_Boundary(adt.geometria)) is not true
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$with 
total as (select count(*) from {schema}.curso_de_agua_eixo),
good as (select count(cdae.*)
	from {schema}.curso_de_agua_eixo cdae, validation.area_trabalho_multi adt
	where (ST_StartPoint(cdae.geometria) in (select geometria from {schema}.no_hidrografico) and ST_EndPoint(cdae.geometria) in (select geometria from {schema}.no_hidrografico))
		or st_intersects(cdae.geometria, ST_Boundary(adt.geometria))
),
bad as (select count(cdae.*)
	from {schema}.curso_de_agua_eixo cdae, validation.area_trabalho_multi adt
	where (ST_StartPoint(cdae.geometria) not in (select geometria from {schema}.no_hidrografico) or ST_EndPoint(cdae.geometria) not in (select geometria from {schema}.no_hidrografico))
		and st_intersects(cdae.geometria, ST_Boundary(adt.geometria)) is not true
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$select cdae.*
	from {schema}.curso_de_agua_eixo cdae, validation.area_trabalho_multi adt
	where (ST_StartPoint(cdae.geometria) not in (select geometria from {schema}.no_hidrografico) or ST_EndPoint(cdae.geometria) not in (select geometria from {schema}.no_hidrografico))
		and st_intersects(cdae.geometria, ST_Boundary(adt.geometria)) is not true$$ );

delete from validation.rules_area where code = 're4_9_1';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re4_9_1', 'Conexão entre o eixo de curso de água e os nós hidrográficos (Parte 1 - Eixos)', 
$$Cada "Curso de água - eixo" conecta obrigatoriamente com dois objetos "Nó hidrográfico".$$, 
$$"Curso de água - eixo" e "Nó hidrográfico".$$, 'curso_de_agua_eixo',
$$with 
total as (select count(*) from {schema}.curso_de_agua_eixo where ST_Intersects(geometria, '%1$s')),
good as (select count(cdae.*)
	from {schema}.curso_de_agua_eixo cdae, validation.area_trabalho_multi adt
	where ST_Intersects(cdae.geometria, '%1$s') and ((ST_StartPoint(cdae.geometria) in (select geometria from {schema}.no_hidrografico) and ST_EndPoint(cdae.geometria) in (select geometria from {schema}.no_hidrografico))
		or st_intersects(cdae.geometria, ST_Boundary(adt.geometria)))
),
bad as (select count(cdae.*)
	from {schema}.curso_de_agua_eixo cdae, validation.area_trabalho_multi adt
	where ST_Intersects(cdae.geometria, '%1$s') and ((ST_StartPoint(cdae.geometria) not in (select geometria from {schema}.no_hidrografico) or ST_EndPoint(cdae.geometria) not in (select geometria from {schema}.no_hidrografico))
		and st_intersects(cdae.geometria, ST_Boundary(adt.geometria)) is not true)
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$with 
total as (select count(*) from {schema}.curso_de_agua_eixo where ST_Intersects(geometria, '%1$s')),
good as (select count(cdae.*)
	from {schema}.curso_de_agua_eixo cdae, validation.area_trabalho_multi adt
	where ST_Intersects(cdae.geometria, '%1$s') and ((ST_StartPoint(cdae.geometria) in (select geometria from {schema}.no_hidrografico) and ST_EndPoint(cdae.geometria) in (select geometria from {schema}.no_hidrografico))
		or st_intersects(cdae.geometria, ST_Boundary(adt.geometria)))
),
bad as (select count(cdae.*)
	from {schema}.curso_de_agua_eixo cdae, validation.area_trabalho_multi adt
	where ST_Intersects(cdae.geometria, '%1$s') and ((ST_StartPoint(cdae.geometria) not in (select geometria from {schema}.no_hidrografico) or ST_EndPoint(cdae.geometria) not in (select geometria from {schema}.no_hidrografico))
		and st_intersects(cdae.geometria, ST_Boundary(adt.geometria)) is not true)
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$select cdae.*
	from {schema}.curso_de_agua_eixo cdae, validation.area_trabalho_multi adt
	where ST_Intersects(cdae.geometria, '%1$s') and ((ST_StartPoint(cdae.geometria) not in (select geometria from {schema}.no_hidrografico) or ST_EndPoint(cdae.geometria) not in (select geometria from {schema}.no_hidrografico))
		and st_intersects(cdae.geometria, ST_Boundary(adt.geometria)) is not true)$$ );


delete from validation.rules where code = 're4_9_2';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re4_9_2', 'Conexão entre o eixo de curso de água e os nós hidrográficos (Parte 2 - Nós)', 
$$Um "Nó hidrográfico" conecta obrigatoriamente com pelo menos um "Curso de água - eixo".$$, 
$$"Curso de água - eixo" e "Nó hidrográfico".$$, 'no_hidrografico',
$$with 
total as (select count(*) from {schema}.no_hidrografico),
good as (select count(*) 
	from {schema}.no_hidrografico
	where geometria in (
	select ST_StartPoint(geometria) from {schema}.curso_de_agua_eixo cdae
	union
	select ST_EndPoint(geometria) from {schema}.curso_de_agua_eixo cdae)),
bad as (select count(*) 
	from {schema}.no_hidrografico
	where geometria not in (
	select ST_StartPoint(geometria) from {schema}.curso_de_agua_eixo cdae
	union
	select ST_EndPoint(geometria) from {schema}.curso_de_agua_eixo cdae))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.no_hidrografico),
good as (select count(*) 
	from {schema}.no_hidrografico
	where geometria in (
	select ST_StartPoint(geometria) from {schema}.curso_de_agua_eixo cdae
	union
	select ST_EndPoint(geometria) from {schema}.curso_de_agua_eixo cdae)),
bad as (select count(*) 
	from {schema}.no_hidrografico
	where geometria not in (
	select ST_StartPoint(geometria) from {schema}.curso_de_agua_eixo cdae
	union
	select ST_EndPoint(geometria) from {schema}.curso_de_agua_eixo cdae))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$ select *
from {schema}.no_hidrografico
where geometria not in (
select ST_StartPoint(geometria) from {schema}.curso_de_agua_eixo cdae
union
select ST_EndPoint(geometria) from {schema}.curso_de_agua_eixo cdae) $$ );

delete from validation.rules_area where code = 're4_9_2';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re4_9_2', 'Conexão entre o eixo de curso de água e os nós hidrográficos (Parte 2 - Nós)', 
$$Um "Nó hidrográfico" conecta obrigatoriamente com pelo menos um "Curso de água - eixo".$$, 
$$"Curso de água - eixo" e "Nó hidrográfico".$$, 'no_hidrografico',
$$with 
total as (select count(*) from {schema}.no_hidrografico where ST_Intersects(geometria, '%1$s')),
good as (select count(*) 
	from {schema}.no_hidrografico
	where ST_Intersects(geometria, '%1$s') and geometria in (
	select ST_StartPoint(geometria) from {schema}.curso_de_agua_eixo cdae
	union
	select ST_EndPoint(geometria) from {schema}.curso_de_agua_eixo cdae)),
bad as (select count(*) 
	from {schema}.no_hidrografico
	where ST_Intersects(geometria, '%1$s') and geometria not in (
	select ST_StartPoint(geometria) from {schema}.curso_de_agua_eixo cdae
	union
	select ST_EndPoint(geometria) from {schema}.curso_de_agua_eixo cdae))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.no_hidrografico where ST_Intersects(geometria, '%1$s')),
good as (select count(*) 
	from {schema}.no_hidrografico
	where ST_Intersects(geometria, '%1$s') and geometria in (
	select ST_StartPoint(geometria) from {schema}.curso_de_agua_eixo cdae
	union
	select ST_EndPoint(geometria) from {schema}.curso_de_agua_eixo cdae)),
bad as (select count(*) 
	from {schema}.no_hidrografico
	where ST_Intersects(geometria, '%1$s') and geometria not in (
	select ST_StartPoint(geometria) from {schema}.curso_de_agua_eixo cdae
	union
	select ST_EndPoint(geometria) from {schema}.curso_de_agua_eixo cdae))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$ select *
from {schema}.no_hidrografico
where ST_Intersects(geometria, '%1$s') and geometria not in (
select ST_StartPoint(geometria) from {schema}.curso_de_agua_eixo cdae
union
select ST_EndPoint(geometria) from {schema}.curso_de_agua_eixo cdae) $$ );


delete from validation.rules where code = 're4_10_1';
insert into validation.rules ( code, name, rule, scope, query, query_nd2 )
values ('re4_10_1', 'Nós de variação ou regulação de fluxo (Parte 1)', 
$$Quando existe uma "Queda de água" ou uma "Zona húmida" é colocado no 
correspondente "Curso de água - eixo" um "Nó hidrográfico" correspondente 
à "Variação de fluxo". 
Quando existe uma "Barreira" é colocado no correspondente "Curso de água 
- eixo" um "Nó hidrográfico" correspondente à "Regulação de fluxo".$$,
$$"Barreira", "Queda de água", "Zona húmida" e "Nó hidrográfico".$$,
$$ select * from validation.re4_10_validation () $$,
$$ select * from validation.re4_10_validation () $$ );

delete from validation.rules_area where code = 're4_10_1';
insert into validation.rules_area ( code, name, rule, scope, query, query_nd2 )
values ('re4_10_1', 'Nós de variação ou regulação de fluxo (Parte 1)', 
$$Quando existe uma "Queda de água" ou uma "Zona húmida" é colocado no 
correspondente "Curso de água - eixo" um "Nó hidrográfico" correspondente 
à "Variação de fluxo". 
Quando existe uma "Barreira" é colocado no correspondente "Curso de água 
- eixo" um "Nó hidrográfico" correspondente à "Regulação de fluxo".$$,
$$"Barreira", "Queda de água", "Zona húmida" e "Nó hidrográfico".$$,
$$ select * from validation.re4_10_validation('%s'::geometry)$$,
$$ select * from validation.re4_10_validation('%s'::geometry)$$ );


delete from validation.rules where code = 're4_10_2';
insert into validation.rules ( code, name, rule, scope, entity, query, query_nd2, report )
values ('re4_10_2', 'Nós de variação ou regulação de fluxo (Parte 2 - Nós)',
$$O nó é colocado no "Curso de água" no ponto correspondente ao local onde o 
fenómeno acontece e em conformidade com a topologia.$$,
$$"Curso de água - eixo", "Queda de água", "Zona húmida" e "Nó hidrográfico".$$, 'no_hidrografico',
$$with 
total as (select count(nh.*) from {schema}.no_hidrografico nh
		where nh.valor_tipo_no_hidrografico='5' or nh.valor_tipo_no_hidrografico='6'
),
good as (select count(nh.*) from {schema}.no_hidrografico nh 
	where (nh.valor_tipo_no_hidrografico='5'
			and nh.identificador in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.queda_de_agua qda, {schema}.zona_humida zh 
				where St_intersects(nha.geometria, qda.geometria) or St_intersects(nha.geometria, zh.geometria)))
		or (nh.valor_tipo_no_hidrografico='6'
			and nh.identificador in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.barreira b 
				where St_intersects(nha.geometria, b.geometria)))
),
bad as (select count(nh.*) from {schema}.no_hidrografico nh 
	where (nh.valor_tipo_no_hidrografico='5'
			and nh.identificador not in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.queda_de_agua qda, {schema}.zona_humida zh 
				where St_intersects(nha.geometria, qda.geometria) or St_intersects(nha.geometria, zh.geometria)))
		or (nh.valor_tipo_no_hidrografico='6'
			and nh.identificador not in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.barreira b 
				where St_intersects(nha.geometria, b.geometria)))
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$with 
total as (select count(nh.*) from {schema}.no_hidrografico nh
		where nh.valor_tipo_no_hidrografico='5' or nh.valor_tipo_no_hidrografico='6'
),
good as (select count(nh.*) from {schema}.no_hidrografico nh 
	where (nh.valor_tipo_no_hidrografico='5'
			and nh.identificador in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.queda_de_agua qda, {schema}.zona_humida zh 
				where St_intersects(nha.geometria, qda.geometria) or St_intersects(nha.geometria, zh.geometria)))
		or (nh.valor_tipo_no_hidrografico='6'
			and nh.identificador in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.barreira b 
				where St_intersects(nha.geometria, b.geometria)))
),
bad as (select count(nh.*) from {schema}.no_hidrografico nh 
	where (nh.valor_tipo_no_hidrografico='5'
			and nh.identificador not in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.queda_de_agua qda, {schema}.zona_humida zh 
				where St_intersects(nha.geometria, qda.geometria) or St_intersects(nha.geometria, zh.geometria)))
		or (nh.valor_tipo_no_hidrografico='6'
			and nh.identificador not in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.barreira b 
				where St_intersects(nha.geometria, b.geometria)))
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$select nh.* from {schema}.no_hidrografico nh 
	where (nh.valor_tipo_no_hidrografico='5'
			and nh.identificador not in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.queda_de_agua qda, {schema}.zona_humida zh 
				where St_intersects(nha.geometria, qda.geometria) or St_intersects(nha.geometria, zh.geometria)))
		or (nh.valor_tipo_no_hidrografico='6'
			and nh.identificador not in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.barreira b 
				where St_intersects(nha.geometria, b.geometria)))$$ );

delete from validation.rules_area where code = 're4_10_2';
insert into validation.rules_area ( code, name, rule, scope, entity, query, query_nd2, report )
values ('re4_10_2', 'Nós de variação ou regulação de fluxo (Parte 2 - Nós)',
$$O nó é colocado no "Curso de água" no ponto correspondente ao local onde o 
fenómeno acontece e em conformidade com a topologia.$$,
$$"Curso de água - eixo", "Queda de água", "Zona húmida" e "Nó hidrográfico".$$, 'no_hidrografico',
$$with 
total as (select count(nh.*) from {schema}.no_hidrografico nh
		where ST_Intersects(nh.geometria, '%1$s') and (nh.valor_tipo_no_hidrografico='5' or nh.valor_tipo_no_hidrografico='6')
),
good as (select count(nh.*) from {schema}.no_hidrografico nh 
	where ST_Intersects(nh.geometria, '%1$s') and ((nh.valor_tipo_no_hidrografico='5'
			and nh.identificador in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.queda_de_agua qda, {schema}.zona_humida zh 
				where St_intersects(nha.geometria, qda.geometria) or St_intersects(nha.geometria, zh.geometria)))
		or (nh.valor_tipo_no_hidrografico='6'
			and nh.identificador in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.barreira b 
				where St_intersects(nha.geometria, b.geometria))))
),
bad as (select count(nh.*) from {schema}.no_hidrografico nh 
	where ST_Intersects(nh.geometria, '%1$s') and ((nh.valor_tipo_no_hidrografico='5'
			and nh.identificador not in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.queda_de_agua qda, {schema}.zona_humida zh 
				where St_intersects(nha.geometria, qda.geometria) or St_intersects(nha.geometria, zh.geometria)))
		or (nh.valor_tipo_no_hidrografico='6'
			and nh.identificador not in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.barreira b 
				where St_intersects(nha.geometria, b.geometria))))
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$with 
total as (select count(nh.*) from {schema}.no_hidrografico nh
		where ST_Intersects(nh.geometria, '%1$s') and (nh.valor_tipo_no_hidrografico='5' or nh.valor_tipo_no_hidrografico='6')
),
good as (select count(nh.*) from {schema}.no_hidrografico nh 
	where ST_Intersects(nh.geometria, '%1$s') and ((nh.valor_tipo_no_hidrografico='5'
			and nh.identificador in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.queda_de_agua qda, {schema}.zona_humida zh 
				where St_intersects(nha.geometria, qda.geometria) or St_intersects(nha.geometria, zh.geometria)))
		or (nh.valor_tipo_no_hidrografico='6'
			and nh.identificador in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.barreira b 
				where St_intersects(nha.geometria, b.geometria))))
),
bad as (select count(nh.*) from {schema}.no_hidrografico nh 
	where ST_Intersects(nh.geometria, '%1$s') and ((nh.valor_tipo_no_hidrografico='5'
			and nh.identificador not in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.queda_de_agua qda, {schema}.zona_humida zh 
				where St_intersects(nha.geometria, qda.geometria) or St_intersects(nha.geometria, zh.geometria)))
		or (nh.valor_tipo_no_hidrografico='6'
			and nh.identificador not in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.barreira b 
				where St_intersects(nha.geometria, b.geometria))))
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$select nh.* from {schema}.no_hidrografico nh 
	where ST_Intersects(nh.geometria, '%1$s') and ((nh.valor_tipo_no_hidrografico='5'
			and nh.identificador not in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.queda_de_agua qda, {schema}.zona_humida zh 
				where St_intersects(nha.geometria, qda.geometria) or St_intersects(nha.geometria, zh.geometria)))
		or (nh.valor_tipo_no_hidrografico='6'
			and nh.identificador not in (select distinct nha.identificador from {schema}.no_hidrografico nha, {schema}.barreira b 
				where St_intersects(nha.geometria, b.geometria))))$$ );


delete from validation.rules where code = 're4_11_1';
delete from validation.rules where code = 're4_11_2';
delete from validation.rules where code = 're4_11';
insert into validation.rules ( code, name, rule, scope, entity, query, report ) 
values ('re4_11', 'Hierarquia dos nós hidrográficos', 
$$Quando um “Curso de água - eixo” interseta outro e, simultaneamente, 
observa-se uma alteração de atributos, o “Nó hidrográfico” assume o valor 
“Junção”. Apenas é inserido um nó que assume o valor “Junção” prevalecendo este sobre o valor “Pseudo-nó“.$$, 
$$"Curso de água - eixo, Nó hidrográfico".$$, 'no_hidrografico',
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.curso_de_agua_eixo l1
		join {schema}.curso_de_agua_eixo l2 on st_intersects(l1.geometria, l2.geometria) and l1.identificador <> l2.identificador
		group by st_intersection(l1.geometria, l2.geometria)
),
total as (
	select count(*) from inter where count > 2
),
good as (
	select count(*) from {schema}.no_hidrografico n1
	where geometria in (select geom from inter where count > 2)
		and geometria not in (select geometria from {schema}.no_hidrografico n2 where n1.identificador <> n2.identificador)
		and valor_tipo_no_hidrografico = '3'
),
bad as (
	select count(*) from {schema}.no_hidrografico n1
	where geometria in (select geom from inter where count > 2)
		and (geometria in (select geometria from {schema}.no_hidrografico n2 where n1.identificador <> n2.identificador)
			or valor_tipo_no_hidrografico <> '3')
) select total.count as total, good.count as good, bad.count as bad from total, good, bad$$,
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.curso_de_agua_eixo l1
		join {schema}.curso_de_agua_eixo l2 on st_intersects(l1.geometria, l2.geometria) and l1.identificador <> l2.identificador
		group by st_intersection(l1.geometria, l2.geometria)
) select * from {schema}.no_hidrografico n1
	where geometria in (select geom from inter where count > 2)
		and (geometria in (select geometria from {schema}.no_hidrografico n2 where n1.identificador <> n2.identificador)
			or valor_tipo_no_hidrografico <> '3')$$ );

delete from validation.rules_area where code = 're4_11_1';
delete from validation.rules_area where code = 're4_11_2';
delete from validation.rules_area where code = 're4_11';
insert into validation.rules_area ( code, name, rule, scope, entity, query, report ) 
values ('re4_11', 'Hierarquia dos nós hidrográficos (Parte 1 - Eixos)', 
$$Quando um “Curso de água - eixo” interseta outro e, simultaneamente, 
observa-se uma alteração de atributos, o “Nó hidrográfico” assume o valor 
“Junção”. Apenas é inserido um nó que assume o valor “Junção” prevalecendo este sobre o valor “Pseudo-nó$$, 
$$"Curso de água - eixo, Nó hidrográfico".$$, 'curso_de_agua_eixo',
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.curso_de_agua_eixo l1
		join {schema}.curso_de_agua_eixo l2 on st_intersects(l1.geometria, l2.geometria) and l1.identificador <> l2.identificador
		group by st_intersection(l1.geometria, l2.geometria)
),
total as (
	select count(*) from inter where count > 2
),
good as (
	select count(*) from {schema}.no_hidrografico n1
	where ST_Intersects(n1.geometria, '%1$s') and geometria in (select geom from inter where count > 2)
		and geometria not in (select geometria from {schema}.no_hidrografico n2 where n1.identificador <> n2.identificador)
		and valor_tipo_no_hidrografico = '3'
),
bad as (
	select count(*) from {schema}.no_hidrografico n1
	where ST_Intersects(n1.geometria, '%1$s') and geometria in (select geom from inter where count > 2)
		and (geometria in (select geometria from {schema}.no_hidrografico n2 where n1.identificador <> n2.identificador)
			or valor_tipo_no_hidrografico <> '3')
) select total.count as total, good.count as good, bad.count as bad from total, good, bad$$,
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.curso_de_agua_eixo l1
		join {schema}.curso_de_agua_eixo l2 on st_intersects(l1.geometria, l2.geometria) and l1.identificador <> l2.identificador
		group by st_intersection(l1.geometria, l2.geometria)
) select * from {schema}.no_hidrografico n1
	where ST_Intersects(n1.geometria, '%1$s') and geometria in (select geom from inter where count > 2)
		and (geometria in (select geometria from {schema}.no_hidrografico n2 where n1.identificador <> n2.identificador)
			or valor_tipo_no_hidrografico <> '3')$$ );

-- pseudo-nós
-- Entre dois nós só pode haver um segmento
-- Acrescentar para rede viária e hidrográfica

-- 6.5.3 REGRAS DO TEMA TRANSPORTES
-- SUBTEMA TRANSPORTE AÉREO
delete from validation.rules where code = 're5_1_1';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_1_1', 'Caracterização das áreas da infraestrutura de transporte aéreo', 
$$Cada área ou eventualmente um conjunto de áreas que caracterizam uma
"Área da infraestrutura de transporte aéreo" relacionam-se com um ponto
(representado no interior de uma das áreas, se possível) que corresponde a
uma "Infraestrutura de transporte aéreo".$$, 
$$"Área da infraestrutura de transporte aéreo" e "Infraestrutura de transporte
aéreo".$$, 'area_infra_trans_aereo',
$$with 
total as (select count(ai.*)
	from {schema}.area_infra_trans_aereo  ai, {schema}.valor_tipo_area_infra_trans_aereo v
	where ai.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'),
good as (select count(ai.*)
	from {schema}.area_infra_trans_aereo  ai, {schema}.valor_tipo_area_infra_trans_aereo v
	where ai.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
	and exists (select * from {schema}.infra_trans_aereo where st_contains(ST_Envelope(ai.geometria), geometria))),
bad as (select count(ai.*)
	from {schema}.area_infra_trans_aereo  ai, {schema}.valor_tipo_area_infra_trans_aereo v
	where ai.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
	and not exists (select * from {schema}.infra_trans_aereo where st_contains(ST_Envelope(ai.geometria), geometria)))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(ai.*)
	from {schema}.area_infra_trans_aereo  ai, {schema}.valor_tipo_area_infra_trans_aereo v
	where ai.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'),
good as (select count(ai.*)
	from {schema}.area_infra_trans_aereo  ai, {schema}.valor_tipo_area_infra_trans_aereo v
	where ai.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
	and exists (select * from {schema}.infra_trans_aereo where st_contains(ST_Envelope(ai.geometria), geometria))),
bad as (select count(ai.*)
	from {schema}.area_infra_trans_aereo  ai, {schema}.valor_tipo_area_infra_trans_aereo v
	where ai.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
	and not exists (select * from {schema}.infra_trans_aereo where st_contains(ST_Envelope(ai.geometria), geometria)))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select ai.*
	from {schema}.area_infra_trans_aereo  ai, {schema}.valor_tipo_area_infra_trans_aereo v
	where ai.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
	and not exists (select * from {schema}.infra_trans_aereo where st_contains(ST_Envelope(ai.geometria), geometria))$$ );

delete from validation.rules_area where code = 're5_1_1';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_1_1', 'Caracterização das áreas da infraestrutura de transporte aéreo', 
$$Cada área ou eventualmente um conjunto de áreas que caracterizam uma
"Área da infraestrutura de transporte aéreo" relacionam-se com um ponto
(representado no interior de uma das áreas, se possível) que corresponde a
uma "Infraestrutura de transporte aéreo".$$, 
$$"Área da infraestrutura de transporte aéreo" e "Infraestrutura de transporte
aéreo".$$, 'area_infra_trans_aereo',
$$with 
total as (select count(ai.*)
	from {schema}.area_infra_trans_aereo  ai, {schema}.valor_tipo_area_infra_trans_aereo v
	where ai.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'),
good as (select count(ai.*)
	from {schema}.area_infra_trans_aereo  ai, {schema}.valor_tipo_area_infra_trans_aereo v
	where ST_Intersects(geometria, '%1$s'::geometry) and ai.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
	and exists (select * from {schema}.infra_trans_aereo where st_contains(ST_Envelope(ai.geometria), geometria))),
bad as (select count(ai.*)
	from {schema}.area_infra_trans_aereo  ai, {schema}.valor_tipo_area_infra_trans_aereo v
	where ST_Intersects(geometria, '%1$s'::geometry) and ai.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
	and not exists (select * from {schema}.infra_trans_aereo where st_contains(ST_Envelope(ai.geometria), geometria)))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(ai.*)
	from {schema}.area_infra_trans_aereo  ai, {schema}.valor_tipo_area_infra_trans_aereo v
	where ST_Intersects(geometria, '%1$s'::geometry) and ai.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'),
good as (select count(ai.*)
	from {schema}.area_infra_trans_aereo  ai, {schema}.valor_tipo_area_infra_trans_aereo v
	where ST_Intersects(geometria, '%1$s'::geometry) and ai.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
	and exists (select * from {schema}.infra_trans_aereo where st_contains(ST_Envelope(ai.geometria), geometria))),
bad as (select count(ai.*)
	from {schema}.area_infra_trans_aereo  ai, {schema}.valor_tipo_area_infra_trans_aereo v
	where ST_Intersects(geometria, '%1$s'::geometry) and ai.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
	and not exists (select * from {schema}.infra_trans_aereo where st_contains(ST_Envelope(ai.geometria), geometria)))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select ai.*
	from {schema}.area_infra_trans_aereo  ai, {schema}.valor_tipo_area_infra_trans_aereo v
	where ST_Intersects(geometria, '%1$s'::geometry) and ai.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
	and not exists (select * from {schema}.infra_trans_aereo where st_contains(ST_Envelope(ai.geometria), geometria))$$ );


delete from validation.rules where code = 're5_1_2';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_1_2', 'Representação de um heliporto', 
$$Um heliporto é representado pela "Área da infraestrutura de transporte
aéreo" que limita a respetiva "Área de pista" (Figura 31 e Figura 32).$$, 
$$"Área da infraestrutura de transporte aéreo" e "Infraestrutura de transporte
aéreo".$$, 'infra_trans_aereo',
$$with 
total as (select count(ia.*) from {schema}.infra_trans_aereo  ia, {schema}.valor_tipo_infra_trans_aereo via
	 where ia.valor_tipo_infra_trans_aereo = via.identificador and (via.descricao = 'Heliporto' or via.descricao = 'Aeródromo com heliporto')),
good as ( select count(ia.*) from {schema}.infra_trans_aereo  ia, {schema}.valor_tipo_infra_trans_aereo via
	 where ia.valor_tipo_infra_trans_aereo = via.identificador and (via.descricao = 'Heliporto' or via.descricao = 'Aeródromo com heliporto')
	 and exists (
		select aia.*
		from {schema}.area_infra_trans_aereo  aia, {schema}.valor_tipo_area_infra_trans_aereo v
		where aia.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
		and st_contains(ST_Envelope(aia.geometria), ia.geometria)
		and exists (
			select aia_pista.*
			from {schema}.area_infra_trans_aereo  aia_pista, {schema}.valor_tipo_area_infra_trans_aereo v
			where aia_pista.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área de pista'
			and st_contains(ST_Envelope(aia.geometria), aia_pista.geometria)
			)
	 )),
bad as ( select count(ia.*) from {schema}.infra_trans_aereo  ia, {schema}.valor_tipo_infra_trans_aereo via
	 where ia.valor_tipo_infra_trans_aereo = via.identificador and (via.descricao = 'Heliporto' or via.descricao = 'Aeródromo com heliporto')
	 and not exists (
		select aia.*
		from {schema}.area_infra_trans_aereo  aia, {schema}.valor_tipo_area_infra_trans_aereo v
		where aia.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
		and st_contains(ST_Envelope(aia.geometria), ia.geometria)
		and exists (
			select aia_pista.*
			from {schema}.area_infra_trans_aereo  aia_pista, {schema}.valor_tipo_area_infra_trans_aereo v
			where aia_pista.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área de pista'
			and st_contains(ST_Envelope(aia.geometria), aia_pista.geometria)
			)
	 ))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(ia.*) from {schema}.infra_trans_aereo  ia, {schema}.valor_tipo_infra_trans_aereo via
	 where ia.valor_tipo_infra_trans_aereo = via.identificador and (via.descricao = 'Heliporto' or via.descricao = 'Aeródromo com heliporto')),
good as ( select count(ia.*) from {schema}.infra_trans_aereo  ia, {schema}.valor_tipo_infra_trans_aereo via
	 where ia.valor_tipo_infra_trans_aereo = via.identificador and (via.descricao = 'Heliporto' or via.descricao = 'Aeródromo com heliporto')
	 and exists (
		select aia.*
		from {schema}.area_infra_trans_aereo  aia, {schema}.valor_tipo_area_infra_trans_aereo v
		where aia.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
		and st_contains(ST_Envelope(aia.geometria), ia.geometria)
		and exists (
			select aia_pista.*
			from {schema}.area_infra_trans_aereo  aia_pista, {schema}.valor_tipo_area_infra_trans_aereo v
			where aia_pista.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área de pista'
			and st_contains(ST_Envelope(aia.geometria), aia_pista.geometria)
			)
	 )),
bad as ( select count(ia.*) from {schema}.infra_trans_aereo  ia, {schema}.valor_tipo_infra_trans_aereo via
	 where ia.valor_tipo_infra_trans_aereo = via.identificador and (via.descricao = 'Heliporto' or via.descricao = 'Aeródromo com heliporto')
	 and not exists (
		select aia.*
		from {schema}.area_infra_trans_aereo  aia, {schema}.valor_tipo_area_infra_trans_aereo v
		where aia.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
		and st_contains(ST_Envelope(aia.geometria), ia.geometria)
		and exists (
			select aia_pista.*
			from {schema}.area_infra_trans_aereo  aia_pista, {schema}.valor_tipo_area_infra_trans_aereo v
			where aia_pista.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área de pista'
			and st_contains(ST_Envelope(aia.geometria), aia_pista.geometria)
			)
	 ))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$ select ia.* from {schema}.infra_trans_aereo  ia, {schema}.valor_tipo_infra_trans_aereo via
 where ia.valor_tipo_infra_trans_aereo = via.identificador and (via.descricao = 'Heliporto' or via.descricao = 'Aeródromo com heliporto')
 and not exists (
	select aia.*
	from {schema}.area_infra_trans_aereo  aia, {schema}.valor_tipo_area_infra_trans_aereo v
	where aia.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
	and st_contains(ST_Envelope(aia.geometria), ia.geometria)
	and exists (
		select aia_pista.*
		from {schema}.area_infra_trans_aereo  aia_pista, {schema}.valor_tipo_area_infra_trans_aereo v
		where aia_pista.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área de pista'
		and st_contains(ST_Envelope(aia.geometria), aia_pista.geometria)
		)
 )$$ );

delete from validation.rules_area where code = 're5_1_2';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_1_2', 'Representação de um heliporto', 
$$Um heliporto é representado pela "Área da infraestrutura de transporte
aéreo" que limita a respetiva "Área de pista" (Figura 31 e Figura 32).$$, 
$$"Área da infraestrutura de transporte aéreo" e "Infraestrutura de transporte
aéreo".$$, 'infra_trans_aereo',
$$with 
total as (select count(ia.*) from {schema}.infra_trans_aereo  ia, {schema}.valor_tipo_infra_trans_aereo via
	 where ia.valor_tipo_infra_trans_aereo = via.identificador and (via.descricao = 'Heliporto' or via.descricao = 'Aeródromo com heliporto')),
good as ( select count(ia.*) from {schema}.infra_trans_aereo  ia, {schema}.valor_tipo_infra_trans_aereo via
	 where ST_Intersects(geometria, '%1$s'::geometry) and ia.valor_tipo_infra_trans_aereo = via.identificador and (via.descricao = 'Heliporto' or via.descricao = 'Aeródromo com heliporto')
	 and exists (
		select aia.*
		from {schema}.area_infra_trans_aereo  aia, {schema}.valor_tipo_area_infra_trans_aereo v
		where aia.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
		and st_contains(ST_Envelope(aia.geometria), ia.geometria)
		and exists (
			select aia_pista.*
			from {schema}.area_infra_trans_aereo  aia_pista, {schema}.valor_tipo_area_infra_trans_aereo v
			where aia_pista.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área de pista'
			and st_contains(ST_Envelope(aia.geometria), aia_pista.geometria)
			)
	 )),
bad as ( select count(ia.*) from {schema}.infra_trans_aereo  ia, {schema}.valor_tipo_infra_trans_aereo via
	 where ST_Intersects(geometria, '%1$s'::geometry) and ia.valor_tipo_infra_trans_aereo = via.identificador and (via.descricao = 'Heliporto' or via.descricao = 'Aeródromo com heliporto')
	 and not exists (
		select aia.*
		from {schema}.area_infra_trans_aereo  aia, {schema}.valor_tipo_area_infra_trans_aereo v
		where aia.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
		and st_contains(ST_Envelope(aia.geometria), ia.geometria)
		and exists (
			select aia_pista.*
			from {schema}.area_infra_trans_aereo  aia_pista, {schema}.valor_tipo_area_infra_trans_aereo v
			where aia_pista.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área de pista'
			and st_contains(ST_Envelope(aia.geometria), aia_pista.geometria)
			)
	 ))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(ia.*) from {schema}.infra_trans_aereo  ia, {schema}.valor_tipo_infra_trans_aereo via
	 where ia.valor_tipo_infra_trans_aereo = via.identificador and (via.descricao = 'Heliporto' or via.descricao = 'Aeródromo com heliporto')),
good as ( select count(ia.*) from {schema}.infra_trans_aereo  ia, {schema}.valor_tipo_infra_trans_aereo via
	 where ST_Intersects(geometria, '%1$s'::geometry) and ia.valor_tipo_infra_trans_aereo = via.identificador and (via.descricao = 'Heliporto' or via.descricao = 'Aeródromo com heliporto')
	 and exists (
		select aia.*
		from {schema}.area_infra_trans_aereo  aia, {schema}.valor_tipo_area_infra_trans_aereo v
		where aia.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
		and st_contains(ST_Envelope(aia.geometria), ia.geometria)
		and exists (
			select aia_pista.*
			from {schema}.area_infra_trans_aereo  aia_pista, {schema}.valor_tipo_area_infra_trans_aereo v
			where aia_pista.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área de pista'
			and st_contains(ST_Envelope(aia.geometria), aia_pista.geometria)
			)
	 )),
bad as ( select count(ia.*) from {schema}.infra_trans_aereo  ia, {schema}.valor_tipo_infra_trans_aereo via
	 where ST_Intersects(geometria, '%1$s'::geometry) and ia.valor_tipo_infra_trans_aereo = via.identificador and (via.descricao = 'Heliporto' or via.descricao = 'Aeródromo com heliporto')
	 and not exists (
		select aia.*
		from {schema}.area_infra_trans_aereo  aia, {schema}.valor_tipo_area_infra_trans_aereo v
		where aia.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
		and st_contains(ST_Envelope(aia.geometria), ia.geometria)
		and exists (
			select aia_pista.*
			from {schema}.area_infra_trans_aereo  aia_pista, {schema}.valor_tipo_area_infra_trans_aereo v
			where aia_pista.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área de pista'
			and st_contains(ST_Envelope(aia.geometria), aia_pista.geometria)
			)
	 ))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$ select ia.* from {schema}.infra_trans_aereo  ia, {schema}.valor_tipo_infra_trans_aereo via
 where ST_Intersects(geometria, '%1$s'::geometry) and ia.valor_tipo_infra_trans_aereo = via.identificador and (via.descricao = 'Heliporto' or via.descricao = 'Aeródromo com heliporto')
 and not exists (
	select aia.*
	from {schema}.area_infra_trans_aereo  aia, {schema}.valor_tipo_area_infra_trans_aereo v
	where aia.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área da infraestrutura'
	and st_contains(ST_Envelope(aia.geometria), ia.geometria)
	and exists (
		select aia_pista.*
		from {schema}.area_infra_trans_aereo  aia_pista, {schema}.valor_tipo_area_infra_trans_aereo v
		where aia_pista.valor_tipo_area_infra_trans_aereo = v.identificador and v.descricao = 'Área de pista'
		and st_contains(ST_Envelope(aia.geometria), aia_pista.geometria)
		)
 )$$ );


-- TODO
-- TODAS AS INTERSEÇÕES entre seg_via_ferrea
-- POINT ou MULTIPOINT; Se as mesmas duas linhas se voltam a juntar, o resultado é MULTIPOINT
delete from validation.rules where code = 're5_2_2_1';
delete from validation.rules where code = 're5_2_2';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_2_2', 'Interrupção da via-férrea', 
$$O "Segmento da via-férrea" é interrompido quando:
 - Existe uma interceção com outro "Segmento de via-férrea";
 - Existe uma alteração do valor de qualquer um dos atributos que
caracteriza o "Segmento de via-férrea";
 - Existe uma interceção com um "Segmento de via rodoviária"
("Passagem de nível");
 - Existe um "Nó de transporte ferroviário" correspondente à existência
de uma "Infraestrutura de transporte ferroviário".
 - Existe uma mudança do(s) nome(s) da(s) "Linha férrea".$$, 
$$"Segmento da via-férrea", "Linha férrea", "Infraestrutura de transporte
ferroviário" e "Nó de transporte ferroviário".$$, 'seg_via_ferrea',
$$with 
all_intersecoes as (select (st_dump(st_intersection(cf1.geometria, cf2.geometria))).*
	from {schema}.seg_via_ferrea cf1, {schema}.seg_via_ferrea cf2
	where cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria)),
ok_intersecoes as (select (st_dump(st_intersection(cf1.geometria, cf2.geometria))).*
	from {schema}.seg_via_ferrea cf1, {schema}.seg_via_ferrea cf2
	where cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) 
	and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) in ('POINT' , 'MULTIPOINT')),
total as (select count(*) from all_intersecoes),
good as (select count(*) from 
	ok_intersecoes where geom in (
		select st_startpoint(geometria) from {schema}.seg_via_ferrea
		union
		select st_endpoint(geometria) from {schema}.seg_via_ferrea
	)),
linhas_duplicadas as (
select count(cf1.*)
from {schema}.seg_via_ferrea cf1, {schema}.seg_via_ferrea cf2
where cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) 
and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) not in ('POINT' , 'MULTIPOINT')),
inexistentes as (
	select count(*) from 
	ok_intersecoes where geom not in (
		select st_startpoint(geometria) from {schema}.seg_via_ferrea
		union
		select st_endpoint(geometria) from {schema}.seg_via_ferrea
	)),
bad as (select inexistentes.count + linhas_duplicadas.count as count
	from inexistentes, linhas_duplicadas)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
all_intersecoes as (select (st_dump(st_intersection(cf1.geometria, cf2.geometria))).*
	from {schema}.seg_via_ferrea cf1, {schema}.seg_via_ferrea cf2
	where cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria)),
ok_intersecoes as (select (st_dump(st_intersection(cf1.geometria, cf2.geometria))).*
	from {schema}.seg_via_ferrea cf1, {schema}.seg_via_ferrea cf2
	where cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) 
	and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) in ('POINT' , 'MULTIPOINT')),
total as (select count(*) from all_intersecoes),
good as (select count(*) from 
	ok_intersecoes where geom in (
		select st_startpoint(geometria) from {schema}.seg_via_ferrea
		union
		select st_endpoint(geometria) from {schema}.seg_via_ferrea
	)),
linhas_duplicadas as (
select count(cf1.*)
from {schema}.seg_via_ferrea cf1, {schema}.seg_via_ferrea cf2
where cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) 
and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) not in ('POINT' , 'MULTIPOINT')),
inexistentes as (
	select count(*) from 
	ok_intersecoes where geom not in (
		select st_startpoint(geometria) from {schema}.seg_via_ferrea
		union
		select st_endpoint(geometria) from {schema}.seg_via_ferrea
	)),
bad as (select inexistentes.count + linhas_duplicadas.count as count
	from inexistentes, linhas_duplicadas)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$ with 
ok_intersecoes as (select (st_dump(st_intersection(cf1.geometria, cf2.geometria))).*
	from {schema}.seg_via_ferrea cf1, {schema}.seg_via_ferrea cf2
	where cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) 
	and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) in ('POINT' , 'MULTIPOINT')),
linhas_duplicadas as (
select cf1.*
from {schema}.seg_via_ferrea cf1, {schema}.seg_via_ferrea cf2
where cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) 
and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) not in ('POINT' , 'MULTIPOINT')),
inexistentes as (
	select * from 
	ok_intersecoes where geom not in (
		select st_startpoint(geometria) from {schema}.seg_via_ferrea
		union
		select st_endpoint(geometria) from {schema}.seg_via_ferrea
	)),
segmentos as (select svf.* from {schema}.seg_via_ferrea svf, inexistentes i where st_contains(svf.geometria, i.geom) )
select * from segmentos union select * from linhas_duplicadas $$ );

delete from validation.rules_area where code = 're5_2_2_1';
delete from validation.rules_area where code = 're5_2_2';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_2_2', 'Interrupção da via-férrea', 
$$O "Segmento da via-férrea" é interrompido quando:
 - Existe uma interceção com outro "Segmento de via-férrea";
 - Existe uma alteração do valor de qualquer um dos atributos que
caracteriza o "Segmento de via-férrea";
 - Existe uma interceção com um "Segmento de via rodoviária"
("Passagem de nível");
 - Existe um "Nó de transporte ferroviário" correspondente à existência
de uma "Infraestrutura de transporte ferroviário".
 - Existe uma mudança do(s) nome(s) da(s) "Linha férrea".$$, 
$$"Segmento da via-férrea", "Linha férrea", "Infraestrutura de transporte
ferroviário" e "Nó de transporte ferroviário".$$, 'seg_via_ferrea',
$$with 
all_intersecoes as (select (st_dump(st_intersection(cf1.geometria, cf2.geometria))).*
	from {schema}.seg_via_ferrea cf1, {schema}.seg_via_ferrea cf2
	where ST_Intersects(cf1.geometria, '%1$s'::geometry) and cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria)),
ok_intersecoes as (select (st_dump(st_intersection(cf1.geometria, cf2.geometria))).*
	from {schema}.seg_via_ferrea cf1, {schema}.seg_via_ferrea cf2
	where ST_Intersects(cf1.geometria, '%1$s'::geometry) and cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) 
	and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) in ('POINT' , 'MULTIPOINT')),
total as (select count(*) from all_intersecoes),
good as (select count(*) from 
	ok_intersecoes where geom in (
		select st_startpoint(geometria) from {schema}.seg_via_ferrea
		union
		select st_endpoint(geometria) from {schema}.seg_via_ferrea
	)),
linhas_duplicadas as (
select count(cf1.*)
from {schema}.seg_via_ferrea cf1, {schema}.seg_via_ferrea cf2
where ST_Intersects(cf1.geometria, '%1$s') and cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) 
and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) not in ('POINT' , 'MULTIPOINT')),
inexistentes as (
	select count(*) from 
	ok_intersecoes where geom not in (
		select st_startpoint(geometria) from {schema}.seg_via_ferrea
		union
		select st_endpoint(geometria) from {schema}.seg_via_ferrea
	)),
bad as (select inexistentes.count + linhas_duplicadas.count as count
	from inexistentes, linhas_duplicadas)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
all_intersecoes as (select (st_dump(st_intersection(cf1.geometria, cf2.geometria))).*
	from {schema}.seg_via_ferrea cf1, {schema}.seg_via_ferrea cf2
	where ST_Intersects(cf1.geometria, '%1$s'::geometry) and cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria)),
ok_intersecoes as (select (st_dump(st_intersection(cf1.geometria, cf2.geometria))).*
	from {schema}.seg_via_ferrea cf1, {schema}.seg_via_ferrea cf2
	where ST_Intersects(cf1.geometria, '%1$s'::geometry) and cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) 
	and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) in ('POINT' , 'MULTIPOINT')),
total as (select count(*) from all_intersecoes),
good as (select count(*) from 
	ok_intersecoes where geom in (
		select st_startpoint(geometria) from {schema}.seg_via_ferrea
		union
		select st_endpoint(geometria) from {schema}.seg_via_ferrea
	)),
linhas_duplicadas as (
select count(cf1.*)
from {schema}.seg_via_ferrea cf1, {schema}.seg_via_ferrea cf2
where ST_Intersects(cf1.geometria, '%1$s'::geometry) and cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) 
and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) not in ('POINT' , 'MULTIPOINT')),
inexistentes as (
	select count(*) from 
	ok_intersecoes where geom not in (
		select st_startpoint(geometria) from {schema}.seg_via_ferrea
		union
		select st_endpoint(geometria) from {schema}.seg_via_ferrea
	)),
bad as (select inexistentes.count + linhas_duplicadas.count as count
	from inexistentes, linhas_duplicadas)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$ with 
ok_intersecoes as (select (st_dump(st_intersection(cf1.geometria, cf2.geometria))).*
	from {schema}.seg_via_ferrea cf1, {schema}.seg_via_ferrea cf2
	where ST_Intersects(cf1.geometria, '%1$s'::geometry) and cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) 
	and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) in ('POINT' , 'MULTIPOINT')),
linhas_duplicadas as (
select cf1.*
from {schema}.seg_via_ferrea cf1, {schema}.seg_via_ferrea cf2
where ST_Intersects(cf1.geometria, '%1$s'::geometry) and cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) 
and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) not in ('POINT' , 'MULTIPOINT')),
inexistentes as (
	select * from 
	ok_intersecoes where geom not in (
		select st_startpoint(geometria) from {schema}.seg_via_ferrea
		union
		select st_endpoint(geometria) from {schema}.seg_via_ferrea
	)),
segmentos as (select svf.* from {schema}.seg_via_ferrea svf, inexistentes i where st_contains(svf.geometria, i.geom) )
select * from segmentos union select * from linhas_duplicadas $$ );

-- RE5.2.3
-- Regras semelhantes: re4_9_1, re5_2_3, re5_5_3
-- TODO
-- Respeitar o tipo de nós:
delete from validation.rules where code = 're5_2_3_1';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_2_3_1', 'Conexão entre segmentos e nós da via-férrea (Parte 1)', 
$$Um "Segmento da via-férrea" conecta obrigatoriamente com dois objetos "Nó
de transporte ferroviário".$$, 
$$"Segmento da via-férrea" e "Nó de transporte ferroviário".$$, 'seg_via_ferrea',
$$with 
total as (select count(*) from {schema}.seg_via_ferrea),
good as (select count(svf.*)
	from {schema}.seg_via_ferrea svf, validation.area_trabalho_multi adt
	where (ST_StartPoint(svf.geometria) in (select geometria from {schema}.no_trans_ferrov) and ST_EndPoint(svf.geometria) in (select geometria from {schema}.no_trans_ferrov))
		or st_intersects(svf.geometria, ST_ExteriorRing(adt.geometria))
),
bad as (select count(svf.*)
	from {schema}.seg_via_ferrea svf, validation.area_trabalho_multi adt
	where (ST_StartPoint(svf.geometria) not in (select geometria from {schema}.no_trans_ferrov) or ST_EndPoint(svf.geometria) not in (select geometria from {schema}.no_trans_ferrov))
		and not st_intersects(svf.geometria, ST_ExteriorRing(adt.geometria))
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$with 
total as (select count(*) from {schema}.seg_via_ferrea),
good as (select count(svf.*)
	from {schema}.seg_via_ferrea svf, validation.area_trabalho_multi adt
	where (ST_StartPoint(svf.geometria) in (select geometria from {schema}.no_trans_ferrov) and ST_EndPoint(svf.geometria) in (select geometria from {schema}.no_trans_ferrov))
		or st_intersects(svf.geometria, ST_ExteriorRing(adt.geometria))
),
bad as (select count(svf.*)
	from {schema}.seg_via_ferrea svf, validation.area_trabalho_multi adt
	where (ST_StartPoint(svf.geometria) not in (select geometria from {schema}.no_trans_ferrov) or ST_EndPoint(svf.geometria) not in (select geometria from {schema}.no_trans_ferrov))
		and not st_intersects(svf.geometria, ST_ExteriorRing(adt.geometria))
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$select svf.*
	from {schema}.seg_via_ferrea svf, validation.area_trabalho_multi adt
	where (ST_StartPoint(svf.geometria) not in (select geometria from {schema}.no_trans_ferrov) or ST_EndPoint(svf.geometria) not in (select geometria from {schema}.no_trans_ferrov))
		and not st_intersects(svf.geometria, ST_ExteriorRing(adt.geometria))$$ );

delete from validation.rules_area where code = 're5_2_3_1';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_2_3_1', 'Conexão entre segmentos e nós da via-férrea (Parte 1)', 
$$Um "Segmento da via-férrea" conecta obrigatoriamente com dois objetos "Nó
de transporte ferroviário".$$, 
$$"Segmento da via-férrea" e "Nó de transporte ferroviário".$$, 'seg_via_ferrea',
$$with 
total as (select count(*) from {schema}.seg_via_ferrea),
good as (select count(svf.*)
	from {schema}.seg_via_ferrea svf, validation.area_trabalho_multi adt
	where ST_Intersects(svf.geometria, '%1$s'::geometry) and ((ST_StartPoint(svf.geometria) in (select geometria from {schema}.no_trans_ferrov) and ST_EndPoint(svf.geometria) in (select geometria from {schema}.no_trans_ferrov))
		or st_intersects(svf.geometria, ST_ExteriorRing(adt.geometria)))
),
bad as (select count(svf.*)
	from {schema}.seg_via_ferrea svf, validation.area_trabalho_multi adt
	where ST_Intersects(svf.geometria, '%1$s'::geometry) and (ST_StartPoint(svf.geometria) not in (select geometria from {schema}.no_trans_ferrov) or ST_EndPoint(svf.geometria) not in (select geometria from {schema}.no_trans_ferrov))
		and not st_intersects(svf.geometria, ST_ExteriorRing(adt.geometria))
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$with 
total as (select count(*) from {schema}.seg_via_ferrea),
good as (select count(svf.*)
	from {schema}.seg_via_ferrea svf, validation.area_trabalho_multi adt
	where ST_Intersects(svf.geometria, '%1$s'::geometry) and ((ST_StartPoint(svf.geometria) in (select geometria from {schema}.no_trans_ferrov) and ST_EndPoint(svf.geometria) in (select geometria from {schema}.no_trans_ferrov))
		or st_intersects(svf.geometria, ST_ExteriorRing(adt.geometria)))
),
bad as (select count(svf.*)
	from {schema}.seg_via_ferrea svf, validation.area_trabalho_multi adt
	where ST_Intersects(svf.geometria, '%1$s'::geometry) and (ST_StartPoint(svf.geometria) not in (select geometria from {schema}.no_trans_ferrov) or ST_EndPoint(svf.geometria) not in (select geometria from {schema}.no_trans_ferrov))
		and not st_intersects(svf.geometria, ST_ExteriorRing(adt.geometria))
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$select svf.*
	from {schema}.seg_via_ferrea svf, validation.area_trabalho_multi adt
	where ST_Intersects(svf.geometria, '%1$s'::geometry) and (ST_StartPoint(svf.geometria) not in (select geometria from {schema}.no_trans_ferrov) or ST_EndPoint(svf.geometria) not in (select geometria from {schema}.no_trans_ferrov))
		and not st_intersects(svf.geometria, ST_ExteriorRing(adt.geometria))$$ );


delete from validation.rules where code = 're5_2_3_2';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_2_3_2', 'Conexão entre segmentos e nós da via-férrea (Parte 2)', 
$$Um "Nó de transporte ferroviário" conecta obrigatoriamente com pelo menos
um "Segmento da via-férrea".$$, 
$$"Segmento da via-férrea" e "Nó de transporte ferroviário".$$, 'no_trans_ferrov',
$$with 
total as (select count(*) from {schema}.no_trans_ferrov),
good as (select count(*) 
	from {schema}.no_trans_ferrov
	where geometria in (
	select ST_StartPoint(geometria) from {schema}.seg_via_ferrea
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_ferrea)),
bad as (select count(*) 
	from {schema}.no_trans_ferrov
	where geometria not in (
	select ST_StartPoint(geometria) from {schema}.seg_via_ferrea
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_ferrea))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.no_trans_ferrov),
good as (select count(*) 
	from {schema}.no_trans_ferrov
	where geometria in (
	select ST_StartPoint(geometria) from {schema}.seg_via_ferrea
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_ferrea)),
bad as (select count(*) 
	from {schema}.no_trans_ferrov
	where geometria not in (
	select ST_StartPoint(geometria) from {schema}.seg_via_ferrea
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_ferrea))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$ select *
	from {schema}.no_trans_ferrov
	where geometria not in (
	select ST_StartPoint(geometria) from {schema}.seg_via_ferrea
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_ferrea)$$ );

delete from validation.rules_area where code = 're5_2_3_2';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_2_3_2', 'Conexão entre segmentos e nós da via-férrea (Parte 2)', 
$$Um "Nó de transporte ferroviário" conecta obrigatoriamente com pelo menos
um "Segmento da via-férrea".$$, 
$$"Segmento da via-férrea" e "Nó de transporte ferroviário".$$, 'no_trans_ferrov',
$$with 
total as (select count(*) from {schema}.no_trans_ferrov),
good as (select count(*) 
	from {schema}.no_trans_ferrov
	where ST_Intersects(geometria, '%1$s'::geometry) and geometria in (
	select ST_StartPoint(geometria) from {schema}.seg_via_ferrea
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_ferrea)),
bad as (select count(*) 
	from {schema}.no_trans_ferrov
	where ST_Intersects(geometria, '%1$s'::geometry) and geometria not in (
	select ST_StartPoint(geometria) from {schema}.seg_via_ferrea
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_ferrea))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.no_trans_ferrov),
good as (select count(*) 
	from {schema}.no_trans_ferrov
	where ST_Intersects(geometria, '%1$s'::geometry) and geometria in (
	select ST_StartPoint(geometria) from {schema}.seg_via_ferrea
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_ferrea)),
bad as (select count(*) 
	from {schema}.no_trans_ferrov
	where ST_Intersects(geometria, '%1$s'::geometry) and geometria not in (
	select ST_StartPoint(geometria) from {schema}.seg_via_ferrea
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_ferrea))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$ select *
	from {schema}.no_trans_ferrov
	where ST_Intersects(geometria, '%1$s'::geometry) and geometria not in (
	select ST_StartPoint(geometria) from {schema}.seg_via_ferrea
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_ferrea)$$ );
	

-- RE5.2.4
delete from validation.rules where code = 're5_2_4';
insert into validation.rules ( code, name, rule, scope, entity, query, report ) 
values ('re5_2_4', 'Nós terminais da via-férrea', 
$$Quando um “Segmento da via-férrea” tem o seu fim numa “Infraestrutura de transporte ferroviário” é colocado um “Nó de transporte ferroviário” 
correspondente ao fim da via e um outro “Nó de transporte ferroviário” correspondente à infraestrutura. 
Os nós são colocados nas mesmas coordenadas (mesma localização) no “Segmento da via-férrea” em conformidade com a topologia implícita.$$, 
$$"Segmento da via-férrea, Infraestrutura de transporte ferroviário, Nó de transporte ferroviário".$$, 'no_trans_ferrov',
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.seg_via_ferrea l1
		join {schema}.infra_trans_ferrov l2 on st_intersects(ST_StartPoint(l1.geometria), l2.geometria) or st_intersects(ST_EndPoint(l1.geometria), l2.geometria)
		group by st_intersection(l1.geometria, l2.geometria)
), total as (
	select count(*) from inter
), good as (
	select count(*) from inter where (select count(*) from {schema}.no_trans_ferrov where geom=geometria) = 2
), bad as (
	select count(*) from inter where (select count(*) from {schema}.no_trans_ferrov where geom=geometria) <> 2
) select total.count as total, good.count as good, bad.count as bad from total, good, bad$$,
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.seg_via_ferrea l1
		join {schema}.infra_trans_ferrov l2 on st_intersects(ST_StartPoint(l1.geometria), l2.geometria) or st_intersects(ST_EndPoint(l1.geometria), l2.geometria)
		group by st_intersection(l1.geometria, l2.geometria)
) select * from {schema}.no_trans_ferrov where geometria in (select geom from inter where (select count(*) from {schema}.no_trans_ferrov where geom=geometria) <> 2)$$ );


delete from validation.rules_area where code = 're5_2_4';
insert into validation.rules_area ( code, name, rule, scope, entity, query, report )
values ('re5_2_4', 'Nós terminais da via-férrea',
$$Quando um “Segmento da via-férrea” tem o seu fim numa “Infraestrutura de transporte ferroviário” é colocado um “Nó de transporte ferroviário”
correspondente ao fim da via e um outro “Nó de transporte ferroviário” correspondente à infraestrutura.
Os nós são colocados nas mesmas coordenadas (mesma localização) no “Segmento da via-férrea” em conformidade com a topologia implícita.$$,
$$"Segmento da via-férrea, Infraestrutura de transporte ferroviário, Nó de transporte ferroviário".$$, 'no_trans_ferrov',
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.seg_via_ferrea l1
		join {schema}.infra_trans_ferrov l2 on st_intersects(ST_StartPoint(l1.geometria), l2.geometria) or st_intersects(ST_EndPoint(l1.geometria), l2.geometria)
		group by st_intersection(l1.geometria, l2.geometria)
), total as (
	select count(*) from inter
), good as (
	select count(*) from inter where ST_Intersects(geom, '%1$s') and (select count(*) from {schema}.no_trans_ferrov where geom=geometria) = 2
), bad as (
	select count(*) from inter where ST_Intersects(geom, '%1$s') and (select count(*) from {schema}.no_trans_ferrov where geom=geometria) <> 2
) select total.count as total, good.count as good, bad.count as bad from total, good, bad$$,
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.seg_via_ferrea l1
		join {schema}.infra_trans_ferrov l2 on st_intersects(ST_StartPoint(l1.geometria), l2.geometria) or st_intersects(ST_EndPoint(l1.geometria), l2.geometria)
		group by st_intersection(l1.geometria, l2.geometria)
) select * from {schema}.no_trans_ferrov n1 where ST_Intersects(n1.geometria, '%1$s') and n1.geometria in (select geom from inter where (select count(*) from {schema}.no_trans_ferrov n2 where geom=n2geometria) <> 2)$$ );


-- RE5.2.5
delete from validation.rules where code = 're5_2_5';
insert into validation.rules ( code, name, rule, scope, entity, query, report ) 
values ('re5_2_5', 'Hierarquia dos nós da via-férrea', 
$$Quando um “Segmento da via-férrea” interseta outro e, simultaneamente, observa-se uma alteração de atributos, o “Nó de transporte ferroviário” 
assume o valor “Junção”. Apenas é inserido um nó que assume o valor “Junção” prevalecendo este sobre o valor “Pseudo-nó“.$$, 
$$"Segmento da via-férrea, Nó de transporte ferroviário".$$, 'no_trans_ferrov',
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.seg_via_ferrea l1
		join {schema}.seg_via_ferrea l2 on st_intersects(l1.geometria, l2.geometria) and l1.identificador <> l2.identificador
		group by st_intersection(l1.geometria, l2.geometria)
),
total as (
	select count(*) from inter where count > 2
),
good as (
	select count(*) from {schema}.no_trans_ferrov n1
	where geometria in (select geom from inter where count > 2)
		and geometria not in (select geometria from {schema}.no_trans_ferrov n2 where n1.identificador <> n2.identificador)
		and valor_tipo_no_trans_ferrov = '1'
),
bad as (
	select count(*) from {schema}.no_trans_ferrov n1
	where geometria in (select geom from inter where count > 2)
		and (geometria in (select geometria from {schema}.no_trans_ferrov n2 where n1.identificador <> n2.identificador)
			or valor_tipo_no_trans_ferrov <> '1')
) select total.count as total, good.count as good, bad.count as bad from total, good, bad$$,
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.seg_via_ferrea l1
		join {schema}.seg_via_ferrea l2 on st_intersects(l1.geometria, l2.geometria) and l1.identificador <> l2.identificador
		group by st_intersection(l1.geometria, l2.geometria)
) select * from {schema}.no_trans_ferrov n1
	where geometria in (select geom from inter where count > 2)
		and (geometria in (select geometria from {schema}.no_trans_ferrov n2 where n1.identificador <> n2.identificador)
			or valor_tipo_no_trans_ferrov <> '1')$$ );


delete from validation.rules_area where code = 're5_2_5';
insert into validation.rules_area ( code, name, rule, scope, entity, query, report ) 
values ('re5_2_5', 'Hierarquia dos nós da via-férrea', 
$$Quando um “Segmento da via-férrea” interseta outro e, simultaneamente, observa-se uma alteração de atributos, o “Nó de transporte ferroviário” 
assume o valor “Junção”. Apenas é inserido um nó que assume o valor “Junção” prevalecendo este sobre o valor “Pseudo-nó“.$$, 
$$"Segmento da via-férrea, Nó de transporte ferroviário".$$, 'no_trans_ferrov',
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.seg_via_ferrea l1
		join {schema}.seg_via_ferrea l2 on st_intersects(l1.geometria, l2.geometria) and l1.identificador <> l2.identificador
		group by st_intersection(l1.geometria, l2.geometria)
),
total as (
	select count(*) from inter where count > 2
),
good as (
	select count(*) from {schema}.no_trans_ferrov n1
	where ST_Intersects(n1.geometria, '%1$s') and geometria in (select geom from inter where count > 2)
		and geometria not in (select geometria from {schema}.no_trans_ferrov n2 where n1.identificador <> n2.identificador)
		and valor_tipo_no_trans_ferrov = '1'
),
bad as (
	select count(*) from {schema}.no_trans_ferrov n1
	where ST_Intersects(n1.geometria, '%1$s') and geometria in (select geom from inter where count > 2)
		and (geometria in (select geometria from {schema}.no_trans_ferrov n2 where n1.identificador <> n2.identificador)
			or valor_tipo_no_trans_ferrov <> '1')
) select total.count as total, good.count as good, bad.count as bad from total, good, bad$$,
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.seg_via_ferrea l1
		join {schema}.seg_via_ferrea l2 on st_intersects(l1.geometria, l2.geometria) and l1.identificador <> l2.identificador
		group by st_intersection(l1.geometria, l2.geometria)
) select * from {schema}.no_trans_ferrov n1
	where ST_Intersects(n1.geometria, '%1$s') and geometria in (select geom from inter where count > 2)
		and (geometria in (select geometria from {schema}.no_trans_ferrov n2 where n1.identificador <> n2.identificador)
			or valor_tipo_no_trans_ferrov <> '1')$$ );


-- RE5.2.6
-- Regras semelhantes: re5_1_1, re_5_2_6, re_5_5_7
-- Esta regra é garantida pelo modelo de dados
delete from validation.rules where code = 're5_2_6';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_2_6', 'Caracterização das áreas da infraestrutura de transporte ferroviário', 
$$Cada área ou eventualmente um conjunto de áreas que caracterizam uma
"Área da infraestrutura de transporte ferroviário" relacionam-se com um
ponto (representado no interior de uma das áreas, se possível) que
corresponde a uma "Infraestrutura de transporte ferroviário".$$, 
$$"Área da infraestrutura de transporte ferroviário" e "Infraestrutura de
transporte ferroviário".$$, 'area_infra_trans_ferrov',
$$with 
total as (select count(*) from {schema}.area_infra_trans_ferrov),
good as (select count(*) from {schema}.area_infra_trans_ferrov where infra_trans_ferrov_id is not NULL),
bad as (select count(*) from {schema}.area_infra_trans_ferrov where infra_trans_ferrov_id is NULL)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.area_infra_trans_ferrov),
good as (select count(*) from {schema}.area_infra_trans_ferrov where infra_trans_ferrov_id is not NULL),
bad as (select count(*) from {schema}.area_infra_trans_ferrov where infra_trans_ferrov_id is NULL)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select * from {schema}.area_infra_trans_ferrov where infra_trans_ferrov_id is null $$ );

delete from validation.rules_area where code = 're5_2_6';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_2_6', 'Caracterização das áreas da infraestrutura de transporte ferroviário', 
$$Cada área ou eventualmente um conjunto de áreas que caracterizam uma
"Área da infraestrutura de transporte ferroviário" relacionam-se com um
ponto (representado no interior de uma das áreas, se possível) que
corresponde a uma "Infraestrutura de transporte ferroviário".$$, 
$$"Área da infraestrutura de transporte ferroviário" e "Infraestrutura de
transporte ferroviário".$$, 'area_infra_trans_ferrov',
$$with 
total as (select count(*) from {schema}.area_infra_trans_ferrov),
good as (select count(*) from {schema}.area_infra_trans_ferrov where ST_Intersects(geometria, '%1$s'::geometry) and infra_trans_ferrov_id is not NULL),
bad as (select count(*) from {schema}.area_infra_trans_ferrov where ST_Intersects(geometria, '%1$s'::geometry) and infra_trans_ferrov_id is NULL)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.area_infra_trans_ferrov),
good as (select count(*) from {schema}.area_infra_trans_ferrov where ST_Intersects(geometria, '%1$s'::geometry) and infra_trans_ferrov_id is not NULL),
bad as (select count(*) from {schema}.area_infra_trans_ferrov where ST_Intersects(geometria, '%1$s'::geometry) and infra_trans_ferrov_id is NULL)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select * from {schema}.area_infra_trans_ferrov where ST_Intersects(geometria, '%1$s'::geometry) and infra_trans_ferrov_id is null $$ );

-- SUBTEMA TRANSPORTE POR CABO
-- RE5.3.1
-- 

-- Subtema "Transporte por via navegável"
-- RE5.4.1
-- Igual à RE5.2.6 (e igual  à das infraestruturas aéreas)

-- Subtema "Transporte rodoviário"

-- Interrupção da via rodoviária
-- RE5.5.2
delete from validation.rules where code = 're5_5_2';
insert into validation.rules ( code, name, rule, scope, entity, query, report ) 
values ('re5_5_2', 'Interrupção da via rodoviária', 
$$O “Segmento da via-férrea” é interrompido quando:
 - Existe uma interceção com outro “Segmento da via-férrea”;
 - Existe uma alteração do valor de qualquer um dos atributos que
caracteriza o “Segmento da via-férrea”;
 - Existe uma interceção com um “Segmento da via rodoviária” e que
seja efetivamente uma “Passagem de nível” (#2
valorTipoNoTransFerrov e #2 valorTipoNoTransRodov) em estado
“Funcional” (#5 valorEstadoLinhaFerrea);
 - Existe um “Nó de transporte ferroviário” correspondente à existência
de uma “Infraestrutura de transporte ferroviário”.
 - Existe uma mudança do(s) nome(s) da(s) “Linha férrea”.$$, 
$$"“Segmento da via rodoviária”, “Via rodoviária - Limite”, “Segmento da via-
férrea”, “Nó de transporte rodoviário” e “Infraestrutura de transporte
rodoviário”".$$, 'seg_via_rodov',
$$with 
all_intersecoes as (select (st_dump(st_intersection(cf1.geometria, cf2.geometria))).*
	from {schema}.seg_via_rodov cf1, {schema}.seg_via_rodov cf2
	where cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) and cf1.valor_posicao_vertical_transportes = cf2.valor_posicao_vertical_transportes),
ok_intersecoes as (select (st_dump(st_intersection(cf1.geometria, cf2.geometria))).*
	from {schema}.seg_via_rodov cf1, {schema}.seg_via_rodov cf2
	where cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) and cf1.valor_posicao_vertical_transportes = cf2.valor_posicao_vertical_transportes
	and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) in ('POINT' , 'MULTIPOINT')),
existentes as (
	select * from ok_intersecoes where geom in (
		select st_startpoint(geometria) from {schema}.seg_via_rodov
		union
		select st_endpoint(geometria) from {schema}.seg_via_rodov
	)
),
inexistentes as (
	select * from 
	ok_intersecoes where geom not in (
		select st_startpoint(geometria) from {schema}.seg_via_rodov
		union
		select st_endpoint(geometria) from {schema}.seg_via_rodov
	)),
segmentos as (select count(*) from (select distinct identificador from {schema}.seg_via_rodov svf, inexistentes i where st_contains(svf.geometria, i.geom))),
linhas_duplicadas as (
	select count(cf1.*) from {schema}.seg_via_rodov cf1, {schema}.seg_via_rodov cf2
		where cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) and cf1.valor_posicao_vertical_transportes = cf2.valor_posicao_vertical_transportes
			and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) not in ('POINT' , 'MULTIPOINT')),
total as (select count(*) from (select distinct identificador from {schema}.seg_via_rodov svf, all_intersecoes i where st_contains(svf.geometria, i.geom))),
good as (select count(*) from (select distinct identificador from {schema}.seg_via_rodov svf, existentes i where st_contains(svf.geometria, i.geom))),
bad as (select segmentos.count + linhas_duplicadas.count as count
	from segmentos, linhas_duplicadas)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
ok_intersecoes as (select (st_dump(st_intersection(cf1.geometria, cf2.geometria))).*
	from {schema}.seg_via_rodov cf1, {schema}.seg_via_rodov cf2
	where cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) and cf1.valor_posicao_vertical_transportes = cf2.valor_posicao_vertical_transportes
	and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) in ('POINT' , 'MULTIPOINT')),
linhas_duplicadas as (
select cf1.*
from {schema}.seg_via_rodov cf1, {schema}.seg_via_rodov cf2
where cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) and cf1.valor_posicao_vertical_transportes = cf2.valor_posicao_vertical_transportes 
and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) not in ('POINT' , 'MULTIPOINT')),
inexistentes as (
	select * from 
	ok_intersecoes where geom not in (
		select st_startpoint(geometria) from {schema}.seg_via_rodov
		union
		select st_endpoint(geometria) from {schema}.seg_via_rodov
	)),
segmentos as (select svf.* from {schema}.seg_via_rodov svf, inexistentes i where st_contains(svf.geometria, i.geom) )
select * from segmentos union select * from linhas_duplicadas$$ );


delete from validation.rules_area where code = 're5_5_2';
insert into validation.rules_area ( code, name, rule, scope, entity, query, report ) 
values ('re5_5_2', 'Interrupção da via rodoviária', 
$$O “Segmento da via-férrea” é interrompido quando:
 - Existe uma interceção com outro “Segmento da via-férrea”;
 - Existe uma alteração do valor de qualquer um dos atributos que
caracteriza o “Segmento da via-férrea”;
 - Existe uma interceção com um “Segmento da via rodoviária” e que
seja efetivamente uma “Passagem de nível” (#2
valorTipoNoTransFerrov e #2 valorTipoNoTransRodov) em estado
“Funcional” (#5 valorEstadoLinhaFerrea);
 - Existe um “Nó de transporte ferroviário” correspondente à existência
de uma “Infraestrutura de transporte ferroviário”.
 - Existe uma mudança do(s) nome(s) da(s) “Linha férrea”.$$, 
$$"“Segmento da via rodoviária”, “Via rodoviária - Limite”, “Segmento da via-
férrea”, “Nó de transporte rodoviário” e “Infraestrutura de transporte
rodoviário”".$$, 'seg_via_rodov',
$$with 
all_intersecoes as (select (st_dump(st_intersection(cf1.geometria, cf2.geometria))).*
	from {schema}.seg_via_rodov cf1, {schema}.seg_via_rodov cf2
	where cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) and cf1.valor_posicao_vertical_transportes = cf2.valor_posicao_vertical_transportes),
ok_intersecoes as (select (st_dump(st_intersection(cf1.geometria, cf2.geometria))).*
	from {schema}.seg_via_rodov cf1, {schema}.seg_via_rodov cf2
	where ST_Intersects(cf1.geometria, '%1$s'::geometry) and cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) and cf1.valor_posicao_vertical_transportes = cf2.valor_posicao_vertical_transportes
	and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) in ('POINT' , 'MULTIPOINT')),
existentes as (
	select * from ok_intersecoes where geom in (
		select st_startpoint(geometria) from {schema}.seg_via_rodov
		union
		select st_endpoint(geometria) from {schema}.seg_via_rodov
	)
),
inexistentes as (
	select * from 
	ok_intersecoes where geom not in (
		select st_startpoint(geometria) from {schema}.seg_via_rodov
		union
		select st_endpoint(geometria) from {schema}.seg_via_rodov
	)),
segmentos as (select count(*) from (select distinct identificador from {schema}.seg_via_rodov svf, inexistentes i where ST_Intersects(svf.geometria, '%1$s'::geometry) and  st_contains(svf.geometria, i.geom))),
linhas_duplicadas as (
	select count(cf1.*) from {schema}.seg_via_rodov cf1, {schema}.seg_via_rodov cf2
		where ST_Intersects(cf1.geometria, '%1$s'::geometry) and cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) and cf1.valor_posicao_vertical_transportes = cf2.valor_posicao_vertical_transportes
			and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) not in ('POINT' , 'MULTIPOINT')),
total as (select count(*) from (select distinct identificador from {schema}.seg_via_rodov svf, all_intersecoes i where st_contains(svf.geometria, i.geom))),
good as (select count(*) from (select distinct identificador from {schema}.seg_via_rodov svf, existentes i where st_contains(svf.geometria, i.geom))),
bad as (select segmentos.count + linhas_duplicadas.count as count
	from segmentos, linhas_duplicadas)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
ok_intersecoes as (select (st_dump(st_intersection(cf1.geometria, cf2.geometria))).*
	from {schema}.seg_via_rodov cf1, {schema}.seg_via_rodov cf2
	where ST_Intersects(cf1.geometria, '%1$s'::geometry) and cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) and cf1.valor_posicao_vertical_transportes = cf2.valor_posicao_vertical_transportes
	and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) in ('POINT' , 'MULTIPOINT')),
linhas_duplicadas as (
select cf1.*
from {schema}.seg_via_rodov cf1, {schema}.seg_via_rodov cf2
where ST_Intersects(cf1.geometria, '%1$s'::geometry) and cf1.identificador != cf2.identificador and st_intersects(cf1.geometria, cf2.geometria) and cf1.valor_posicao_vertical_transportes = cf2.valor_posicao_vertical_transportes 
and geometrytype(st_intersection(cf1.geometria, cf2.geometria)) not in ('POINT' , 'MULTIPOINT')),
inexistentes as (
	select * from 
	ok_intersecoes where geom not in (
		select st_startpoint(geometria) from {schema}.seg_via_rodov
		union
		select st_endpoint(geometria) from {schema}.seg_via_rodov
	)),
segmentos as (select svf.* from {schema}.seg_via_rodov svf, inexistentes i where st_contains(svf.geometria, i.geom) )
select * from segmentos union select * from linhas_duplicadas$$ );


-- RE5.5.3
-- Regras semelhantes: re4_9_1, re5_2_3, re5_5_3
delete from validation.rules where code = 're5_5_3_1';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_5_3_1', 'Conexão entre segmentos e nós da via rodoviária (Parte 1)', 
$$Um "Segmento da via rodoviária" conecta obrigatoriamente com dois objetos
"Nó de transporte rodoviário".$$, 
$$"Segmento da via rodoviária" e "Nó de transporte rodoviário".$$, 'seg_via_rodov',
$$with 
total as (select count(*) from {schema}.seg_via_rodov),
good as (select count(svr.*)
	from {schema}.seg_via_rodov svr, validation.area_trabalho_multi adt
	where (ST_StartPoint(svr.geometria) in (select geometria from {schema}.no_trans_rodov) and ST_EndPoint(svr.geometria) in (select geometria from {schema}.no_trans_rodov))
		or st_intersects(svr.geometria, ST_ExteriorRing(adt.geometria))
),
bad as (select count(svr.*)
	from {schema}.seg_via_rodov svr, validation.area_trabalho_multi adt
	where (ST_StartPoint(svr.geometria) not in (select geometria from {schema}.no_trans_rodov) or ST_EndPoint(svr.geometria) not in (select geometria from {schema}.no_trans_rodov))
		and st_intersects(svr.geometria, ST_ExteriorRing(adt.geometria)) is not true
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$with 
total as (select count(*) from {schema}.seg_via_rodov),
good as (select count(svr.*)
	from {schema}.seg_via_rodov svr, validation.area_trabalho_multi adt
	where (ST_StartPoint(svr.geometria) in (select geometria from {schema}.no_trans_rodov) and ST_EndPoint(svr.geometria) in (select geometria from {schema}.no_trans_rodov))
		or st_intersects(svr.geometria, ST_ExteriorRing(adt.geometria))
),
bad as (select count(svr.*)
	from {schema}.seg_via_rodov svr, validation.area_trabalho_multi adt
	where (ST_StartPoint(svr.geometria) not in (select geometria from {schema}.no_trans_rodov) or ST_EndPoint(svr.geometria) not in (select geometria from {schema}.no_trans_rodov))
		and st_intersects(svr.geometria, ST_ExteriorRing(adt.geometria)) is not true
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$select svr.*
	from {schema}.seg_via_rodov svr, validation.area_trabalho_multi adt
	where (ST_StartPoint(svr.geometria) not in (select geometria from {schema}.no_trans_rodov) or ST_EndPoint(svr.geometria) not in (select geometria from {schema}.no_trans_rodov))
		and st_intersects(svr.geometria, ST_ExteriorRing(adt.geometria)) is not true$$ );

delete from validation.rules_area where code = 're5_5_3_1';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_5_3_1', 'Conexão entre segmentos e nós da via rodoviária (Parte 1)', 
$$Um "Segmento da via rodoviária" conecta obrigatoriamente com dois objetos
"Nó de transporte rodoviário".$$, 
$$"Segmento da via rodoviária" e "Nó de transporte rodoviário".$$, 'seg_via_rodov',
$$with 
total as (select count(*) from {schema}.seg_via_rodov),
good as (select count(svr.*)
	from {schema}.seg_via_rodov svr, validation.area_trabalho_multi adt
	where ST_Intersects(svr.geometria, '%1$s'::geometry) and ((ST_StartPoint(svr.geometria) in (select geometria from {schema}.no_trans_rodov) and ST_EndPoint(svr.geometria) in (select geometria from {schema}.no_trans_rodov))
		or st_intersects(svr.geometria, ST_ExteriorRing(adt.geometria)))
),
bad as (select count(svr.*)
	from {schema}.seg_via_rodov svr, validation.area_trabalho_multi adt
	where ST_Intersects(svr.geometria, '%1$s'::geometry) and ((ST_StartPoint(svr.geometria) not in (select geometria from {schema}.no_trans_rodov) or ST_EndPoint(svr.geometria) not in (select geometria from {schema}.no_trans_rodov))
		and st_intersects(svr.geometria, ST_ExteriorRing(adt.geometria)) is not true)
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$with 
total as (select count(*) from {schema}.seg_via_rodov),
good as (select count(svr.*)
	from {schema}.seg_via_rodov svr, validation.area_trabalho_multi adt
	where ST_Intersects(svr.geometria, '%1$s'::geometry) and ((ST_StartPoint(svr.geometria) in (select geometria from {schema}.no_trans_rodov) and ST_EndPoint(svr.geometria) in (select geometria from {schema}.no_trans_rodov))
		or st_intersects(svr.geometria, ST_ExteriorRing(adt.geometria)))
),
bad as (select count(svr.*)
	from {schema}.seg_via_rodov svr, validation.area_trabalho_multi adt
	where ST_Intersects(svr.geometria, '%1$s'::geometry) and ((ST_StartPoint(svr.geometria) not in (select geometria from {schema}.no_trans_rodov) or ST_EndPoint(svr.geometria) not in (select geometria from {schema}.no_trans_rodov))
		and st_intersects(svr.geometria, ST_ExteriorRing(adt.geometria)) is not true)
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$select svr.*
	from {schema}.seg_via_rodov svr, validation.area_trabalho_multi adt
	where ST_Intersects(svr.geometria, '%1$s'::geometry) and ((ST_StartPoint(svr.geometria) not in (select geometria from {schema}.no_trans_rodov) or ST_EndPoint(svr.geometria) not in (select geometria from {schema}.no_trans_rodov))
		and st_intersects(svr.geometria, ST_ExteriorRing(adt.geometria)) is not true)$$ );


delete from validation.rules where code = 're5_5_3_2';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_5_3_2', 'Conexão entre segmentos e nós da via rodoviária (Parte 2)', 
$$Um "Nó de transporte rodoviário" conecta obrigatoriamente com pelo menos
um "Segmento da via rodoviária".$$, 
$$"Segmento da via rodoviária" e "Nó de transporte rodoviário".$$, 'no_trans_rodov',
$$with 
total as (select count(*) from {schema}.no_trans_rodov),
good as (select count(*) 
	from {schema}.no_trans_rodov
	where geometria in (
	select ST_StartPoint(geometria) from {schema}.seg_via_rodov
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_rodov)),
bad as (select count(*) 
	from {schema}.no_trans_rodov
	where geometria not in (
	select ST_StartPoint(geometria) from {schema}.seg_via_rodov
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_rodov))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.no_trans_rodov),
good as (select count(*) 
	from {schema}.no_trans_rodov
	where geometria in (
	select ST_StartPoint(geometria) from {schema}.seg_via_rodov
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_rodov)),
bad as (select count(*) 
	from {schema}.no_trans_rodov
	where geometria not in (
	select ST_StartPoint(geometria) from {schema}.seg_via_rodov
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_rodov))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$ select *
	from {schema}.no_trans_rodov
	where geometria not in (
	select ST_StartPoint(geometria) from {schema}.seg_via_rodov
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_rodov)$$ );

delete from validation.rules_area where code = 're5_5_3_2';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_5_3_2', 'Conexão entre segmentos e nós da via rodoviária (Parte 2)', 
$$Um "Nó de transporte rodoviário" conecta obrigatoriamente com pelo menos
um "Segmento da via rodoviária".$$, 
$$"Segmento da via rodoviária" e "Nó de transporte rodoviário".$$, 'no_trans_rodov',
$$with 
total as (select count(*) from {schema}.no_trans_rodov),
good as (select count(*) 
	from {schema}.no_trans_rodov
	where ST_Intersects(geometria, '%1$s'::geometry) and geometria in (
	select ST_StartPoint(geometria) from {schema}.seg_via_rodov
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_rodov)),
bad as (select count(*) 
	from {schema}.no_trans_rodov
	where ST_Intersects(geometria, '%1$s'::geometry) and geometria not in (
	select ST_StartPoint(geometria) from {schema}.seg_via_rodov
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_rodov))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.no_trans_rodov),
good as (select count(*) 
	from {schema}.no_trans_rodov
	where ST_Intersects(geometria, '%1$s'::geometry) and geometria in (
	select ST_StartPoint(geometria) from {schema}.seg_via_rodov
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_rodov)),
bad as (select count(*) 
	from {schema}.no_trans_rodov
	where ST_Intersects(geometria, '%1$s'::geometry) and geometria not in (
	select ST_StartPoint(geometria) from {schema}.seg_via_rodov
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_rodov))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$ select *
	from {schema}.no_trans_rodov
	where ST_Intersects(geometria, '%1$s'::geometry) and geometria not in (
	select ST_StartPoint(geometria) from {schema}.seg_via_rodov
	union
	select ST_EndPoint(geometria) from {schema}.seg_via_rodov)$$ );


-- RE5.5.4
delete from validation.rules where code = 're5_5_4';
insert into validation.rules ( code, name, rule, scope, entity, query, report ) 
values ('re5_5_4', 'Nós terminais da via rodoviária', 
$$Quando um “Segmento da via rodoviária” tem o seu fim numa “Infraestrutura de transporte rodoviário” é colocado um “Nó de transporte rodoviário” 
correspondente ao fim da via e um outro “Nó de transporte rodoviário” correspondente à infraestrutura. 
Os nós são colocados nas mesmas coordenadas (mesma localização) no “Segmento da via rodoviária” em conformidade com a topologia implícita.$$, 
$$"“Segmento da via rodoviária”, “Infraestrutura de transporte rodoviário” e “Nó de transporte rodoviário”".$$, 'no_trans_rodov',
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.seg_via_rodov l1
		join {schema}.infra_trans_rodov l2 on st_intersects(ST_StartPoint(l1.geometria), l2.geometria) or st_intersects(ST_EndPoint(l1.geometria), l2.geometria)
		group by st_intersection(l1.geometria, l2.geometria)
), total as (
	select count(*) from inter
), good as (
	select count(*) from inter where (select count(*) from {schema}.no_trans_rodov where geom=geometria) = 2
), bad as (
	select count(*) from inter where (select count(*) from {schema}.no_trans_rodov where geom=geometria) <> 2
) select total.count as total, good.count as good, bad.count as bad from total, good, bad$$,
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.seg_via_rodov l1
		join {schema}.infra_trans_rodov l2 on st_intersects(l1.geometria, l2.geometria)
		group by st_intersection(l1.geometria, l2.geometria)
) select * from {schema}.no_trans_rodov where geometria in (select geom from inter where (select count(*) from {schema}.no_trans_rodov where geom=geometria) <> 2)$$ );


delete from validation.rules_area where code = 're5_5_4';
insert into validation.rules_area ( code, name, rule, scope, entity, query, report ) 
values ('re5_5_4', 'Nós terminais da via rodoviária', 
$$Quando um “Segmento da via rodoviária” tem o seu fim numa “Infraestrutura de transporte rodoviário” é colocado um “Nó de transporte rodoviário” 
correspondente ao fim da via e um outro “Nó de transporte rodoviário” correspondente à infraestrutura. 
Os nós são colocados nas mesmas coordenadas (mesma localização) no “Segmento da via rodoviária” em conformidade com a topologia implícita.$$, 
$$"“Segmento da via rodoviária”, “Infraestrutura de transporte rodoviário” e “Nó de transporte rodoviário”".$$, 'no_trans_rodov',
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.seg_via_rodov l1
		join {schema}.infra_trans_rodov l2 on st_intersects(ST_StartPoint(l1.geometria), l2.geometria) or st_intersects(ST_EndPoint(l1.geometria), l2.geometria)
		group by st_intersection(l1.geometria, l2.geometria)
), total as (
	select count(*) from inter
), good as (
	select count(*) from inter where ST_Intersects(geom, '%1$s') and (select count(*) from {schema}.no_trans_rodov where geom=geometria) = 2
), bad as (
	select count(*) from inter where ST_Intersects(geom, '%1$s') and (select count(*) from {schema}.no_trans_rodov where geom=geometria) <> 2
) select total.count as total, good.count as good, bad.count as bad from total, good, bad$$,
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.seg_via_rodov l1
		join {schema}.infra_trans_rodov l2 on st_intersects(l1.geometria, l2.geometria)
		group by st_intersection(l1.geometria, l2.geometria)
) select * from {schema}.no_trans_rodov where ST_Intersects(geom, '%1$s') and geometria in (select geom from inter where (select count(*) from {schema}.no_trans_rodov where geom=geometria) <> 2)$$ );


-- RE5.5.5
delete from validation.rules where code = 're5_5_5';
insert into validation.rules ( code, name, rule, scope, entity, query, report ) 
values ('re5_5_5', 'Hierarquia dos nós da via rodoviária', 
$$Quando um “Segmento da via rodoviária” interseta outro e, simultaneamente, observa-se uma alteração de atributos, o “Nó de transporte
rodoviário” assume o valor “Junção” (#1 valorTipoNoTransRodov). Apenas é inserido um nó que assume o valor “Junção” ” (#1 valorTipoNoTransRodov)
prevalecendo este sobre o valor “Pseudo-nó ” (#3 valorTipoNoTransRodov).$$, 
$$"“Segmento da via rodoviária” e “Nó de transporte rodoviário”".$$, 'no_trans_rodov',
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.seg_via_rodov l1
		join {schema}.seg_via_rodov l2 on l1.identificador <> l2.identificador and l1.valor_posicao_vertical_transportes = l2.valor_posicao_vertical_transportes
			and (st_intersects(ST_StartPoint(l1.geometria), l2.geometria) or st_intersects(ST_EndPoint(l1.geometria), l2.geometria))
		group by st_intersection(l1.geometria, l2.geometria)
),
total as (
	select count(*) from {schema}.no_trans_rodov n1 where geometria in (select geom from inter where count > 2)
),
good as (
	select count(*) from {schema}.no_trans_rodov n1
	where valor_tipo_no_trans_rodov = '1' and geometria in (select geom from inter where count > 2)
		and geometria not in (select geometria from {schema}.no_trans_rodov n2 where n1.identificador <> n2.identificador)
),
bad as (
	select count(*) from {schema}.no_trans_rodov n1
	where geometria in (select geom from inter where count > 2)
		and (valor_tipo_no_trans_rodov <> '1' or geometria in (select geometria from {schema}.no_trans_rodov n2 where n1.identificador <> n2.identificador))
) select total.count as total, good.count as good, bad.count as bad from total, good, bad$$,
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.seg_via_rodov l1
		join {schema}.seg_via_rodov l2 on l1.identificador <> l2.identificador and l1.valor_posicao_vertical_transportes = l2.valor_posicao_vertical_transportes
			and (st_intersects(ST_StartPoint(l1.geometria), l2.geometria) or st_intersects(ST_EndPoint(l1.geometria), l2.geometria))
		group by st_intersection(l1.geometria, l2.geometria)
)select * from {schema}.no_trans_rodov n1
	where geometria in (select geom from inter where count > 2)
		and (valor_tipo_no_trans_rodov <> '1' or geometria in (select geometria from {schema}.no_trans_rodov n2 where n1.identificador <> n2.identificador))$$ );


delete from validation.rules_area where code = 're5_5_5';
insert into validation.rules_area ( code, name, rule, scope, entity, query, report ) 
values ('re5_5_5', 'Hierarquia dos nós da via rodoviária', 
$$Quando um “Segmento da via rodoviária” interseta outro e, simultaneamente, observa-se uma alteração de atributos, o “Nó de transporte
rodoviário” assume o valor “Junção” (#1 valorTipoNoTransRodov). Apenas é inserido um nó que assume o valor “Junção” ” (#1 valorTipoNoTransRodov)
prevalecendo este sobre o valor “Pseudo-nó ” (#3 valorTipoNoTransRodov).$$, 
$$"“Segmento da via rodoviária” e “Nó de transporte rodoviário”".$$, 'no_trans_rodov',
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.seg_via_rodov l1
		join {schema}.seg_via_rodov l2 on l1.identificador <> l2.identificador and l1.valor_posicao_vertical_transportes = l2.valor_posicao_vertical_transportes
			and (st_intersects(ST_StartPoint(l1.geometria), l2.geometria) or st_intersects(ST_EndPoint(l1.geometria), l2.geometria))
		group by st_intersection(l1.geometria, l2.geometria)
),
total as (
	select count(*) from {schema}.no_trans_rodov n1 where geometria in (select geom from inter where count > 2)
),
good as (
	select count(*) from {schema}.no_trans_rodov n1
	where ST_Intersects(n1.geometria, '%1$s') and valor_tipo_no_trans_rodov = '1' and geometria in (select geom from inter where count > 2)
		and geometria not in (select geometria from {schema}.no_trans_rodov n2 where n1.identificador <> n2.identificador)
),
bad as (
	select count(*) from {schema}.no_trans_rodov n1
	where ST_Intersects(n1.geometria, '%1$s') and geometria in (select geom from inter where count > 2)
		and (valor_tipo_no_trans_rodov <> '1' or geometria in (select geometria from {schema}.no_trans_rodov n2 where n1.identificador <> n2.identificador))
) select total.count as total, good.count as good, bad.count as bad from total, good, bad$$,
$$with inter as (
	select st_intersection(l1.geometria, l2.geometria) as geom, count(*) from {schema}.seg_via_rodov l1
		join {schema}.seg_via_rodov l2 on l1.identificador <> l2.identificador and l1.valor_posicao_vertical_transportes = l2.valor_posicao_vertical_transportes
			and (st_intersects(ST_StartPoint(l1.geometria), l2.geometria) or st_intersects(ST_EndPoint(l1.geometria), l2.geometria))
		group by st_intersection(l1.geometria, l2.geometria)
)select * from {schema}.no_trans_rodov n1
	where ST_Intersects(n1.geometria, '%1$s') and geometria in (select geom from inter where count > 2)
		and (valor_tipo_no_trans_rodov <> '1' or geometria in (select geometria from {schema}.no_trans_rodov n2 where n1.identificador <> n2.identificador))$$ );


-- RE5.5.7
-- Regras semelhantes: re5_1_1, re_5_2_6, re_5_5_7
-- Esta regra é garantida pelo modelo de dados
delete from validation.rules where code = 're5_5_7';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_5_7', 'Caracterização das áreas da infraestrutura de transporte rodoviário', 
$$Cada área ou eventualmente um conjunto de áreas que caracterizam uma
"Área da infraestrutura de transporte rodoviário" relacionam-se com um
ponto (representado no interior de uma das áreas, se possível) que
corresponde a uma "Infraestrutura de transporte rodoviário".$$, 
$$"Área da infraestrutura de transporte rodoviário" e "Infraestrutura de
transporte rodoviário".$$, 'area_infra_trans_rodov',
$$with 
total as (select count(*) from {schema}.area_infra_trans_rodov),
good as (select count(*) from {schema}.area_infra_trans_rodov where infra_trans_rodov_id is not NULL),
bad as (select count(*) from {schema}.area_infra_trans_rodov where infra_trans_rodov_id is NULL)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.area_infra_trans_rodov),
good as (select count(*) from {schema}.area_infra_trans_rodov where infra_trans_rodov_id is not NULL),
bad as (select count(*) from {schema}.area_infra_trans_rodov where infra_trans_rodov_id is NULL)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select * from {schema}.area_infra_trans_rodov where infra_trans_rodov_id is null $$ );

delete from validation.rules_area where code = 're5_5_7';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_5_7', 'Caracterização das áreas da infraestrutura de transporte rodoviário', 
$$Cada área ou eventualmente um conjunto de áreas que caracterizam uma
"Área da infraestrutura de transporte rodoviário" relacionam-se com um
ponto (representado no interior de uma das áreas, se possível) que
corresponde a uma "Infraestrutura de transporte rodoviário".$$, 
$$"Área da infraestrutura de transporte rodoviário" e "Infraestrutura de
transporte rodoviário".$$, 'area_infra_trans_rodov',
$$with 
total as (select count(*) from {schema}.area_infra_trans_rodov),
good as (select count(*) from {schema}.area_infra_trans_rodov where ST_Intersects(geometria, '%1$s'::geometry) and infra_trans_rodov_id is not NULL),
bad as (select count(*) from {schema}.area_infra_trans_rodov where ST_Intersects(geometria, '%1$s'::geometry) and infra_trans_rodov_id is NULL)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$with 
total as (select count(*) from {schema}.area_infra_trans_rodov),
good as (select count(*) from {schema}.area_infra_trans_rodov where ST_Intersects(geometria, '%1$s'::geometry) and infra_trans_rodov_id is not NULL),
bad as (select count(*) from {schema}.area_infra_trans_rodov where ST_Intersects(geometria, '%1$s'::geometry) and infra_trans_rodov_id is NULL)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad $$,
$$select * from {schema}.area_infra_trans_rodov where ST_Intersects(geometria, '%1$s'::geometry) and infra_trans_rodov_id is null $$ );


delete from validation.rules where code = 're5_5_8';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_5_8', 'Representação da infraestrutura de transporte rodoviário', 
$$Se a "Área da infraestrutura de transporte rodoviário" não possuir dimensões
para ser representada (RG2) a "Infraestrutura de transporte rodoviário" é
sempre representada através da colocação de um ponto no centro do
fenómeno a que diz respeito.$$, 
$$"Área da infraestrutura de transporte rodoviário" e "Infraestrutura de
transporte rodoviário".$$, 'infra_trans_rodov',
$$with 
total as (select * from {schema}.infra_trans_rodov itr
where not exists (select * from {schema}.area_infra_trans_rodov aitr  where st_contains(aitr.geometria,itr.geometria ))),
good as (select * from {schema}.infra_trans_rodov itr
where not exists (select * from {schema}.area_infra_trans_rodov aitr  where st_contains(aitr.geometria,itr.geometria )))
select total.count as total, good.count as good, 0 as bad
from total, good $$,
$$with 
total as (select * from {schema}.infra_trans_rodov itr
where not exists (select * from {schema}.area_infra_trans_rodov aitr  where st_contains(aitr.geometria,itr.geometria ))),
good as (select * from {schema}.infra_trans_rodov itr
where not exists (select * from {schema}.area_infra_trans_rodov aitr  where st_contains(aitr.geometria,itr.geometria )))
select total.count as total, good.count as good, 0 as bad
from total, good $$,
$$ select * from {schema}.infra_trans_rodov where false $$ );

delete from validation.rules_area where code = 're5_5_8';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_5_8', 'Representação da infraestrutura de transporte rodoviário', 
$$Se a "Área da infraestrutura de transporte rodoviário" não possuir dimensões
para ser representada (RG2) a "Infraestrutura de transporte rodoviário" é
sempre representada através da colocação de um ponto no centro do
fenómeno a que diz respeito.$$, 
$$"Área da infraestrutura de transporte rodoviário" e "Infraestrutura de
transporte rodoviário".$$, 'infra_trans_rodov',
$$with 
total as (select * from {schema}.infra_trans_rodov itr
where not exists (select * from {schema}.area_infra_trans_rodov aitr  where st_contains(aitr.geometria,itr.geometria ))),
good as (select * from {schema}.infra_trans_rodov itr
where ST_Intersects(geometria, '%1$s'::geometry) and not exists (select * from {schema}.area_infra_trans_rodov aitr  where st_contains(aitr.geometria,itr.geometria )))
select total.count as total, good.count as good, 0 as bad
from total, good $$,
$$with 
total as (select * from {schema}.infra_trans_rodov itr
where not exists (select * from {schema}.area_infra_trans_rodov aitr  where st_contains(aitr.geometria,itr.geometria ))),
good as (select * from {schema}.infra_trans_rodov itr
where ST_Intersects(geometria, '%1$s'::geometry) and not exists (select * from {schema}.area_infra_trans_rodov aitr  where st_contains(aitr.geometria,itr.geometria )))
select total.count as total, good.count as good, 0 as bad
from total, good $$,
$$ select * from {schema}.infra_trans_rodov where false $$ );


delete from validation.rules where code = 're5_5_9';
insert into validation.rules ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_5_9', 'Nó da infraestrutura rodoviária', 
$$Cada "Infraestrutura de transporte rodoviário" tem obrigatoriamente
associada um "Nó de transporte rodoviário" do tipo "Infraestrutura" (#5
valorTipoNoTransRodov).
O nó é colocado no "Segmento da via rodoviária" em conformidade com a
topologia implícita e no ponto mais próximo da "Infraestrutura de transporte
rodoviário" (Figura 45).$$, 
$$"Segmento da via rodoviária", "Infraestrutura de transporte rodoviário" e "Nó
de transporte rodoviário".$$, 'infra_trans_rodov',
$$with
total as (select count(*) from {schema}.infra_trans_rodov),
good as (select count(*) from {schema}.infra_trans_rodov where identificador in (
	select infra_trans_rodov_id from {schema}.lig_infratransrodov_notransrodov lin 
		inner join {schema}.no_trans_rodov ntr on lin.no_trans_rodov_id=ntr.identificador
	where ntr.valor_tipo_no_trans_rodov = '5')
),
bad as (select count(*) from {schema}.infra_trans_rodov where identificador not in (
	select infra_trans_rodov_id from {schema}.lig_infratransrodov_notransrodov lin 
		inner join {schema}.no_trans_rodov ntr on lin.no_trans_rodov_id=ntr.identificador
	where ntr.valor_tipo_no_trans_rodov = '5')
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$with
total as (select count(*) from {schema}.infra_trans_rodov),
good as (select count(*) from {schema}.infra_trans_rodov where identificador in (
	select infra_trans_rodov_id from {schema}.lig_infratransrodov_notransrodov lin 
		inner join {schema}.no_trans_rodov ntr on lin.no_trans_rodov_id=ntr.identificador
	where ntr.valor_tipo_no_trans_rodov = '5')
),
bad as (select count(*) from {schema}.infra_trans_rodov where identificador not in (
	select infra_trans_rodov_id from {schema}.lig_infratransrodov_notransrodov lin 
		inner join {schema}.no_trans_rodov ntr on lin.no_trans_rodov_id=ntr.identificador
	where ntr.valor_tipo_no_trans_rodov = '5')
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$select * from {schema}.infra_trans_rodov where identificador not in (
	select infra_trans_rodov_id from {schema}.lig_infratransrodov_notransrodov lin 
		inner join {schema}.no_trans_rodov ntr on lin.no_trans_rodov_id=ntr.identificador
	where ntr.valor_tipo_no_trans_rodov = '5')$$ );

delete from validation.rules_area where code = 're5_5_9';
insert into validation.rules_area ( code, name, rule, scope, entity,  query, query_nd2, report ) 
values ('re5_5_9', 'Nó da infraestrutura rodoviária', 
$$Cada "Infraestrutura de transporte rodoviário" tem obrigatoriamente
associada um "Nó de transporte rodoviário" do tipo "Infraestrutura" (#5
valorTipoNoTransRodov).
O nó é colocado no "Segmento da via rodoviária" em conformidade com a
topologia implícita e no ponto mais próximo da "Infraestrutura de transporte
rodoviário" (Figura 45).$$, 
$$"Segmento da via rodoviária", "Infraestrutura de transporte rodoviário" e "Nó
de transporte rodoviário".$$, 'infra_trans_rodov',
$$with
total as (select count(*) from {schema}.infra_trans_rodov),
good as (select count(*) from {schema}.infra_trans_rodov where ST_Intersects(geometria, '%1$s'::geometry) and identificador in (
	select infra_trans_rodov_id from {schema}.lig_infratransrodov_notransrodov lin 
		inner join {schema}.no_trans_rodov ntr on lin.no_trans_rodov_id=ntr.identificador
	where ntr.valor_tipo_no_trans_rodov = '5')
),
bad as (select count(*) from {schema}.infra_trans_rodov where ST_Intersects(geometria, '%1$s'::geometry) and identificador not in (
	select infra_trans_rodov_id from {schema}.lig_infratransrodov_notransrodov lin 
		inner join {schema}.no_trans_rodov ntr on lin.no_trans_rodov_id=ntr.identificador
	where ntr.valor_tipo_no_trans_rodov = '5')
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$with
total as (select count(*) from {schema}.infra_trans_rodov),
good as (select count(*) from {schema}.infra_trans_rodov where ST_Intersects(geometria, '%1$s'::geometry) and identificador in (
	select infra_trans_rodov_id from {schema}.lig_infratransrodov_notransrodov lin 
		inner join {schema}.no_trans_rodov ntr on lin.no_trans_rodov_id=ntr.identificador
	where ntr.valor_tipo_no_trans_rodov = '5')
),
bad as (select count(*) from {schema}.infra_trans_rodov where ST_Intersects(geometria, '%1$s'::geometry) and identificador not in (
	select infra_trans_rodov_id from {schema}.lig_infratransrodov_notransrodov lin 
		inner join {schema}.no_trans_rodov ntr on lin.no_trans_rodov_id=ntr.identificador
	where ntr.valor_tipo_no_trans_rodov = '5')
)
select total.count as total, good.count as good, bad.count as bad
from total, good, bad$$,
$$select * from {schema}.infra_trans_rodov where ST_Intersects(geometria, '%1$s'::geometry) and identificador not in (
	select infra_trans_rodov_id from {schema}.lig_infratransrodov_notransrodov lin 
		inner join {schema}.no_trans_rodov ntr on lin.no_trans_rodov_id=ntr.identificador
	where ntr.valor_tipo_no_trans_rodov = '5')$$ );


delete from validation.rules where code = 're7_1';
insert into validation.rules ( code, name, rule, scope, query, query_nd2 ) 
values ('re7_1', 'Representação da área agrícola, florestal ou mato',
$$A área agrícola, florestal ou mato é recolhida e representada se possuir uma
área igual ou superior a:
 - NdD1: 2 000 m²;
 - NdD2: 5 000 m².$$,
$$Área agrícola, florestal ou mato.$$,
$$select * from validation.rg_min_area ('re7_1', 'area_agricola_florestal_mato', ('%1$s'::json->>'re7_1_ndd1')::int)$$,
$$select * from validation.rg_min_area ('re7_1', 'area_agricola_florestal_mato', ('%1$s'::json->>'re7_1_ndd2')::int)$$ );

delete from validation.rules_area where code = 're7_1';
insert into validation.rules_area ( code, name, rule, scope, query, query_nd2 ) 
values ('re7_1', 'Representação da área agrícola, florestal ou mato',
$$A área agrícola, florestal ou mato é recolhida e representada se possuir uma
área igual ou superior a:
 - NdD1: 2 000 m²;
 - NdD2: 5 000 m².$$,
$$Área agrícola, florestal ou mato.$$,
$$select * from validation.rg_min_area ('re7_1', 'area_agricola_florestal_mato', ('%2$s'::json->>'re7_1_ndd1')::int, '%1$s'::geometry)$$,
$$select * from validation.rg_min_area ('re7_1', 'area_agricola_florestal_mato', ('%2$s'::json->>'re7_1_ndd2')::int, '%1$s'::geometry)$$ );


delete from validation.rules where code = 're7_8';
insert into validation.rules ( code, name, rule, scope, query, query_nd2 ) 
values ('re7_8', 'Representação de parque, jardim e área verde',
$$O parque e jardim e a área verde são recolhidos e representados se possuírem
uma área igual ou superior a:
 - NdD1: 100 m²;
 - NdD2: 1 000 m².$$,
$$Área artificializada.$$,
$$select * from validation.rg_min_area ('re7_8', 'areas_artificializadas', ('%1$s'::json->>'re7_8_ndd1')::int)$$,
$$select * from validation.rg_min_area ('re7_8', 'areas_artificializadas', ('%1$s'::json->>'re7_8_ndd2')::int)$$ );

delete from validation.rules_area where code = 're7_8';
insert into validation.rules_area ( code, name, rule, scope, query, query_nd2 ) 
values ('re7_8', 'Representação de parque, jardim e área verde',
$$O parque e jardim e a área verde são recolhidos e representados se possuírem
uma área igual ou superior a:
 - NdD1: 100 m²;
 - NdD2: 1 000 m².$$,
$$Área artificializada.$$,
$$select * from validation.rg_min_area ('re7_8', 'areas_artificializadas', ('%2$s'::json->>'re7_8_ndd1')::int, '%1$s'::geometry)$$,
$$select * from validation.rg_min_area ('re7_8', 'areas_artificializadas', ('%2$s'::json->>'re7_8_ndd2')::int, '%1$s'::geometry)$$ );


delete from validation.rules where code = 'pq2_1_1';
insert into validation.rules ( code, name, rule, scope, query, query_nd2 )
values ('pq2_1_1', 'Conformidade dos dados',
$$Avalia a conformidade dos objetos ao modelo conceptual e às regras definidas.$$,
$$Todos os dados de todos os temas.$$,
$$select * from validation.pq2_1_1_validation ()$$,
$$select * from validation.pq2_1_1_validation ()$$ );

delete from validation.rules_area where code = 'pq2_1_1';
insert into validation.rules_area ( code, name, rule, scope, query, query_nd2, is_global )
values ('pq2_1_1', 'Conformidade dos dados',
$$Avalia a conformidade dos objetos ao modelo conceptual e às regras definidas.$$,
$$Todos os dados de todos os temas.$$,
$$select * from validation.pq2_1_1_validation ()$$,
$$select * from validation.pq2_1_1_validation ()$$, true );


delete from validation.rules where code = 'pq2_4_1';
insert into validation.rules ( code, name, rule, scope, query, query_nd2 )
values ('pq2_4_1', 'Consistência topológica dos objetos',
$$Avalia a existência erros topológicos nos dados.$$,
$$Todos os objetos com exceção dos objetos do Tema Toponímia.$$,
$$select * from validation.pq2_4_1_validation ()$$,
$$select * from validation.pq2_4_1_validation ()$$ );

delete from validation.rules_area where code = 'pq2_4_1';
insert into validation.rules_area ( code, name, rule, scope, query, query_nd2 )
values ('pq2_4_1', 'Consistência topológica dos objetos',
$$Avalia a existência erros topológicos nos dados.$$,
$$Todos os objetos com exceção dos objetos do Tema Toponímia.$$,
$$select * from validation.pq2_4_1_validation ('%1$s'::geometry)$$,
$$select * from validation.pq2_4_1_validation ('%1$s'::geometry)$$ );


drop table if exists validation.area_trabalho_grid;
create table if not exists validation.area_trabalho_grid as
with grid as (
	select (ST_SquareGrid(10000, geometria)).* from {schema}.area_trabalho
)
select gen_random_uuid() as identificador, geom as geometria from grid;

CREATE INDEX ON validation.area_trabalho_grid USING gist(geometria);

create or replace view validation.rules_area_report_view as (
	with aggr_report as (
		select rule_code, max(total) as total, max(total) - sum(bad) as good, sum(bad) as bad 
		from validation.rules_area_report
		group by rule_code
	)
	select ra.code, ra.name, ra.rule, ra.scope, ra.entity, ra.required, ra.enabled, ra.run, ra.dorder, ra.versoes, ra.is_global, rar.total, rar.good, rar.bad 
	from validation.rules_area ra
	left join aggr_report rar on ra.code=rar.rule_code
);
