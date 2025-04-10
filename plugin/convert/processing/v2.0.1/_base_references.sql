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

--
-- Toponimia
--
create table if not exists {schema}.valor_local_nomeado (
	identificador varchar(10) not null,
	descricao varchar(255) not null,
	constraint valor_local_nomeado_pkey primary key (identificador)
);
insert into {schema}.valor_local_nomeado (identificador, descricao) values
('1','Capital do País')
, ('2','Sede administrativa de Região Autónoma')
, ('3','Capital de Distrito')
, ('4','Sede de Município')
, ('5','Sede de Freguesia')
, ('6','Forma de relevo'), ('6.1','Serra'), ('6.2','Cabo'), ('6.3','Ria'), ('6.4','Pico'), ('6.5','Península'), ('6.6','Baía'), ('6.7','Enseada'), ('6.8','Ínsua'), ('6.9','Dunas'), ('6.10','Fajã'), ('6.11','Lombo'), ('6.12','Achada'), ('6.13','Vale')
, ('7','Lugar'), ('7.1','Cidade'), ('7.2','Vila'), ('7.3','Outro aglomerado')
, ('8','Designação local')
, ('9','Área protegida')
, ('10','Praia')
, ('11','Oceano')
, ('12','Arquipélago')
, ('13','Ilha')
, ('14','Ilhéu')
, ('15','Outro local nomeado');

create table if not exists {schema}.designacao_local (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_local_nomeado varchar(10) NOT NULL,
	nome varchar(255) NOT NULL,
	geometria geometry(POINT, 3763) NOT NULL,
	CONSTRAINT designacao_local_pkey PRIMARY KEY (identificador),
	CONSTRAINT valor_local_nomeado_id FOREIGN KEY (valor_local_nomeado) REFERENCES {schema}.valor_local_nomeado(identificador)
);

--
-- Ocupacao de Solo
--
create table if not exists {schema}.valor_areas_agricolas_florestais_matos (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_areas_agricolas_florestais_matos_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_areas_agricolas_florestais_matos VALUES
, ('1','Agricultura'), ('1.1','Cultura temporária de sequeiro e regadio'), ('1.2','Arrozal'), ('1.3','Vinha'), ('1.4','Pomar'), ('1.5','Olival'), ('1.6','Bananal'), ('1.7','Misto de culturas permanentes'), ('1.8','Outras culturas permanentes')
, ('2','Pastagem'), ('2.1','Pastagem permanente'), ('2.2','Vegetação herbácea natural')
, ('3','Sistema agroflorestal')
, ('4','Floresta'), ('4.1','Floresta de folhosas'), ('4.1.1','Sobreiro'), ('4.1.2','Azinheira'), ('4.1.3','Carvalho'), ('4.1.4','Castanheiro'), ('4.1.5','Eucalipto'), ('4.1.6','Espécie invasora'), ('4.1.7','Outras folhosas')
, ('4.2','Floresta de resinosas'), ('4.2.1','Pinheiro manso'), ('4.2.2','Pinheiro bravo'), ('4.2.3','Outras resinosas'), ('4.3','Floresta de Laurissilva')
, ('5','Mato');

create table if not exists {schema}.area_agricola_florestal_mato (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	valor_areas_agricolas_florestais_matos varchar(10) NOT NULL,
	nome varchar(255),
	geometria geometry(POLYGON, 3763) NOT NULL,
	CONSTRAINT area_agricola_florestal_mato_pkey PRIMARY KEY (identificador),
	CONSTRAINT valor_areas_agricolas_florestais_matos_id FOREIGN KEY (valor_areas_agricolas_florestais_matos) REFERENCES {schema}.valor_areas_agricolas_florestais_matos(identificador)
);

create table if not exists {schema}.valor_areas_artificializadas (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_areas_artificializadas_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_areas_artificializadas VALUES
('1','Área de equipamentos de saúde')
, ('2','Área de equipamentos de educação')
, ('3','Área de equipamentos industriais')
, ('4','Área de equipamentos comerciais ou de carácter geral')
, ('5','Área de deposição de resíduos')
, ('6','Área em construção')
, ('7','Área de equipamentos desportivos e de lazer')
, ('8','Área de parque de campismo')
, ('9','Área de inumação')
, ('10','Área de equipamentos de segurança e ordem pública, defesa ou justiça')
, ('11','Área de instalações agrícolas')
, ('12','Área de equipamentos culturais')
, ('13','Área de extração de inertes');
