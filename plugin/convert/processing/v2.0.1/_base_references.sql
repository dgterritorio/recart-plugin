create or replace function {schema}.insert_references(schem character varying, src_table character varying) returns void
 language plpgsql
as $function$
declare
	refs refcursor;
	rec record;
	ref_fields text;
	fks record;
	ref_v text;
	ref_vals text;
	rid uuid;
	begin
		open refs for execute
				'select identificador, inicio_objeto, geometria, import_ref::json->0->''table'' as table, import_ref::json->0->''fields'' as campos, import_ref::json->0->''connection'' as conn, import_ref::json->0->''attribute'' as cattr, import_ref::json->0->''operation'' as operation from ' || src_table || ' where import_ref is not null';
		fetch next from refs into rec;
		while (found) loop
			ref_fields = 'inicio_objeto';
			ref_vals = '''' || rec.inicio_objeto::text || '''';
			for fks in select json_object_keys(rec.campos::json)
			loop
				ref_fields = ref_fields  || ',' || regexp_replace(fks::text, '[()]', '', 'g');
				ref_v = rec.campos::json->(regexp_replace(fks::text, '[()]', '', 'g'));
				ref_vals = ref_vals || ',"' || regexp_replace(ref_v, '[\[\]"]', '', 'g') || '"';
			end loop;

			if rec."operation" is not null then
				ref_fields = ref_fields || ', geometria';
				case rec."operation"::text
					when '"centroid"' then
						ref_vals = ref_vals || ',' || '''' || ST_AsEWKT(ST_Centroid(rec."geometria")) || '''';
					else
						ref_vals = ref_vals || ',' || '''' || ST_AsEWKT(rec."geometria") || '''';
					end case;
			end if;

			--raise notice '%', (format('insert into %1$I.%2$s(%3$s) values (%4$s)', schem, rec."table", ref_fields, regexp_replace(ref_vals, '"', '''', 'g')));
			execute format('insert into %1$I.%2$s(%3$s) values (%4$s) returning identificador', schem, rec."table", ref_fields, regexp_replace(ref_vals, '"', '''', 'g'))
			into rid;

			if rec."conn" is not null then
				--raise notice '%', (format('insert into %1$I.%2$s(%3$s) values (%4$s)', schem, rec."conn", split_part(src_table, '.', 2)||'_id' || ', ' || regexp_replace((rec."table")::text, '"', '', 'g') || '_id', rec.identificador || ', ' || rid));
				execute format('insert into %1$I.%2$s(%3$s) values (%4$s)', schem, rec."conn", split_part(src_table, '.', 2)||'_id' || ', ' || regexp_replace((rec."table")::text, '"', '', 'g') || '_id', '''' || rec.identificador || ''', ''' || rid || '''');
			end if;

			if rec."cattr" is not null then
				--raise notice '%', (format('update %1$s set %2$s = %3$s where identificador=%4$s', src_table, rec."cattr", '''' || rid || '''', '''' || rec.identificador || ''''));
				execute format('update %1$s set %2$s = %3$s where identificador=%4$s', src_table, rec."cattr", '''' || rid || '''', '''' || rec.identificador || '''');
			end if;

			fetch next from refs into rec;
		end loop;
		close refs;
	end;
$function$
;


CREATE OR REPLACE FUNCTION {schema}.trigger_linestring_polygon_validation()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
if(st_geometrytype(NEW.geometria) like 'ST_LineString' OR st_geometrytype(NEW.geometria) like 'ST_Polygon') then
	RETURN NEW;
end if;
RAISE EXCEPTION 'Invalid geometry type only linestring or polygon are accepted!';
END;
$function$
;


CREATE OR REPLACE FUNCTION {schema}.trigger_point_polygon_validation()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
if(st_geometrytype(NEW.geometria) like 'ST_Point' OR st_geometrytype(NEW.geometria) like 'ST_Polygon') then
	RETURN NEW;
end if;
RAISE EXCEPTION 'Invalid geometry type only point or polygon are accepted!';
END;
$function$
;


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_adm_publica (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_adm_publica_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_adm_publica (identificador, descricao) VALUES
('1', 'Assembleia da República, Assembleia Regional')
, ('2', 'Ministério, Gabinete do Secretário de Estado; Secretária-geral')
, ('3', 'Câmara Municipal, Assembleia Municipal')
, ('4', 'Junta de Freguesia')
, ('5', 'Outro - Administração pública');

CREATE TABLE IF NOT EXISTS {schema}.adm_publica (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NOT NULL,
	ponto_de_contacto varchar(255) NULL,
	valor_tipo_adm_publica varchar(10) NOT NULL,
	CONSTRAINT adm_publica_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.adm_publica ADD CONSTRAINT valor_tipo_adm_publica_id FOREIGN KEY (valor_tipo_adm_publica) REFERENCES {schema}.valor_tipo_adm_publica(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_agua_lentica (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_agua_lentica_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_agua_lentica (identificador, descricao) VALUES
('1', 'Lago ou lagoa')
, ('2', 'Albufeira')
, ('3', 'Charca')
, ('4', 'Charco ou poça');

CREATE TABLE IF NOT EXISTS {schema}.valor_persistencia_hidrologica (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_persistencia_hidrologica_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_persistencia_hidrologica (identificador, descricao) VALUES
('1', 'Seco')
, ('2', 'Efémero')
, ('3', 'Intermitente')
, ('4', 'Perene');

CREATE TABLE IF NOT EXISTS {schema}.agua_lentica (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NULL,
	cota_plena_armazenamento bool NOT NULL,
	data_fonte_dados date NULL,
	mare bool NOT NULL,
	origem_natural bool NULL,
	profundidade_media float4 NULL,
	id_hidrografico varchar(255) NULL,
	valor_agua_lentica varchar(10) NOT NULL,
	valor_persistencia_hidrologica varchar(10) NULL,
	geometria public.geometry(polygonz, 3763) NOT NULL,
	CONSTRAINT agua_lentica_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.agua_lentica ADD CONSTRAINT valor_agua_lentica_id FOREIGN KEY (valor_agua_lentica) REFERENCES {schema}.valor_agua_lentica(identificador);
ALTER TABLE {schema}.agua_lentica ADD CONSTRAINT valor_persistencia_hidrologica_id FOREIGN KEY (valor_persistencia_hidrologica) REFERENCES {schema}.valor_persistencia_hidrologica(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_areas_agricolas_florestais_matos (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_areas_agricolas_florestais_matos_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_areas_agricolas_florestais_matos (identificador, descricao) VALUES
('1', 'Agricultura')
, ('1.1', 'Cultura temporária de sequeiro e regadio'), ('1.2', 'Arrozal'), ('1.3', 'Vinha'), ('1.4', 'Pomar'), ('1.5', 'Olival'), ('1.6', 'Bananal'), ('1.7', 'Misto de culturas permanentes'), ('1.8', 'Outras culturas permanentes')
, ('2', 'Pastagem')
, ('2.1', 'Pastagem permanente'), ('2.2', 'Vegetação herbácea natural')
, ('3', 'Sistema agroflorestal')
, ('4', 'Floresta')
, ('4.1', 'Floresta de folhosas'), ('4.1.1', 'Sobreiro'), ('4.1.2', 'Azinheira'), ('4.1.3', 'Carvalho'), ('4.1.4', 'Castanheiro'), ('4.1.5', 'Eucalipto'), ('4.1.6', 'Espécie invasora'), ('4.1.7', 'Outras folhosas'), ('4.2', 'Floresta de resinosas'), ('4.2.1', 'Pinheiro manso'), ('4.2.2', 'Pinheiro bravo'), ('4.2.3', 'Outras resinosas'), ('4.3', 'Floresta de Laurissilva')
, ('5', 'Mato');

CREATE TABLE IF NOT EXISTS {schema}.area_agricola_florestal_mato (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_areas_agricolas_florestais_matos varchar(10) NOT NULL,
	nome varchar(255) NULL,
	geometria public.geometry(polygon, 3763) NOT NULL,
	CONSTRAINT area_agricola_florestal_mato_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.area_agricola_florestal_mato ADD CONSTRAINT valor_areas_agricolas_florestais_matos_id FOREIGN KEY (valor_areas_agricolas_florestais_matos) REFERENCES {schema}.valor_areas_agricolas_florestais_matos(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_area_infra_trans_aereo (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_area_infra_trans_aereo_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_area_infra_trans_aereo (identificador, descricao) VALUES
('1', 'Área da infraestrutura')
, ('2', 'Área de pista')
, ('3', 'Área de circulação')
, ('4', 'Plataforma de estacionamento');

CREATE TABLE IF NOT EXISTS {schema}.area_infra_trans_aereo (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_tipo_area_infra_trans_aereo varchar(10) NOT NULL,
	geometria public.geometry(polygon, 3763) NOT NULL,
	CONSTRAINT area_infra_trans_aereo_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.area_infra_trans_aereo ADD CONSTRAINT valor_tipo_area_infra_trans_aereo_id FOREIGN KEY (valor_tipo_area_infra_trans_aereo) REFERENCES {schema}.valor_tipo_area_infra_trans_aereo(identificador);


CREATE TABLE IF NOT EXISTS {schema}.area_infra_trans_cabo (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	geometria public.geometry(polygon, 3763) NOT NULL,
	CONSTRAINT area_infra_trans_cabo_pkey PRIMARY KEY (identificador)
);


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_uso_infra_trans_ferrov (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_uso_infra_trans_ferrov_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_uso_infra_trans_ferrov (identificador, descricao) VALUES
('1', 'Passageiros'), ('2', 'Mercadorias'), ('3', 'Misto');

CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_infra_trans_ferrov (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_infra_trans_ferrov_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_infra_trans_ferrov (identificador, descricao) VALUES
('1', 'Local de estação'), ('2', 'Local de apeadeiro');

CREATE TABLE IF NOT EXISTS {schema}.infra_trans_ferrov (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	codigo_infra_ferrov varchar(255) NULL,
	nome varchar(255) NULL,
	nplataformas int4 NULL,
	valor_tipo_uso_infra_trans_ferrov varchar(10) NULL,
	valor_tipo_infra_trans_ferrov varchar(10) NOT NULL,
	geometria public.geometry(point, 3763) NOT NULL,
	CONSTRAINT infra_trans_ferrov_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.infra_trans_ferrov ADD CONSTRAINT valor_tipo_infra_trans_ferrov_id FOREIGN KEY (valor_tipo_infra_trans_ferrov) REFERENCES {schema}.valor_tipo_infra_trans_ferrov(identificador);
ALTER TABLE {schema}.infra_trans_ferrov ADD CONSTRAINT valor_tipo_uso_infra_trans_ferrov_id FOREIGN KEY (valor_tipo_uso_infra_trans_ferrov) REFERENCES {schema}.valor_tipo_uso_infra_trans_ferrov(identificador);


CREATE TABLE IF NOT EXISTS {schema}.area_infra_trans_ferrov (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	infra_trans_ferrov_id uuid NOT NULL,
	geometria public.geometry(polygon, 3763) NOT NULL,
	CONSTRAINT area_infra_trans_ferrov_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.area_infra_trans_ferrov ADD CONSTRAINT area_infra_trans_ferrov FOREIGN KEY (infra_trans_ferrov_id) REFERENCES {schema}.infra_trans_ferrov(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_infra_trans_rodov (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_infra_trans_rodov_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_infra_trans_rodov (identificador, descricao) VALUES
('1', 'Local de paragem')
, ('2', 'Terminal')
, ('3', 'Parqueamento')
, ('4', 'Parque de estacionamento')
, ('5', 'Portagem')
, ('6', 'Área de repouso')
, ('7', 'Área de serviço')
, ('8', 'Posto de abastecimento de combustíveis')
, ('9', 'Praça de táxis');

CREATE TABLE IF NOT EXISTS {schema}.infra_trans_rodov (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NULL,
	valor_tipo_infra_trans_rodov varchar(10) NOT NULL,
	geometria public.geometry(point, 3763) NOT NULL,
	CONSTRAINT infra_trans_rodov_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.infra_trans_rodov ADD CONSTRAINT valor_tipo_infra_trans_rodov_id FOREIGN KEY (valor_tipo_infra_trans_rodov) REFERENCES {schema}.valor_tipo_infra_trans_rodov(identificador);

CREATE TABLE IF NOT EXISTS {schema}.area_infra_trans_rodov (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	infra_trans_rodov_id uuid NOT NULL,
	geometria public.geometry(polygon, 3763) NOT NULL,
	CONSTRAINT area_infra_trans_rodov_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.area_infra_trans_rodov ADD CONSTRAINT area_infra_trans_rodov FOREIGN KEY (infra_trans_rodov_id) REFERENCES {schema}.infra_trans_rodov(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_area_infra_trans_via_navegavel (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_area_infra_trans_via_navegavel_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_area_infra_trans_via_navegavel (identificador, descricao) VALUES
('1', 'Área do porto'), ('2', 'Área do cais'), ('3', 'Área da doca');

CREATE TABLE IF NOT EXISTS {schema}.area_infra_trans_via_navegavel (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_tipo_area_infra_trans_via_navegavel varchar(10) NOT NULL,
	geometria public.geometry(polygon, 3763) NOT NULL,
	CONSTRAINT area_infra_trans_via_navegavel_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.area_infra_trans_via_navegavel ADD CONSTRAINT valor_tipo_area_infra_trans_via_navegavel_id FOREIGN KEY (valor_tipo_area_infra_trans_via_navegavel) REFERENCES {schema}.valor_tipo_area_infra_trans_via_navegavel(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_nivel_de_detalhe (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_nivel_de_detalhe_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_nivel_de_detalhe (identificador, descricao) VALUES
('1', 'NdD1'), ('2', 'NdD2');

CREATE TABLE IF NOT EXISTS {schema}.area_trabalho (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	"data" date NOT NULL,
	data_homologacao date NULL,
	nome varchar(255) NOT NULL,
	nome_proprietario varchar(255) NOT NULL,
	nome_produtor varchar(255) NOT NULL,
	valor_nivel_de_detalhe varchar(10) NOT NULL,
	geometria public.geometry(polygon, 3763) NOT NULL,
	CONSTRAINT area_trabalho_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.area_trabalho ADD CONSTRAINT valor_nivel_de_detalhe_id FOREIGN KEY (valor_nivel_de_detalhe) REFERENCES {schema}.valor_nivel_de_detalhe(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_instalacao_producao (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_instalacao_producao_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_instalacao_producao (identificador, descricao) VALUES
('1', 'Pecuária'), ('1.1', 'Bovinicultura'), ('1.2', 'Suinicultura'), ('1.3', 'Avicultura'), ('1.100', 'Outros - Pecuária')
, ('4', 'Indústria extrativa'), ('4.1', 'Pedreira'), ('4.2', 'Mina'), ('4.4', 'Salina')
, ('5', 'Fábrica')
, ('6', 'Instalação de materiais explosivos')
, ('7', 'Oficina'), ('7.1', 'Oficina em geral'), ('7.2', 'Oficina de pirotecnia'), ('7.3', 'Oficina de reparação ou lavagem automóvel')
, ('8', 'Estaleiro naval')
, ('11', 'Aquicultura')
, ('12', 'Sucata')
, ('13', 'Indústria agroindustrial'), ('13.1', 'Matadouro'), ('13.2', 'Adega'), ('13.3', 'Lagar'), ('13.4', 'Lacticínios'), ('13.5', 'Engenho'), ('13.100', 'Outros - Indústria agroindustrial');

CREATE TABLE IF NOT EXISTS {schema}.inst_producao (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NOT NULL,
	descricao_da_funcao varchar(255) NULL,
	valor_instalacao_producao varchar(10) NOT NULL,
	CONSTRAINT inst_producao_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.inst_producao ADD CONSTRAINT valor_instalacao_producao_id FOREIGN KEY (valor_instalacao_producao) REFERENCES {schema}.valor_instalacao_producao(identificador);

CREATE TABLE IF NOT EXISTS {schema}.valor_instalacao_gestao_ambiental (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_instalacao_gestao_ambiental_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_instalacao_gestao_ambiental (identificador, descricao) VALUES
('1', 'Aterro'), ('1.1', 'Aterro urbano'), ('1.2', 'Aterro industrial')
, ('2', 'ETAR'), ('2.1', 'ETAR urbana'), ('2.2', 'ETAR industrial')
, ('5', 'ETA')
, ('6', 'Instalação de tratamento de resíduos');

CREATE TABLE IF NOT EXISTS {schema}.inst_gestao_ambiental (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NOT NULL,
	valor_instalacao_gestao_ambiental varchar(10) NOT NULL,
	CONSTRAINT inst_gestao_ambiental_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.inst_gestao_ambiental ADD CONSTRAINT valor_instalacao_gestao_ambiental_id FOREIGN KEY (valor_instalacao_gestao_ambiental) REFERENCES {schema}.valor_instalacao_gestao_ambiental(identificador);

CREATE TABLE IF NOT EXISTS {schema}.equip_util_coletiva (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NOT NULL,
	ponto_de_contacto varchar(255) NULL,
	CONSTRAINT equip_util_coletiva_pkey PRIMARY KEY (identificador)
);

CREATE TABLE IF NOT EXISTS {schema}.valor_areas_artificializadas (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_areas_artificializadas_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_areas_artificializadas (identificador, descricao) VALUES
('1', 'Área de equipamentos de saúde')
, ('2', 'Área de equipamentos de educação')
, ('3', 'Área de equipamentos industriais')
, ('4', 'Área de equipamentos comerciais ou de carácter geral')
, ('5', 'Área de deposição de resíduos')
, ('6', 'Área em construção')
, ('7', 'Área de equipamentos desportivos e de lazer')
, ('8', 'Área de parque de campismo')
, ('9', 'Área de inumação')
, ('10', 'Área de equipamentos de segurança e ordem pública, defesa ou justiça')
, ('11', 'Área de instalações agrícolas')
, ('12', 'Área de equipamentos culturais')
, ('13', 'Área de extração de inertes');

CREATE TABLE IF NOT EXISTS {schema}.areas_artificializadas (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	inst_producao_id uuid NULL,
	inst_gestao_ambiental_id uuid NULL,
	equip_util_coletiva_id uuid NULL,
	valor_areas_artificializadas varchar(10) NOT NULL,
	nome varchar(255) NULL,
	geometria public.geometry(polygon, 3763) NOT NULL,
	CONSTRAINT areas_artificializadas_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.areas_artificializadas ADD CONSTRAINT localizacao_equip_util_coletiva FOREIGN KEY (equip_util_coletiva_id) REFERENCES {schema}.equip_util_coletiva(identificador);
ALTER TABLE {schema}.areas_artificializadas ADD CONSTRAINT localizacao_instalacao_ambiental FOREIGN KEY (inst_gestao_ambiental_id) REFERENCES {schema}.inst_gestao_ambiental(identificador);
ALTER TABLE {schema}.areas_artificializadas ADD CONSTRAINT localizacao_instalacao_producao FOREIGN KEY (inst_producao_id) REFERENCES {schema}.inst_producao(identificador);
ALTER TABLE {schema}.areas_artificializadas ADD CONSTRAINT valor_areas_artificializadas_id FOREIGN KEY (valor_areas_artificializadas) REFERENCES {schema}.valor_areas_artificializadas(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_barreira (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_barreira_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_barreira (identificador, descricao) VALUES
('1', 'Comporta')
, ('2', 'Eclusa')
, ('3', 'Barragem de betão')
, ('4', 'Barragem de aterro')
, ('5', 'Açude ou represa')
, ('6', 'Dique');

CREATE TABLE IF NOT EXISTS {schema}.valor_estado_instalacao (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_estado_instalacao_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_estado_instalacao (identificador, descricao) VALUES
('1', 'Desmantelada')
, ('2', 'Em construção')
, ('3', 'Em desuso')
, ('4', 'Projetada')
, ('5', 'Funcional');

CREATE TABLE IF NOT EXISTS {schema}.barreira (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NULL,
	id_hidrografico varchar(255) NULL,
	valor_barreira varchar(10) NOT NULL,
	valor_estado_instalacao varchar(10) NULL,
	geometria public.geometry(geometry, 3763) NOT NULL,
	CONSTRAINT barreira_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.barreira ADD CONSTRAINT valor_barreira_id FOREIGN KEY (valor_barreira) REFERENCES {schema}.valor_barreira(identificador);
ALTER TABLE {schema}.barreira ADD CONSTRAINT valor_estado_instalacao_id_2 FOREIGN KEY (valor_estado_instalacao) REFERENCES {schema}.valor_estado_instalacao(identificador);
create trigger barreira_geometry_check before
insert
    on
    {schema}.barreira for each row execute function {schema}.trigger_linestring_polygon_validation();


CREATE TABLE IF NOT EXISTS {schema}.valor_designacao_tensao (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_designacao_tensao_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_designacao_tensao (identificador, descricao) VALUES
('1', 'Muito alta'), ('2', 'Alta'), ('3', 'Média'), ('4', 'Baixa');

CREATE TABLE IF NOT EXISTS {schema}.valor_posicao_vertical (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_posicao_vertical_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_posicao_vertical (identificador, descricao) VALUES
('1', 'Suspenso ou elevado'), ('0', 'Ao nível do solo'), ('-1', 'No subsolo');

CREATE TABLE IF NOT EXISTS {schema}.cabo_electrico (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	tensao_nominal float4 NULL,
	valor_designacao_tensao varchar(10) NOT NULL,
	valor_posicao_vertical varchar(10) NOT NULL,
	geometria public.geometry(linestring, 3763) NOT NULL,
	CONSTRAINT cabo_electrico_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.cabo_electrico ADD CONSTRAINT valor_designacao_tensao_id FOREIGN KEY (valor_designacao_tensao) REFERENCES {schema}.valor_designacao_tensao(identificador);
ALTER TABLE {schema}.cabo_electrico ADD CONSTRAINT valor_posicao_vertical_id FOREIGN KEY (valor_posicao_vertical) REFERENCES {schema}.valor_posicao_vertical(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_conduta_agua (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_conduta_agua_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_conduta_agua (identificador, descricao) VALUES
('1', 'Aqueduto'), ('2', 'Conduta'), ('3', 'Valeta');

CREATE TABLE IF NOT EXISTS {schema}.conduta_de_agua (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	diametro float4 NULL,
	valor_conduta_agua varchar(10) NOT NULL,
	valor_posicao_vertical varchar(10) NOT NULL,
	geometria public.geometry(linestring, 3763) NOT NULL,
	CONSTRAINT conduta_de_agua_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.conduta_de_agua ADD CONSTRAINT valor_conduta_agua_id FOREIGN KEY (valor_conduta_agua) REFERENCES {schema}.valor_conduta_agua(identificador);
ALTER TABLE {schema}.conduta_de_agua ADD CONSTRAINT valor_posicao_vertical_id FOREIGN KEY (valor_posicao_vertical) REFERENCES {schema}.valor_posicao_vertical(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_construcao_linear (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_construcao_linear_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_construcao_linear (identificador, descricao) VALUES
('1', 'Muro de alvenaria ou betão')
, ('2', 'Muro de pedra')
, ('3', 'Sebe')
, ('4', 'Gradeamento ou vedação')
, ('5', 'Muralha')
, ('6', 'Portão')
, ('7', 'Barreira acústica')
, ('8', 'Pista')
, ('9', 'Lancil')
, ('10', 'Guarda de segurança')
, ('11', 'Tapete para transporte de materiais');

CREATE TABLE IF NOT EXISTS {schema}.constru_linear (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NULL,
	suporte bool NOT NULL,
	valor_construcao_linear varchar(10) NOT NULL,
	largura float4 NULL,
	geometria public.geometry(linestring, 3763) NOT NULL,
	CONSTRAINT constru_linear_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.constru_linear ADD CONSTRAINT valor_construcao_linear_id FOREIGN KEY (valor_construcao_linear) REFERENCES {schema}.valor_construcao_linear(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_const_margem (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_const_margem_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_const_margem (identificador, descricao) VALUES
('1', 'Molhe ou quebra-mar')
, ('2', 'Pontão ou cais')
, ('3', 'Esporão')
, ('4', 'Paredão')
, ('5', 'Rampa')
, ('6', 'Degraus');

CREATE TABLE IF NOT EXISTS {schema}.constru_na_margem (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NULL,
	valor_tipo_const_margem varchar(10) NOT NULL,
	valor_estado_instalacao varchar(10) NULL,
	geometria public.geometry(polygon, 3763) NOT NULL,
	CONSTRAINT constru_na_margem_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.constru_na_margem ADD CONSTRAINT valor_estado_instalacao_id_3 FOREIGN KEY (valor_estado_instalacao) REFERENCES {schema}.valor_estado_instalacao(identificador);
ALTER TABLE {schema}.constru_na_margem ADD CONSTRAINT valor_tipo_const_margem_id FOREIGN KEY (valor_tipo_const_margem) REFERENCES {schema}.valor_tipo_const_margem(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_construcao (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_construcao_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_construcao (identificador, descricao) VALUES
('3', 'Piscina')
, ('4', 'Tanque')
, ('5', 'Campo de jogos')
, ('6', 'Lago de jardim')
, ('7', 'Escadaria')
, ('8', 'Bancada')
, ('9', 'Passeio')
, ('10', 'Limite da construção linear')
, ('11', 'Rampa de acesso')
, ('12', 'Grua ou guindaste');

CREATE TABLE IF NOT EXISTS {schema}.constru_polig (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NULL,
	valor_tipo_construcao varchar(10) NOT NULL,
	geometria public.geometry(polygon, 3763) NOT NULL,
	CONSTRAINT constru_polig_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.constru_polig ADD CONSTRAINT valor_tipo_construcao_id FOREIGN KEY (valor_tipo_construcao) REFERENCES {schema}.valor_tipo_construcao(identificador);


CREATE TABLE IF NOT EXISTS {schema}.curso_de_agua_area (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	delimitacao_conhecida bool NOT NULL,
	geometria public.geometry(polygonz, 3763) NOT NULL,
	CONSTRAINT curso_de_agua_area_pkey PRIMARY KEY (identificador)
);


CREATE TABLE IF NOT EXISTS {schema}.valor_curso_de_agua (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_curso_de_agua_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_curso_de_agua (identificador, descricao) VALUES
('3', 'Ribeira'), ('4', 'Linha de água'), ('5', 'Canal'), ('6', 'Vala'), ('7', 'Rio');

CREATE TABLE IF NOT EXISTS {schema}.valor_ficticio (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_ficticio_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_ficticio (identificador, descricao) VALUES
('1', 'Real')
, ('2', 'Fictício em curso de água - área')
, ('3', 'Fictício em água lêntica')
, ('4', 'Fictício conexão tributária')
, ('5', 'Fictício outra classificação');

CREATE TABLE IF NOT EXISTS {schema}.valor_natureza (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_natureza_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_natureza (identificador, descricao) VALUES
('1', 'Genérico'), ('2', 'Canalizado'), ('3', 'Coberto');

CREATE TABLE IF NOT EXISTS {schema}.curso_de_agua_eixo (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NULL,
	comprimento float4 NULL,
	delimitacao_conhecida bool NOT NULL,
	ficticio bool NOT NULL,
	mare bool NULL,
	navegavel_ou_flutuavel bool NOT NULL,
	largura float4 NULL,
	id_hidrografico varchar(255) NULL,
	id_curso_de_agua_area uuid NULL,
	id_agua_lentica uuid NULL,
	ordem_hidrologica varchar(255) NULL,
	origem_natural bool NULL,
	valor_curso_de_agua varchar(10) NOT NULL,
	valor_persistencia_hidrologica varchar(10) NULL,
	valor_posicao_vertical varchar(10) NOT NULL,
	valor_estado_instalacao varchar(10) NULL,
	valor_ficticio varchar(10) NULL,
	valor_natureza varchar(10) NOT NULL,
	geometria public.geometry(linestringz, 3763) NOT NULL,
	CONSTRAINT curso_de_agua_eixo_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.curso_de_agua_eixo ADD CONSTRAINT lig_agua_lentica_curso_agua_eixo FOREIGN KEY (id_agua_lentica) REFERENCES {schema}.agua_lentica(identificador);
ALTER TABLE {schema}.curso_de_agua_eixo ADD CONSTRAINT lig_curso_agua_area_curso_agua_eixo FOREIGN KEY (id_curso_de_agua_area) REFERENCES {schema}.curso_de_agua_area(identificador);
ALTER TABLE {schema}.curso_de_agua_eixo ADD CONSTRAINT valor_curso_de_agua_id FOREIGN KEY (valor_curso_de_agua) REFERENCES {schema}.valor_curso_de_agua(identificador);
ALTER TABLE {schema}.curso_de_agua_eixo ADD CONSTRAINT valor_estado_instalacao_id FOREIGN KEY (valor_estado_instalacao) REFERENCES {schema}.valor_estado_instalacao(identificador);
ALTER TABLE {schema}.curso_de_agua_eixo ADD CONSTRAINT valor_ficticio_id FOREIGN KEY (valor_ficticio) REFERENCES {schema}.valor_ficticio(identificador);
ALTER TABLE {schema}.curso_de_agua_eixo ADD CONSTRAINT valor_natureza_id FOREIGN KEY (valor_natureza) REFERENCES {schema}.valor_natureza(identificador);
ALTER TABLE {schema}.curso_de_agua_eixo ADD CONSTRAINT valor_persistencia_hidrologica_id FOREIGN KEY (valor_persistencia_hidrologica) REFERENCES {schema}.valor_persistencia_hidrologica(identificador);
ALTER TABLE {schema}.curso_de_agua_eixo ADD CONSTRAINT valor_posicao_vertical_id FOREIGN KEY (valor_posicao_vertical) REFERENCES {schema}.valor_posicao_vertical(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_curva (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_curva_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_curva (identificador, descricao) VALUES
('1', 'Mestra'), ('2', 'Secundária'), ('3', 'Auxiliar');

CREATE TABLE IF NOT EXISTS {schema}.curva_de_nivel (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_tipo_curva varchar(10) NOT NULL,
	geometria public.geometry(linestringz, 3763) NOT NULL,
	CONSTRAINT curva_de_nivel_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.curva_de_nivel ADD CONSTRAINT valor_tipo_curva_id FOREIGN KEY (valor_tipo_curva) REFERENCES {schema}.valor_tipo_curva(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_local_nomeado (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_local_nomeado_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_local_nomeado (identificador, descricao) VALUES
('1', 'Capital do País')
, ('2', 'Sede administrativa de Região Autónoma')
, ('3', 'Capital de Distrito')
, ('4', 'Sede de Município')
, ('5', 'Sede de Freguesia')
, ('6', 'Forma de relevo'), ('6.1', 'Serra'), ('6.2', 'Cabo'), ('6.3', 'Ria'), ('6.4', 'Pico'), ('6.5', 'Península'), ('6.6', 'Baía'), ('6.7', 'Enseada'), ('6.8', 'Ínsua'), ('6.9', 'Dunas'), ('6.10', 'Fajã'), ('6.11', 'Lombo'), ('6.12', 'Achada'), ('6.13', 'Vale')
, ('7', 'Lugar'), ('7.1', 'Cidade'), ('7.2', 'Vila'), ('7.3', 'Outro aglomerado')
, ('8', 'Designação local')
, ('9', 'Área protegida')
, ('10', 'Praia')
, ('11', 'Oceano')
, ('12', 'Arquipélago')
, ('13', 'Ilha')
, ('14', 'Ilhéu')
, ('15', 'Outro local nomeado');

CREATE TABLE IF NOT EXISTS {schema}.designacao_local (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_local_nomeado varchar(10) NOT NULL,
	nome varchar(255) NOT NULL,
	geometria public.geometry(point, 3763) NOT NULL,
	CONSTRAINT designacao_local_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.designacao_local ADD CONSTRAINT valor_local_nomeado_id FOREIGN KEY (valor_local_nomeado) REFERENCES {schema}.valor_local_nomeado(identificador);


CREATE TABLE IF NOT EXISTS {schema}.distrito (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	data_publicacao date NOT NULL,
	codigo varchar(255) NOT NULL,
	nome varchar(255) NOT NULL,
	geometria public.geometry(multipolygon, 3763) NOT NULL,
	CONSTRAINT distrito_pkey PRIMARY KEY (identificador)
);


CREATE TABLE IF NOT EXISTS {schema}.valor_condicao_const (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_condicao_const_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_condicao_const (identificador, descricao) VALUES
('1', 'Demolido')
, ('2', 'Desafetado')
, ('3', 'Em construção')
, ('4', 'Projetado')
, ('5', 'Ruína')
, ('6', 'Funcional');

CREATE TABLE IF NOT EXISTS {schema}.valor_elemento_edificio_xy (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_elemento_edificio_xy_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_elemento_edificio_xy (identificador, descricao) VALUES
('1', 'Combinado')
, ('2', 'Ponto de entrada')
, ('3', 'Invólucro')
, ('4', 'Implantação')
, ('5', 'Piso mais baixo acima do solo')
, ('6', 'Beira do telhado');

CREATE TABLE IF NOT EXISTS {schema}.valor_elemento_edificio_z (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_elemento_edificio_z_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_elemento_edificio_z (identificador, descricao) VALUES
('1', 'Invólucro acima do solo')
, ('2', 'Base do edifício')
, ('3', 'Ponto de entrada')
, ('4', 'Cornija geral')
, ('5', 'Solo geral')
, ('6', 'Telhado geral')
, ('7', 'Beira do telhado geral')
, ('8', 'Cornija mais alta')
, ('9', 'Ponto mais alto')
, ('10', 'Beira mais alta do telhado')
, ('11', 'Cornija mais baixa')
, ('12', 'Piso mais baixo acima do solo')
, ('13', 'Beira do telhado mais baixa')
, ('14', 'Topo do edifício')
, ('15', 'Ponto mais alto no solo')
, ('16', 'Ponto mais baixo no solo');

CREATE TABLE IF NOT EXISTS {schema}.valor_forma_edificio (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_forma_edificio_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_forma_edificio (identificador, descricao) VALUES
('1', 'Anfiteatro ao ar livre')
, ('2', 'Arco')
, ('3', 'Azenha')
, ('4', 'Construção precária')
, ('5', 'Barragem')
, ('6', 'Bunker')
, ('7', 'Capela')
, ('8', 'Castelo')
, ('9', 'Chaminé')
, ('10', 'Coreto')
, ('11', 'Espigueiro')
, ('12', 'Estádio')
, ('13', 'Estufa')
, ('14', 'Farol')
, ('15', 'Forte')
, ('16', 'Hangar')
, ('17', 'Igreja')
, ('18', 'Reservatório da mãe de água')
, ('19', 'Mesquita')
, ('20', 'Moinho de vento')
, ('21', 'Palácio')
, ('22', 'Pombal')
, ('23', 'Praça de touros')
, ('24', 'Silo')
, ('25', 'Sinagoga')
, ('26', 'Reservatório de armazenamento')
, ('27', 'Telheiro')
, ('28', 'Templo')
, ('29', 'Torre')
, ('30', 'Palheiro')
, ('31', 'Moinho de maré')
, ('32', 'Barracão')
, ('33', 'Quiosque fixo')
, ('34', 'Posto transformador')
, ('35', 'Gerador eólico');

CREATE TABLE IF NOT EXISTS {schema}.edificio (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inst_producao_id uuid NULL,
	inst_gestao_ambiental_id uuid NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	altura_edificio float4 NOT NULL,
	data_const date NULL,
	numero_total_pisos int4 NULL,
	valor_condicao_const varchar(10) NULL,
	valor_elemento_edificio_xy varchar(10) NOT NULL,
	valor_elemento_edificio_z varchar(10) NOT NULL,
	valor_forma_edificio varchar(10) NULL,
	geometria public.geometry(geometry, 3763) NOT NULL,
	CONSTRAINT edificio_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.edificio ADD CONSTRAINT localizacao_instalacao_ambiental FOREIGN KEY (inst_gestao_ambiental_id) REFERENCES {schema}.inst_gestao_ambiental(identificador);
ALTER TABLE {schema}.edificio ADD CONSTRAINT localizacao_instalacao_producao FOREIGN KEY (inst_producao_id) REFERENCES {schema}.inst_producao(identificador);
ALTER TABLE {schema}.edificio ADD CONSTRAINT valor_condicao_const_id FOREIGN KEY (valor_condicao_const) REFERENCES {schema}.valor_condicao_const(identificador);
ALTER TABLE {schema}.edificio ADD CONSTRAINT valor_elemento_edificio_xy_id FOREIGN KEY (valor_elemento_edificio_xy) REFERENCES {schema}.valor_elemento_edificio_xy(identificador);
ALTER TABLE {schema}.edificio ADD CONSTRAINT valor_elemento_edificio_z_id FOREIGN KEY (valor_elemento_edificio_z) REFERENCES {schema}.valor_elemento_edificio_z(identificador);
ALTER TABLE {schema}.edificio ADD CONSTRAINT valor_forma_edificio_id FOREIGN KEY (valor_forma_edificio) REFERENCES {schema}.valor_forma_edificio(identificador);
create trigger edifico_geometry_check before
insert
    on
    {schema}.edificio for each row execute function {schema}.trigger_point_polygon_validation();


CREATE TABLE IF NOT EXISTS {schema}.valor_elemento_associado_agua (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_elemento_associado_agua_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_elemento_associado_agua (identificador, descricao) VALUES
('1', 'Marco de incêndio')
, ('2', 'Estação elevatória'), ('2.1', 'EE de água'), ('2.2', 'EE de águas residuais')
, ('3', 'Estação de tratamento')
, ('4', 'Fonte')
, ('5', 'Poço')
, ('6', 'Furo')
, ('7', 'Reservatório de água'), ('7.1', 'Reservatório de água elevado'), ('7.2', 'Reservatório de água ao nível do solo')
, ('8', 'Nora')
, ('9', 'Estrutura de captação de água')
, ('10', 'Câmara de visita')
, ('11', 'Sumidouro')
, ('12', 'Sarjeta');

CREATE TABLE IF NOT EXISTS {schema}.elem_assoc_agua (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_elemento_associado_agua varchar(10) NOT NULL,
	nome varchar(255) NULL,
	geometria public.geometry(point, 3763) NOT NULL,
	CONSTRAINT elem_assoc_agua_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.elem_assoc_agua ADD CONSTRAINT valor_elemento_associado_agua_id FOREIGN KEY (valor_elemento_associado_agua) REFERENCES {schema}.valor_elemento_associado_agua(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_elemento_associado_electricidade (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_elemento_associado_electricidade_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_elemento_associado_electricidade (identificador, descricao) VALUES
('1', 'Central de produção elétrica'), ('1.1', 'Central hidroelétrica'), ('1.2', 'Central fotovoltaica'), ('1.3', 'Central eólica'), ('1.4', 'Central termoelétrica'), ('1.5', 'Central de biomassa'), ('1.6', 'Central geotérmica')
, ('2', 'Subestação elétrica')
, ('3', 'Aeromotor')
, ('4', 'Gerador eólico')
, ('5', 'Painel solar fotovoltaico')
, ('6', 'Estrutura de eletricidade com ponto de iluminação'), ('6.1', 'Apoio isolado de iluminação'), ('6.2', 'Apoio de baixa tensão com iluminação'), ('6.3', 'Estrutura de iluminação')
, ('7', 'Apoio de eletricidade'), ('7.1', 'Apoio de alta tensão'), ('7.2', 'Apoio de média tensão'), ('7.3', 'Apoio de baixa tensão'), ('7.4', 'Apoio de muito alta tensão')
, ('8', 'Posto transformador')
, ('9', 'Posto de transformação aéreo')
, ('10', 'Armário de distribuição')
, ('11', 'Câmara de visita');

CREATE TABLE IF NOT EXISTS {schema}.elem_assoc_eletricidade (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_elemento_associado_electricidade varchar(10) NOT NULL,
	nome varchar(255) NULL,
	geometria public.geometry(point, 3763) NOT NULL,
	CONSTRAINT elem_assoc_eletricidade_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.elem_assoc_eletricidade ADD CONSTRAINT valor_elemento_associado_electricidade_id FOREIGN KEY (valor_elemento_associado_electricidade) REFERENCES {schema}.valor_elemento_associado_electricidade(identificador);


CREATE TABLE {schema}.valor_elemento_associado_pgq (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_elemento_associado_pgq_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_elemento_associado_pgq (identificador, descricao) VALUES
('1', 'Petróleo ou derivados')
, ('2', 'Gás')
, ('2.1', 'Estação da RNTGN')
, ('2.1.1', 'Estação de seccionamento')
, ('2.1.2', 'Estação de derivação')
, ('2.1.3', 'Estação de redução e medição de gás')
, ('2.1.4', 'Ponto de entrega')
, ('2.2', 'Instalação de armazenamento subterrâneo de gás natural')
, ('2.3', 'Terminal de GNL')
, ('2.4', 'Unidade autónoma de gás natural (UAG)')
, ('2.100', 'Outra instalação de gás')
, ('3', 'Substâncias químicas');

CREATE TABLE IF NOT EXISTS {schema}.elem_assoc_pgq (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_elemento_associado_pgq varchar(10) NOT NULL,
	nome varchar(255) NULL,
	geometria public.geometry(point, 3763) NOT NULL,
	CONSTRAINT elem_assoc_pgq_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.elem_assoc_pgq ADD CONSTRAINT valor_elemento_associado_pgq_id FOREIGN KEY (valor_elemento_associado_pgq) REFERENCES {schema}.valor_elemento_associado_pgq(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_elemento_associado_telecomunicacoes (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_elemento_associado_telecomunicacoes_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_elemento_associado_telecomunicacoes (identificador, descricao) VALUES
('1', 'Apoio de telecomunicações')
, ('2', 'Cabina telefónica')
, ('3', 'Antena')
, ('4', 'Armário')
, ('5', 'Câmara de visita');

CREATE TABLE IF NOT EXISTS {schema}.elem_assoc_telecomunicacoes (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_elemento_associado_telecomunicacoes varchar(10) NOT NULL,
	geometria public.geometry(point, 3763) NOT NULL,
	CONSTRAINT elem_assoc_telecomunicacoes_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.elem_assoc_telecomunicacoes ADD CONSTRAINT valor_elemento_associado_telecomunicacoes_id FOREIGN KEY (valor_elemento_associado_telecomunicacoes) REFERENCES {schema}.valor_elemento_associado_telecomunicacoes(identificador);


CREATE TABLE IF NOT EXISTS {schema}.freguesia (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	data_publicacao date NOT NULL,
	codigo varchar(255) NOT NULL,
	nome varchar(255) NOT NULL,
	geometria public.geometry(multipolygon, 3763) NOT NULL,
	CONSTRAINT freguesia_pkey PRIMARY KEY (identificador)
);


CREATE TABLE {schema}.valor_estado_fronteira (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_estado_fronteira_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_estado_fronteira (identificador, descricao) VALUES
('1', 'Definido'), ('2', 'Por acordar');

CREATE TABLE IF NOT EXISTS {schema}.fronteira (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_estado_fronteira varchar(10) NOT NULL,
	data_publicacao date NOT NULL,
	geometria public.geometry(linestring, 3763) NOT NULL,
	CONSTRAINT fronteira_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.fronteira ADD CONSTRAINT valor_estado_fronteira_id FOREIGN KEY (valor_estado_fronteira) REFERENCES {schema}.valor_estado_fronteira(identificador);


CREATE TABLE {schema}.valor_tipo_fronteira_terra_agua (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_fronteira_terra_agua_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_fronteira_terra_agua (identificador, descricao) VALUES
('1', 'Linha de costa')
, ('2', 'Linha limite do leito')
, ('3', 'Linha limite de ilha')
, ('4', 'Linha de nível pleno de armazenamento');

CREATE TABLE IF NOT EXISTS {schema}.fronteira_terra_agua (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	data_fonte_dados date NOT NULL,
	fonte_dados varchar(255) NOT NULL,
	ilha bool NOT NULL,
	origem_natural bool NULL,
	valor_tipo_fronteira_terra_agua varchar(10) NOT NULL,
	geometria public.geometry(linestringz, 3763) NOT NULL,
	CONSTRAINT fronteira_terra_agua_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.fronteira_terra_agua ADD CONSTRAINT valor_tipo_fronteira_terra_agua_id FOREIGN KEY (valor_tipo_fronteira_terra_agua) REFERENCES {schema}.valor_tipo_fronteira_terra_agua(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_categoria_infra_trans_aereo (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_categoria_infra_trans_aereo_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_categoria_infra_trans_aereo (identificador, descricao) VALUES
('1', 'Internacional'), ('2', 'Nacional'), ('3', 'Regional');

CREATE TABLE IF NOT EXISTS {schema}.valor_restricao_infra_trans_aereo (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_restricao_infra_trans_aereo_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_restricao_infra_trans_aereo (identificador, descricao) VALUES
('1', 'Fins exclusivamente militares'), ('2', 'Restrições temporais');

CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_infra_trans_aereo (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_infra_trans_aereo_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_infra_trans_aereo (identificador, descricao) VALUES
('1', 'Aeródromo')
, ('2', 'Heliporto')
, ('3', 'Aeródromo com heliporto')
, ('4', 'Local de aterragem');

CREATE TABLE IF NOT EXISTS {schema}.infra_trans_aereo (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	codigo_iata varchar(255) NULL,
	codigo_icao varchar(255) NULL,
	nome varchar(255) NULL,
	valor_categoria_infra_trans_aereo varchar(10) NOT NULL,
	valor_restricao_infra_trans_aereo varchar(10) NULL,
	valor_tipo_infra_trans_aereo varchar(10) NOT NULL,
	geometria public.geometry(point, 3763) NOT NULL,
	CONSTRAINT infra_trans_aereo_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.infra_trans_aereo ADD CONSTRAINT valor_categoria_infra_trans_aereo_id FOREIGN KEY (valor_categoria_infra_trans_aereo) REFERENCES {schema}.valor_categoria_infra_trans_aereo(identificador);
ALTER TABLE {schema}.infra_trans_aereo ADD CONSTRAINT valor_restricao_infra_trans_aereo_id FOREIGN KEY (valor_restricao_infra_trans_aereo) REFERENCES {schema}.valor_restricao_infra_trans_aereo(identificador);
ALTER TABLE {schema}.infra_trans_aereo ADD CONSTRAINT valor_tipo_infra_trans_aereo_id FOREIGN KEY (valor_tipo_infra_trans_aereo) REFERENCES {schema}.valor_tipo_infra_trans_aereo(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_infra_trans_via_navegavel (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_infra_trans_via_navegavel_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_infra_trans_via_navegavel (identificador, descricao) VALUES
('1', 'Porto'), ('2', 'Cais'), ('3', 'Doca');

CREATE TABLE IF NOT EXISTS {schema}.infra_trans_via_navegavel (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NOT NULL,
	codigo_via_navegavel varchar(255) NULL,
	valor_tipo_infra_trans_via_navegavel varchar(10) NOT NULL,
	geometria public.geometry(point, 3763) NOT NULL,
	CONSTRAINT infra_trans_via_navegavel_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.infra_trans_via_navegavel ADD CONSTRAINT valor_tipo_infra_trans_via_navegavel_id FOREIGN KEY (valor_tipo_infra_trans_via_navegavel) REFERENCES {schema}.valor_tipo_infra_trans_via_navegavel(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_classifica (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_classifica_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_classifica (identificador, descricao) VALUES
('1', 'Base do declive')
, ('2', 'Alteração no declive')
, ('3', 'Linha de forma')
, ('6', 'Topo do declive')
, ('7', 'Limite de área plana');

CREATE TABLE IF NOT EXISTS {schema}.valor_natureza_linha (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_natureza_linha_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_natureza_linha (identificador, descricao) VALUES
('1', 'Escarpado')
, ('2', 'Talude')
, ('3', 'Socalco')
, ('4', 'Combro')
, ('5', 'Talvegue')
, ('6', 'Cumeada')
, ('7', 'Plano');

CREATE TABLE IF NOT EXISTS {schema}.linha_de_quebra (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_classifica varchar(10) NOT NULL,
	valor_natureza_linha varchar(10) NOT NULL,
	artificial bool NULL,
	geometria public.geometry(linestringz, 3763) NOT NULL,
	CONSTRAINT linha_de_quebra_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.linha_de_quebra ADD CONSTRAINT valor_classifica_id FOREIGN KEY (valor_classifica) REFERENCES {schema}.valor_classifica(identificador);
ALTER TABLE {schema}.linha_de_quebra ADD CONSTRAINT valor_natureza_linha_id FOREIGN KEY (valor_natureza_linha) REFERENCES {schema}.valor_natureza_linha(identificador);


CREATE TABLE IF NOT EXISTS {schema}.linha_ferrea (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	codigo_linha_ferrea varchar(255) NOT NULL,
	nome varchar(255) NOT NULL,
	CONSTRAINT linha_ferrea_pkey PRIMARY KEY (identificador)
);


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_de_mob_urbano_sinal (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_de_mob_urbano_sinal_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_de_mob_urbano_sinal (identificador, descricao) VALUES
('2', 'Banco de jardim')
, ('3', 'Canteiro')
, ('4', 'Lixo indiferenciado')
, ('5', 'Ecoponto')
, ('6', 'Equipamento de exercício físico ao ar livre')
, ('8', 'Marco de correio')
, ('9', 'Painel publicitário')
, ('10', 'Papeleira')
, ('12', 'Parquímetro')
, ('13', 'Passadeira de peões')
, ('14', 'Placa informativa')
, ('15', 'Pérgula')
, ('16', 'Posto de carregamento elétrico')
, ('19', 'Semáforo')
, ('20', 'Sinal de trânsito')
, ('22', 'Contentor de reutilização');

CREATE TABLE IF NOT EXISTS {schema}.mob_urbano_sinal (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_tipo_de_mob_urbano_sinal varchar(10) NOT NULL,
	geometria public.geometry(geometry, 3763) NOT NULL,
	CONSTRAINT mob_urbano_sinal_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.mob_urbano_sinal ADD CONSTRAINT valor_tipo_de_mob_urbano_sinal_id FOREIGN KEY (valor_tipo_de_mob_urbano_sinal) REFERENCES {schema}.valor_tipo_de_mob_urbano_sinal(identificador);
create trigger mob_urbano_sinal_geometry_check before
insert
    on
    {schema}.mob_urbano_sinal for each row execute function {schema}.trigger_point_polygon_validation();


CREATE TABLE IF NOT EXISTS {schema}.municipio (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	data_publicacao date NOT NULL,
	codigo varchar(255) NOT NULL,
	nome varchar(255) NOT NULL,
	geometria public.geometry(multipolygon, 3763) NOT NULL,
	CONSTRAINT municipio_pkey PRIMARY KEY (identificador)
);


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_nascente (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_nascente_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_nascente (identificador, descricao) VALUES
('1', 'Água de nascente'), ('2', 'Água mineral');

CREATE TABLE IF NOT EXISTS {schema}.nascente (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NULL,
	id_hidrografico varchar(255) NULL,
	valor_persistencia_hidrologica varchar(10) NULL,
	valor_tipo_nascente varchar(10) NULL,
	geometria public.geometry(pointz, 3763) NOT NULL,
	CONSTRAINT nascente_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.nascente ADD CONSTRAINT valor_persistencia_hidrologica_id FOREIGN KEY (valor_persistencia_hidrologica) REFERENCES {schema}.valor_persistencia_hidrologica(identificador);
ALTER TABLE {schema}.nascente ADD CONSTRAINT valor_tipo_nascente_id FOREIGN KEY (valor_tipo_nascente) REFERENCES {schema}.valor_tipo_nascente(identificador);


CREATE TABLE {schema}.valor_tipo_no_hidrografico (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_no_hidrografico_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_no_hidrografico (identificador, descricao) VALUES
('1', 'Início')
, ('2', 'Fim')
, ('3', 'Junção')
, ('4', 'Pseudo-nó')
, ('5', 'Variação de fluxo')
, ('6', 'Regulação de fluxo')
, ('7', 'Fronteira')
, ('8', 'Limite do trabalho');

CREATE TABLE IF NOT EXISTS {schema}.no_hidrografico (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	id_hidrografico varchar(255) NULL,
	valor_tipo_no_hidrografico varchar(10) NOT NULL,
	geometria public.geometry(pointz, 3763) NOT NULL,
	CONSTRAINT no_hidrografico_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.no_hidrografico ADD CONSTRAINT valor_tipo_no_hidrografico_id FOREIGN KEY (valor_tipo_no_hidrografico) REFERENCES {schema}.valor_tipo_no_hidrografico(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_no_trans_ferrov (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_no_trans_ferrov_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_no_trans_ferrov (identificador, descricao) VALUES
('1', 'Junção')
, ('2', 'Passagem de nível')
, ('3', 'Pseudo-nó')
, ('4', 'Fim da via ferroviária')
, ('5', 'Paragem')
, ('6', 'Fronteira')
, ('7', 'Limite do trabalho');

CREATE TABLE IF NOT EXISTS {schema}.no_trans_ferrov (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_tipo_no_trans_ferrov varchar(10) NOT NULL,
	geometria public.geometry(pointz, 3763) NOT NULL,
	CONSTRAINT no_trans_ferrov_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.no_trans_ferrov ADD CONSTRAINT valor_tipo_no_trans_ferrov_id FOREIGN KEY (valor_tipo_no_trans_ferrov) REFERENCES {schema}.valor_tipo_no_trans_ferrov(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_no_trans_rodov (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_no_trans_rodov_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_no_trans_rodov (identificador, descricao) VALUES
('1', 'Junção')
, ('2', 'Passagem de nível')
, ('3', 'Pseudo-nó')
, ('4', 'Fim da via rodoviária')
, ('5', 'Infraestrutura')
, ('6', 'Fronteira')
, ('7', 'Limite do trabalho');

CREATE TABLE IF NOT EXISTS {schema}.no_trans_rodov (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_tipo_no_trans_rodov varchar(10) NOT NULL,
	geometria public.geometry(pointz, 3763) NOT NULL,
	CONSTRAINT no_trans_rodov_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.no_trans_rodov ADD CONSTRAINT valor_tipo_no_trans_rodov_id FOREIGN KEY (valor_tipo_no_trans_rodov) REFERENCES {schema}.valor_tipo_no_trans_rodov(identificador);


CREATE TABLE IF NOT EXISTS {schema}.nome_edificio (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	edificio_id uuid NOT NULL,
	nome varchar(255) NOT NULL,
	CONSTRAINT nome_edificio_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.nome_edificio ADD CONSTRAINT nome_edificio_id_edificio_id FOREIGN KEY (edificio_id) REFERENCES {schema}.edificio(identificador) ON DELETE CASCADE;


CREATE TABLE IF NOT EXISTS {schema}.valor_caract_fisica_rodov (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_caract_fisica_rodov_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_caract_fisica_rodov (identificador, descricao) VALUES
('1', 'Autoestrada ou via reservada a automóveis e motociclos')
, ('2', 'Estrada')
, ('3', 'Via urbana')
, ('4', 'Via rural')
, ('5', 'Aceiro')
, ('6', 'Ciclovia')
, ('7', 'Vereda');

CREATE TABLE IF NOT EXISTS {schema}.valor_estado_via_rodov (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_estado_via_rodov_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_estado_via_rodov (identificador, descricao) VALUES
('1', 'Desmantelada')
, ('2', 'Em construção')
, ('3', 'Em desuso')
, ('4', 'Projetada')
, ('5', 'Funcional');

CREATE TABLE IF NOT EXISTS {schema}.valor_posicao_vertical_transportes (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_posicao_vertical_transportes_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_posicao_vertical_transportes (identificador, descricao) VALUES
('3', 'Suspenso ou elevado: nível acima do nível 2')
, ('2', 'Suspenso ou elevado: nível 2, acima de nível 1')
, ('1', 'Suspenso ou elevado: nível 1')
, ('0', 'Ao nível do solo')
, ('-1', 'No subsolo: nível -1')
, ('-2', 'No subsolo: nível mais profundo que nível -1')
, ('-3', 'No subsolo: nível mais profundo que nível -2');

CREATE TABLE IF NOT EXISTS {schema}.valor_restricao_acesso (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_restricao_acesso_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_restricao_acesso (identificador, descricao) VALUES
('1', 'Livre')
, ('2', 'Pago')
, ('3', 'Privado')
, ('4', 'Proibido por lei')
, ('5', 'Sazonal'), ('5.1', 'Diário'), ('5.2', 'Estação do ano')
, ('6', 'Acesso físico impossível');

CREATE TABLE IF NOT EXISTS {schema}.valor_sentido (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_sentido_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_sentido (identificador, descricao) VALUES
('1', 'Duplo'), ('2', 'No sentido'), ('3', 'Sentido contrário');

CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_troco_rodoviario (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_troco_rodoviario_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_troco_rodoviario (identificador, descricao) VALUES
('1', 'Plena via')
, ('2', 'Ramo de ligação')
, ('3', 'Rotunda')
, ('4', 'Via de serviço')
, ('5', 'Via em escada')
, ('6', 'Trilho')
, ('7', 'Passadiço')
, ('8', 'Escapatória');

CREATE TABLE IF NOT EXISTS {schema}.seg_via_rodov (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	gestao varchar(255) NULL,
	largura_via_rodov float4 NULL,
	multipla_faixa_rodagem bool NULL,
	num_vias_transito int4 NOT NULL,
	pavimentado bool NOT NULL,
	velocidade_max int4 NULL,
	jurisdicao varchar(255) NULL,
	valor_caract_fisica_rodov varchar(10) NOT NULL,
	valor_estado_via_rodov varchar(10) NOT NULL,
	valor_posicao_vertical_transportes varchar(10) NOT NULL,
	valor_restricao_acesso varchar(10) NULL,
	valor_sentido varchar(10) NOT NULL,
	valor_tipo_troco_rodoviario varchar(10) NOT NULL,
	geometria public.geometry(linestringz, 3763) NOT NULL,
	CONSTRAINT seg_via_rodov_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.seg_via_rodov ADD CONSTRAINT valor_caract_fisica_rodov_id FOREIGN KEY (valor_caract_fisica_rodov) REFERENCES {schema}.valor_caract_fisica_rodov(identificador);
ALTER TABLE {schema}.seg_via_rodov ADD CONSTRAINT valor_estado_via_rodov_id FOREIGN KEY (valor_estado_via_rodov) REFERENCES {schema}.valor_estado_via_rodov(identificador);
ALTER TABLE {schema}.seg_via_rodov ADD CONSTRAINT valor_posicao_vertical_transportes_id FOREIGN KEY (valor_posicao_vertical_transportes) REFERENCES {schema}.valor_posicao_vertical_transportes(identificador);
ALTER TABLE {schema}.seg_via_rodov ADD CONSTRAINT valor_restricao_acesso_id FOREIGN KEY (valor_restricao_acesso) REFERENCES {schema}.valor_restricao_acesso(identificador);
ALTER TABLE {schema}.seg_via_rodov ADD CONSTRAINT valor_sentido_id FOREIGN KEY (valor_sentido) REFERENCES {schema}.valor_sentido(identificador);
ALTER TABLE {schema}.seg_via_rodov ADD CONSTRAINT valor_tipo_troco_rodoviario_id FOREIGN KEY (valor_tipo_troco_rodoviario) REFERENCES {schema}.valor_tipo_troco_rodoviario(identificador);


CREATE TABLE IF NOT EXISTS {schema}.numero_policia (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	edificio_id uuid NULL,
	seg_via_rodov_id uuid NOT NULL,
	numero varchar(255) NOT NULL,
	geometria public.geometry(point, 3763) NOT NULL,
	CONSTRAINT numero_policia_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.numero_policia ADD CONSTRAINT numero_policia_id_edificio_id FOREIGN KEY (edificio_id) REFERENCES {schema}.edificio(identificador);
ALTER TABLE {schema}.numero_policia ADD CONSTRAINT numero_policia_id_seg_via_rodov_id FOREIGN KEY (seg_via_rodov_id) REFERENCES {schema}.seg_via_rodov(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_obra_arte (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_obra_arte_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_obra_arte (identificador, descricao) VALUES
('1', 'Ponte')
, ('2', 'Viaduto')
, ('3', 'Passagem superior')
, ('4', 'Passagem inferior')
, ('5', 'Túnel')
, ('6', 'Passagem hidráulica')
, ('7', 'Passagem pedonal')
, ('8', 'Pilar')
, ('9', 'Estrutura de proteção');

CREATE TABLE IF NOT EXISTS {schema}.obra_arte (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NULL,
	valor_tipo_obra_arte varchar(10) NOT NULL,
	geometria public.geometry(polygonz, 3763) NOT NULL,
	CONSTRAINT obra_arte_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.obra_arte ADD CONSTRAINT valor_tipo_obra_arte_id FOREIGN KEY (valor_tipo_obra_arte) REFERENCES {schema}.valor_tipo_obra_arte(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_gasoduto_oleoduto_sub_quimicas (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_gasoduto_oleoduto_sub_quimicas_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_gasoduto_oleoduto_sub_quimicas (identificador, descricao) VALUES
('1', 'Gasoduto'), ('1.1', 'Gasoduto de 1º escalão'), ('1.2', 'Gasoduto de 2º escalão'), ('1.3', 'Gasoduto de 3º escalão')
, ('2', 'Oleoduto')
, ('3', 'Outros produtos');

CREATE TABLE IF NOT EXISTS {schema}.oleoduto_gasoduto_subtancias_quimicas (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	diametro float4 NULL,
	valor_gasoduto_oleoduto_sub_quimicas varchar(10) NOT NULL,
	valor_posicao_vertical varchar(10) NOT NULL,
	geometria public.geometry(linestring, 3763) NOT NULL,
	CONSTRAINT oleoduto_gasoduto_subtancias_quimicas_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.oleoduto_gasoduto_subtancias_quimicas ADD CONSTRAINT valor_gasoduto_oleoduto_sub_quimicas_id FOREIGN KEY (valor_gasoduto_oleoduto_sub_quimicas) REFERENCES {schema}.valor_gasoduto_oleoduto_sub_quimicas(identificador);
ALTER TABLE {schema}.oleoduto_gasoduto_subtancias_quimicas ADD CONSTRAINT valor_posicao_vertical_id FOREIGN KEY (valor_posicao_vertical) REFERENCES {schema}.valor_posicao_vertical(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_classifica_las (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_classifica_las_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_classifica_las (identificador, descricao) VALUES
('1', 'Terreno')
, ('2', 'Edifício'), ('2.1', 'Edifício - soleira'), ('2.2', 'Edifício - beirado'), ('2.3', 'Edifício - ponto mais alto')
, ('3', 'Tabuleiro suspenso ou elevado');

CREATE TABLE IF NOT EXISTS {schema}.ponto_cotado (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_classifica_las varchar(10) NOT NULL,
	geometria public.geometry(pointz, 3763) NOT NULL,
	CONSTRAINT ponto_cotado_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.ponto_cotado ADD CONSTRAINT valor_classifica_las_id FOREIGN KEY (valor_classifica_las) REFERENCES {schema}.valor_classifica_las(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_ponto_interesse (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_ponto_interesse_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_ponto_interesse (identificador, descricao) VALUES
('1', 'Alminha')
, ('2', 'Anta')
, ('3', 'Árvore')
, ('4', 'Árvore classificada')
, ('5', 'Castro')
, ('6', 'Cruzeiro')
, ('7', 'Estátua')
, ('8', 'Menir')
, ('9', 'Miradouro')
, ('10', 'Padrão')
, ('11', 'Pelourinho')
, ('12', 'Ruínas com interesse histórico')
, ('13', 'Outro - Ponto de Interesse');

CREATE TABLE IF NOT EXISTS {schema}.ponto_interesse (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NULL,
	valor_tipo_ponto_interesse varchar(10) NOT NULL,
	geometria public.geometry(geometry, 3763) NOT NULL,
	CONSTRAINT ponto_interesse_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.ponto_interesse ADD CONSTRAINT valor_tipo_ponto_interesse_id FOREIGN KEY (valor_tipo_ponto_interesse) REFERENCES {schema}.valor_tipo_ponto_interesse(identificador);
create trigger ponto_interesse_geometry_check before
insert
    on
    {schema}.ponto_interesse for each row execute function {schema}.trigger_point_polygon_validation();


CREATE TABLE IF NOT EXISTS {schema}.queda_de_agua (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NULL,
	altura float4 NULL,
	id_hidrografico varchar(255) NULL,
	geometria public.geometry(pointz, 3763) NOT NULL,
	CONSTRAINT queda_de_agua_pkey PRIMARY KEY (identificador)
);
create trigger queda_de_agua_geometry_check before
insert
    on
    {schema}.queda_de_agua for each row execute function {schema}.trigger_point_polygon_validation();


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_via_cabo (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_via_cabo_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_via_cabo (identificador, descricao) VALUES
('1', 'Cabina'), ('2', 'Cadeira'), ('3', 'Teleski');

CREATE TABLE IF NOT EXISTS {schema}.seg_via_cabo (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NULL,
	valor_tipo_via_cabo varchar(10) NULL,
	geometria public.geometry(linestring, 3763) NOT NULL,
	CONSTRAINT seg_via_cabo_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.seg_via_cabo ADD CONSTRAINT valor_tipo_via_cabo_id FOREIGN KEY (valor_tipo_via_cabo) REFERENCES {schema}.valor_tipo_via_cabo(identificador);


CREATE TABLE {schema}.valor_categoria_bitola (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_categoria_bitola_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_categoria_bitola (identificador, descricao) VALUES
('1', 'Ibérica')
, ('2', 'Europeia')
, ('3', 'Métrica')
, ('995', 'Não aplicável');

CREATE TABLE {schema}.valor_estado_linha_ferrea (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_estado_linha_ferrea_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_estado_linha_ferrea (identificador, descricao) VALUES
('1', 'Desmantelada')
, ('2', 'Em construção')
, ('3', 'Em desuso')
, ('4', 'Projetada')
, ('5', 'Funcional');

CREATE TABLE {schema}.valor_tipo_linha_ferrea (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_linha_ferrea_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_linha_ferrea (identificador, descricao) VALUES
('1', 'Ferrovia de cremalheira')
, ('2', 'Funicular')
, ('3', 'Levitação magnética')
, ('4', 'Metro')
, ('5', 'Carril único')
, ('6', 'Carril único (suspenso)')
, ('7', 'Comboio (dois carris paralelos)')
, ('8', 'Elétrico');

CREATE TABLE {schema}.valor_tipo_troco_via_ferrea (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_troco_via_ferrea_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_troco_via_ferrea (identificador, descricao) VALUES
('1', 'Via única'), ('2', 'Via dupla'), ('3', 'Via múltipla');

CREATE TABLE {schema}.valor_via_ferrea (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_via_ferrea_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_via_ferrea (identificador, descricao) VALUES
('1', 'Plena via')
, ('2', 'Linha de estação')
, ('3', 'Linha de estacionamento')
, ('4', 'Linha de segurança')
, ('5', 'Ramal particular');

CREATE TABLE IF NOT EXISTS {schema}.seg_via_ferrea (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	eletrific bool NOT NULL,
	gestao varchar(255) NULL,
	velocidade_max int4 NULL,
	valor_categoria_bitola varchar(10) NOT NULL,
	valor_estado_linha_ferrea varchar(10) NOT NULL,
	valor_posicao_vertical_transportes varchar(10) NOT NULL,
	valor_tipo_linha_ferrea varchar(10) NOT NULL,
	valor_tipo_troco_via_ferrea varchar(10) NOT NULL,
	valor_via_ferrea varchar(10) NULL,
	jurisdicao varchar(255) NULL,
	geometria public.geometry(linestringz, 3763) NOT NULL,
	CONSTRAINT seg_via_ferrea_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.seg_via_ferrea ADD CONSTRAINT valor_categoria_bitola_id FOREIGN KEY (valor_categoria_bitola) REFERENCES {schema}.valor_categoria_bitola(identificador);
ALTER TABLE {schema}.seg_via_ferrea ADD CONSTRAINT valor_estado_linha_ferrea_id FOREIGN KEY (valor_estado_linha_ferrea) REFERENCES {schema}.valor_estado_linha_ferrea(identificador);
ALTER TABLE {schema}.seg_via_ferrea ADD CONSTRAINT valor_posicao_vertical_transportes_id FOREIGN KEY (valor_posicao_vertical_transportes) REFERENCES {schema}.valor_posicao_vertical_transportes(identificador);
ALTER TABLE {schema}.seg_via_ferrea ADD CONSTRAINT valor_tipo_linha_ferrea_id FOREIGN KEY (valor_tipo_linha_ferrea) REFERENCES {schema}.valor_tipo_linha_ferrea(identificador);
ALTER TABLE {schema}.seg_via_ferrea ADD CONSTRAINT valor_tipo_troco_via_ferrea_id FOREIGN KEY (valor_tipo_troco_via_ferrea) REFERENCES {schema}.valor_tipo_troco_via_ferrea(identificador);
ALTER TABLE {schema}.seg_via_ferrea ADD CONSTRAINT valor_via_ferrea_id FOREIGN KEY (valor_via_ferrea) REFERENCES {schema}.valor_via_ferrea(identificador);


CREATE TABLE {schema}.valor_categoria (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_categoria_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_categoria (identificador, descricao) VALUES
('1', 'Primordial'), ('2', 'Auxiliar'), ('995', 'Não aplicável');

CREATE TABLE {schema}.valor_tipo_sinal_geodesico (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_sinal_geodesico_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_sinal_geodesico (identificador, descricao) VALUES
('1', 'Estação Permanente')
, ('2', 'Vértice Geodésico')
, ('3', 'Marca de Nivelamento')
, ('4', 'Marégrafo')
, ('5', 'Estação Gravimétrica');

CREATE TABLE IF NOT EXISTS {schema}.sinal_geodesico (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	data_revisao date NOT NULL,
	nome varchar(255) NULL,
	valor_categoria varchar(10) NOT NULL,
	valor_tipo_sinal_geodesico varchar(10) NOT NULL,
	geometria public.geometry(pointz, 3763) NOT NULL,
	CONSTRAINT sinal_geodesico_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.sinal_geodesico ADD CONSTRAINT valor_categoria_id FOREIGN KEY (valor_categoria) REFERENCES {schema}.valor_categoria(identificador);
ALTER TABLE {schema}.sinal_geodesico ADD CONSTRAINT valor_tipo_sinal_geodesico_id FOREIGN KEY (valor_tipo_sinal_geodesico) REFERENCES {schema}.valor_tipo_sinal_geodesico(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_terreno_marginal (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_terreno_marginal_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_terreno_marginal (identificador, descricao) VALUES
('1', 'Pedregulho')
, ('2', 'Argila')
, ('3', 'Cascalho')
, ('4', 'Lama')
, ('5', 'Rocha')
, ('6', 'Areia')
, ('7', 'Seixos')
, ('8', 'Pedra');

CREATE TABLE IF NOT EXISTS {schema}.terreno_marginal (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NULL,
	id_hidrografico varchar(255) NULL,
	valor_tipo_terreno_marginal varchar(10) NOT NULL,
	geometria public.geometry(polygon, 3763) NOT NULL,
	CONSTRAINT terreno_marginal_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.terreno_marginal ADD CONSTRAINT valor_tipo_terreno_marginal_id FOREIGN KEY (valor_tipo_terreno_marginal) REFERENCES {schema}.valor_tipo_terreno_marginal(identificador);


CREATE TABLE IF NOT EXISTS {schema}.via_rodov (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	codigo_via_rodov varchar(255) NOT NULL,
	data_cat date NOT NULL,
	fonte_aquisicao_dados varchar(255) NOT NULL,
	nome varchar(255) NOT NULL,
	nome_alternativo varchar(255) NULL,
	tipo_via_rodov_abv varchar(255) NOT NULL,
	tipo_via_rodov_c varchar(255) NOT NULL,
	tipo_via_rodov_d varchar(255) NOT NULL,
	CONSTRAINT via_rodov_pkey PRIMARY KEY (identificador)
);


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_limite (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_limite_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_limite (identificador, descricao) VALUES
('1', 'Limite exterior sem berma'), ('2', 'Separador'), ('3', 'Limite exterior com berma pavimentada');

CREATE TABLE IF NOT EXISTS {schema}.via_rodov_limite (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_tipo_limite varchar(10) NOT NULL,
	geometria public.geometry(linestringz, 3763) NOT NULL,
	CONSTRAINT via_rodov_limite_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.via_rodov_limite ADD CONSTRAINT valor_tipo_limite_id FOREIGN KEY (valor_tipo_limite) REFERENCES {schema}.valor_tipo_limite(identificador);


CREATE TABLE {schema}.valor_zona_humida (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_zona_humida_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_zona_humida (identificador, descricao) VALUES
('1', 'Sapal ou terreno inundável'), ('2', 'Turfeira'), ('3', 'Paul');

CREATE TABLE IF NOT EXISTS {schema}.zona_humida (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NULL,
	mare bool NOT NULL,
	id_hidrografico varchar(255) NULL,
	valor_zona_humida varchar(10) NOT NULL,
	geometria public.geometry(polygonz, 3763) NOT NULL,
	CONSTRAINT zona_humida_pkey PRIMARY KEY (identificador)
);
ALTER TABLE {schema}.zona_humida ADD CONSTRAINT valor_zona_humida_id FOREIGN KEY (valor_zona_humida) REFERENCES {schema}.valor_zona_humida(identificador);


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_circulacao (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_circulacao_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_circulacao (identificador, descricao) VALUES
('1', 'Veículo ligeiro ou pesado')
, ('2', 'Veículo agrícola ou com tração às quatro rodas')
, ('3', 'Velocipede')
, ('4', 'Pedonal')
, ('5', 'Autocarro público');


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_equipamento_coletivo (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_equipamento_coletivo_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_equipamento_coletivo (identificador, descricao) VALUES
('1', 'Educação e investigação'), ('1.1', 'Creche, infantário ou ensino pré-escolar'), ('1.2', 'Ensino básico ou secundário'), ('1.3', 'Ensino superior e investigação'), ('1.4', 'Serviços de apoio - Educação e investigação'), ('1.5', 'Outros - Educação e investigação')
, ('2', 'Saúde'), ('2.1', 'Hospital'), ('2.2', 'Centro de saúde'), ('2.100', 'Outro - saúde')
, ('3', 'Ação social')
, ('4', 'Segurança e ordem pública'), ('4.1', 'Proteção civil e bombeiros'), ('4.2', 'Forças de segurança')
, ('5', 'Defesa')
, ('6', 'Justiça'), ('6.1', 'Tribunal'), ('6.2', 'Estabelecimento prisional')
, ('7', 'Desporto e lazer'), ('7.1', 'Parque e jardim'), ('7.2', 'Área verde'), ('7.3', 'Campo de golfe'), ('7.4', 'Outro – desporto e lazer'), ('7.5', 'Parque infantil')
, ('8', 'Cemitério')
, ('9', 'Centro cívico');


CREATE TABLE IF NOT EXISTS {schema}.valor_tipo_servico (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_servico_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_tipo_servico (identificador, descricao) VALUES
('1', 'Abastecimento de combustível')
, ('2', 'Carregamento elétrico')
, ('3', 'Loja de conveniência')
, ('4', 'Restauração')
, ('5', 'Estacionamento para veículos ligeiros')
, ('6', 'Estacionamento para veículos pesados')
, ('7', 'Estacionamento para caravanas')
, ('8', 'Apoio automóvel')
, ('9', 'Parque infantil')
, ('10', 'Instalações sanitárias')
, ('11', 'Duche')
, ('12', 'Área de piquenique')
, ('13', 'Estacionamento mobilidade condicionada')
, ('14', 'Estacionamento para velocípedes')
, ('15', 'Estacionamento para motociclos')
, ('995', 'Não aplicável');


CREATE TABLE IF NOT EXISTS {schema}.valor_utilizacao_atual (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_utilizacao_atual_pkey PRIMARY KEY (identificador)
);
INSERT INTO {schema}.valor_utilizacao_atual (identificador, descricao) VALUES
('1', 'Habitação'), ('1.1', 'Residencial'), ('1.2', 'Asssociado à residencia')
, ('2', 'Agricultura e pescas'), ('2.1', 'Agricultura'), ('2.2', 'Floresta'), ('2.3', 'Pesca e aquicultura')
, ('3', 'Indústria')
, ('4', 'Comércio'), ('4.1', 'Pequena loja'), ('4.2', 'Mercado'), ('4.3', 'Centro comercial'), ('4.4', 'Grande loja'), ('4.5', 'Armazém')
, ('5', 'Alojamento e restauração'), ('5.1', 'Alojamento'), ('5.2', 'Edifício de apoio ao alojamento'), ('5.3', 'Restauração')
, ('6', 'Transportes'), ('6.1', 'Transporte aéreo'), ('6.1.1', 'Terminal aéreo'), ('6.1.2', 'Torre de controlo')
, ('6.2', 'Transporte ferroviário'), ('6.2.1', 'Estação'), ('6.2.2', 'Apeadeiro')
, ('6.3', 'Transporte por via navegável'), ('6.3.1', 'Terminal marítimo ou fluvial'), ('6.3.2', 'Centro de controlo')
, ('6.4', 'Transporte rodoviário'), ('6.4.1', 'Abrigo de passageiros'), ('6.4.2', 'Terminal rodoviário'), ('6.4.3', 'Parque de estacionamento em edifício')
, ('6.5', 'Elevador ou ascensor'), ('6.6', 'Outro - Transportes')
, ('7', 'Serviços'), ('7.1', 'Serviços da Administração Pública'), ('7.2', 'Serviços de utilização coletiva'), ('7.3', 'Outros - Serviços')
, ('8', 'Serviços coletivos sociais e pessoais'), ('8.1', 'Atividades associativas'), ('8.2', 'Culto e inumação'), ('8.3', 'Atividades recreativas e culturais'), ('8.4', 'Atividades desportivas e de lazer')
, ('9', 'Organismos internacionais');


CREATE TABLE IF NOT EXISTS {schema}.lig_adm_publica_edificio (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	adm_publica_id uuid NOT NULL,
	edificio_id uuid NOT NULL,
	CONSTRAINT adm_publica_id_edificio_id_uk UNIQUE (adm_publica_id, edificio_id),
	CONSTRAINT lig_adm_publica_edificio_pkey PRIMARY KEY (identificador)
);

CREATE TABLE IF NOT EXISTS {schema}.lig_equip_util_coletiva_edificio (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	equip_util_coletiva_id uuid NOT NULL,
	edificio_id uuid NOT NULL,
	CONSTRAINT equip_util_coletiva_id_edificio_id_uk UNIQUE (equip_util_coletiva_id, edificio_id),
	CONSTRAINT lig_equip_util_coletiva_edificio_pkey PRIMARY KEY (identificador)
);

CREATE TABLE IF NOT EXISTS {schema}.lig_infratransferrov_notransferrov (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	infra_trans_ferrov_id uuid NOT NULL,
	no_trans_ferrov_id uuid NOT NULL,
	CONSTRAINT infra_trans_ferrov_id_no_trans_ferrov_id_uk UNIQUE (infra_trans_ferrov_id, no_trans_ferrov_id),
	CONSTRAINT lig_infratransferrov_notransferrov_pkey PRIMARY KEY (identificador)
);

CREATE TABLE IF NOT EXISTS {schema}.lig_infratransrodov_notransrodov (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	infra_trans_rodov_id uuid NOT NULL,
	no_trans_rodov_id uuid NOT NULL,
	CONSTRAINT infra_trans_rodov_id_no_trans_rodov_id_uk UNIQUE (infra_trans_rodov_id, no_trans_rodov_id),
	CONSTRAINT lig_infratransrodov_notransrodov_pkey PRIMARY KEY (identificador)
);

CREATE TABLE IF NOT EXISTS {schema}.lig_segviaferrea_linhaferrea (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	seg_via_ferrea_id uuid NOT NULL,
	linha_ferrea_id uuid NOT NULL,
	CONSTRAINT lig_segviaferrea_linhaferrea_pkey PRIMARY KEY (identificador),
	CONSTRAINT seg_via_ferrea_id_linha_ferrea_id_uk UNIQUE (seg_via_ferrea_id, linha_ferrea_id)
);

CREATE TABLE IF NOT EXISTS {schema}.lig_segviarodov_viarodov (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	seg_via_rodov_id uuid NOT NULL,
	via_rodov_id uuid NOT NULL,
	CONSTRAINT lig_segviarodov_viarodov_pkey PRIMARY KEY (identificador),
	CONSTRAINT seg_via_rodov_id_via_rodov_id_uk UNIQUE (seg_via_rodov_id, via_rodov_id)
);

CREATE TABLE IF NOT EXISTS {schema}.lig_segviarodov_viarodovlimite (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	seg_via_rodov_id uuid NOT NULL,
	via_rodov_limite_id uuid NOT NULL,
	CONSTRAINT lig_segviarodov_viarodovlimite_pkey PRIMARY KEY (identificador),
	CONSTRAINT seg_via_rodov_id_via_rodov_limite_id_uk UNIQUE (seg_via_rodov_id, via_rodov_limite_id)
);

CREATE TABLE IF NOT EXISTS {schema}.lig_valor_tipo_circulacao_seg_via_rodov (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	seg_via_rodov_id uuid NOT NULL,
	valor_tipo_circulacao_id varchar(10) NOT NULL,
	CONSTRAINT lig_valor_tipo_circulacao_seg_via_rodov_pkey PRIMARY KEY (identificador),
	CONSTRAINT seg_via_rodov_id_valor_tipo_circulacao_id_uk UNIQUE (seg_via_rodov_id, valor_tipo_circulacao_id)
);

CREATE TABLE IF NOT EXISTS {schema}.lig_valor_tipo_equipamento_coletivo_equip_util_coletiva (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	equip_util_coletiva_id uuid NOT NULL,
	valor_tipo_equipamento_coletivo_id varchar(10) NOT NULL,
	CONSTRAINT equip_util_coletiva_id_valor_tipo_equipamento_coletivo_id_uk UNIQUE (equip_util_coletiva_id, valor_tipo_equipamento_coletivo_id),
	CONSTRAINT lig_valor_tipo_equipamento_coletivo_equip_util_coletiva_pkey PRIMARY KEY (identificador)
);

CREATE TABLE IF NOT EXISTS {schema}.lig_valor_tipo_servico_infra_trans_rodov (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	infra_trans_rodov_id uuid NOT NULL,
	valor_tipo_servico_id varchar(10) NOT NULL,
	CONSTRAINT infra_trans_rodov_id_valor_tipo_servico_id_uk UNIQUE (infra_trans_rodov_id, valor_tipo_servico_id),
	CONSTRAINT lig_valor_tipo_servico_infra_trans_rodov_pkey PRIMARY KEY (identificador)
);

CREATE TABLE IF NOT EXISTS {schema}.lig_valor_utilizacao_atual_edificio (
	identificador uuid DEFAULT uuid_generate_v1mc() NOT NULL,
	edificio_id uuid NOT NULL,
	valor_utilizacao_atual_id varchar(10) NOT NULL,
	CONSTRAINT edificio_id_valor_utilizacao_atual_id_uk UNIQUE (edificio_id, valor_utilizacao_atual_id),
	CONSTRAINT lig_valor_utilizacao_atual_edificio_pkey PRIMARY KEY (identificador)
);


ALTER TABLE {schema}.lig_adm_publica_edificio ADD CONSTRAINT localizacao_servico_publico_1 FOREIGN KEY (edificio_id) REFERENCES {schema}.edificio(identificador) ON DELETE CASCADE;
ALTER TABLE {schema}.lig_adm_publica_edificio ADD CONSTRAINT localizacao_servico_publico_2 FOREIGN KEY (adm_publica_id) REFERENCES {schema}.adm_publica(identificador) ON DELETE CASCADE;

ALTER TABLE {schema}.lig_equip_util_coletiva_edificio ADD CONSTRAINT localizacao_equip_util_coletiva_1 FOREIGN KEY (edificio_id) REFERENCES {schema}.edificio(identificador) ON DELETE CASCADE;
ALTER TABLE {schema}.lig_equip_util_coletiva_edificio ADD CONSTRAINT localizacao_equip_util_coletiva_2 FOREIGN KEY (equip_util_coletiva_id) REFERENCES {schema}.equip_util_coletiva(identificador) ON DELETE CASCADE;

ALTER TABLE {schema}.lig_infratransferrov_notransferrov ADD CONSTRAINT lig_infratransferrov_notransferrov_1 FOREIGN KEY (no_trans_ferrov_id) REFERENCES {schema}.no_trans_ferrov(identificador) ON DELETE CASCADE;
ALTER TABLE {schema}.lig_infratransferrov_notransferrov ADD CONSTRAINT lig_infratransferrov_notransferrov_2 FOREIGN KEY (infra_trans_ferrov_id) REFERENCES {schema}.infra_trans_ferrov(identificador) ON DELETE CASCADE;

ALTER TABLE {schema}.lig_infratransrodov_notransrodov ADD CONSTRAINT lig_infratransrodov_notransrodov_1 FOREIGN KEY (no_trans_rodov_id) REFERENCES {schema}.no_trans_rodov(identificador) ON DELETE CASCADE;
ALTER TABLE {schema}.lig_infratransrodov_notransrodov ADD CONSTRAINT lig_infratransrodov_notransrodov_2 FOREIGN KEY (infra_trans_rodov_id) REFERENCES {schema}.infra_trans_rodov(identificador) ON DELETE CASCADE;

ALTER TABLE {schema}.lig_segviaferrea_linhaferrea ADD CONSTRAINT lig_segviaferrea_linhaferrea_1 FOREIGN KEY (seg_via_ferrea_id) REFERENCES {schema}.seg_via_ferrea(identificador) ON DELETE CASCADE;
ALTER TABLE {schema}.lig_segviaferrea_linhaferrea ADD CONSTRAINT lig_segviaferrea_linhaferrea_2 FOREIGN KEY (linha_ferrea_id) REFERENCES {schema}.linha_ferrea(identificador) ON DELETE CASCADE;

ALTER TABLE {schema}.lig_segviarodov_viarodov ADD CONSTRAINT lig_segviarodov_viarodov_1 FOREIGN KEY (seg_via_rodov_id) REFERENCES {schema}.seg_via_rodov(identificador) ON DELETE CASCADE;
ALTER TABLE {schema}.lig_segviarodov_viarodov ADD CONSTRAINT lig_segviarodov_viarodov_2 FOREIGN KEY (via_rodov_id) REFERENCES {schema}.via_rodov(identificador) ON DELETE CASCADE;

ALTER TABLE {schema}.lig_segviarodov_viarodovlimite ADD CONSTRAINT lig_segviarodov_viarodovlimite_1 FOREIGN KEY (via_rodov_limite_id) REFERENCES {schema}.via_rodov_limite(identificador) ON DELETE CASCADE;
ALTER TABLE {schema}.lig_segviarodov_viarodovlimite ADD CONSTRAINT lig_segviarodov_viarodovlimite_2 FOREIGN KEY (seg_via_rodov_id) REFERENCES {schema}.seg_via_rodov(identificador) ON DELETE CASCADE;

ALTER TABLE {schema}.lig_valor_tipo_circulacao_seg_via_rodov ADD CONSTRAINT valor_tipo_circulacao_seg_via_rodov_seg_via_rodov FOREIGN KEY (seg_via_rodov_id) REFERENCES {schema}.seg_via_rodov(identificador) ON DELETE CASCADE;
ALTER TABLE {schema}.lig_valor_tipo_circulacao_seg_via_rodov ADD CONSTRAINT valor_tipo_circulacao_seg_via_rodov_valor_tipo_circulacao FOREIGN KEY (valor_tipo_circulacao_id) REFERENCES {schema}.valor_tipo_circulacao(identificador);

ALTER TABLE {schema}.lig_valor_tipo_equipamento_coletivo_equip_util_coletiva ADD CONSTRAINT lig_valor_tipo_equipamento_coletivo_equip_util_coletiva_1 FOREIGN KEY (equip_util_coletiva_id) REFERENCES {schema}.equip_util_coletiva(identificador) ON DELETE CASCADE;
ALTER TABLE {schema}.lig_valor_tipo_equipamento_coletivo_equip_util_coletiva ADD CONSTRAINT lig_valor_tipo_equipamento_coletivo_equip_util_coletiva_2 FOREIGN KEY (valor_tipo_equipamento_coletivo_id) REFERENCES {schema}.valor_tipo_equipamento_coletivo(identificador);

ALTER TABLE {schema}.lig_valor_tipo_servico_infra_trans_rodov ADD CONSTRAINT valor_tipo_servico_infra_trans_rodov_infra_trans_rodov FOREIGN KEY (infra_trans_rodov_id) REFERENCES {schema}.infra_trans_rodov(identificador) ON DELETE CASCADE;
ALTER TABLE {schema}.lig_valor_tipo_servico_infra_trans_rodov ADD CONSTRAINT valor_tipo_servico_infra_trans_rodov_valor_tipo_servico FOREIGN KEY (valor_tipo_servico_id) REFERENCES {schema}.valor_tipo_servico(identificador);

ALTER TABLE {schema}.lig_valor_utilizacao_atual_edificio ADD CONSTRAINT lig_valor_utilizacao_atual_edificio_edificio FOREIGN KEY (edificio_id) REFERENCES {schema}.edificio(identificador) ON DELETE CASCADE;
ALTER TABLE {schema}.lig_valor_utilizacao_atual_edificio ADD CONSTRAINT lig_valor_utilizacao_atual_edificio_valor_utilizacao_atual FOREIGN KEY (valor_utilizacao_atual_id) REFERENCES {schema}.valor_utilizacao_atual(identificador);
