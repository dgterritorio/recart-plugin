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
('1', 'Capital do País')
, ('2', 'Sede administrativa de Região Autónoma')
, ('3', 'Capital de Distrito')
, ('4', 'Sede de Concelho')
, ('5', 'Sede de Freguesia')
, ('6', 'Forma de relevo'), ('6.1', 'Serra'), ('6.2', 'Cabo'), ('6.3', 'Ria'), ('6.4', 'Pico'), ('6.5', 'Península'), ('6.6', 'Baía'), ('6.7', 'Enseada'), ('6.8', 'Ínsua'), ('6.9', 'Dunas'), ('6.10', 'Fajã')
, ('7', 'Lugar'), ('7.1', 'Cidade'), ('7.2', 'Vila'), ('7.3', 'Outro aglomerado')
, ('8', 'Designação local')
, ('9', 'Área protegida')
, ('10', 'Praia')
, ('11', 'Oceano')
, ('12', 'Arquipélago')
, ('13', 'Ilha')
, ('14', 'Ilhéu')
, ('15', 'Outro local nomeado')
, ('888', 'SEM DADOS');

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
('1','Agricultura'), ('1.1','Cultura temporária de sequeiro e regadio'), ('1.2','Arrozal'), ('1.3','Vinha'), ('1.4','Pomar'), ('1.5','Olival')
, ('2','Pastagem'), ('2.1','Pastagem permanente'), ('2.2','Vegetação herbácea natural')
, ('3','Sistema agroflorestal')
, ('4','Floresta'), ('4.1','Floresta de folhosas'), ('4.1.1','Sobreiro'), ('4.1.2','Azinheira'), ('4.1.3','Carvalho'), ('4.1.4','Castanheiro'), ('4.1.5','Eucalipto'), ('4.1.6','Espécie invasora'), ('4.1.7','Outras folhosas'), ('4.2','Floresta de resinosas'), ('4.2.1','Pinheiro manso'), ('4.2.2','Pinheiro bravo'), ('4.2.3','Outras resinosas')
, ('5','Mato')
, ('888', 'SEM DADOS');
create table if not exists {schema}.area_agricola_florestal_mato (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	valor_areas_agricolas_florestais_matos varchar(10) NOT NULL,
	nome varchar(255),
	geometria geometry(POLYGON, 3763) NOT NULL,
	CONSTRAINT area_agricola_florestal_mato_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_areas_artificializadas (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_areas_artificializadas_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_areas_artificializadas VALUES
('1','Equipamentos de saúde')
, ('2','Equipamentos de educação')
, ('3','Equipamentos industriais')
, ('4','Equipamentos comerciais ou de carácter geral')
, ('5','Área de deposição de resíduos')
, ('6','Área em construção')
, ('7','Instalação desportiva e de lazer')
, ('8','Parque de campismo')
, ('9','Área de inumação')
, ('888', 'SEM DADOS');
create table if not exists {schema}.areas_artificializadas (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	inst_producao_id uuid,
	inst_gestao_ambiental_id uuid,
	equip_util_coletiva_id uuid,
	valor_areas_artificializadas varchar(10) NOT NULL,
	nome varchar(255),
	geometria geometry(POLYGON, 3763) NOT NULL,
	PRIMARY KEY (identificador)
);

--
-- Altimetria
--
create table if not exists {schema}.valor_classifica (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_classifica_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_classifica (identificador, descricao) values
('1', 'Base do declive')
, ('2', 'Alteração no declive')
, ('3', 'Linha de forma')
, ('4', 'Linha de talvegue')
, ('5', 'Linha de cumeada')
, ('6', 'Topo do declive')
, ('888', 'SEM DADOS');

create table if not exists {schema}.valor_natureza_linha (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_natureza_linha_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_natureza_linha (identificador, descricao) values
('1', 'Escarpado')
, ('2', 'Talude')
, ('3', 'Socalco')
, ('4', 'Combro')
, ('888', 'SEM DADOS');
create table if not exists {schema}.linha_de_quebra (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_classifica varchar(10) NOT NULL,
	valor_natureza_linha varchar(10) NOT NULL,
	artificial bool NULL,
	geometria geometry(linestringz, 3763) NOT NULL,
	CONSTRAINT linha_de_quebra_pkey PRIMARY KEY (identificador),
	CONSTRAINT valor_classifica_id FOREIGN KEY (valor_classifica) REFERENCES {schema}.valor_classifica(identificador),
	CONSTRAINT valor_natureza_linha_id FOREIGN KEY (valor_natureza_linha) REFERENCES {schema}.valor_natureza_linha(identificador)
);

create table if not exists {schema}.valor_classifica_las (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_classifica_las_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_classifica_las (identificador, descricao) VALUES
('1', 'Terreno')
, ('2', 'Edifício'), ('2.1', 'Edifício - soleira'), ('2.2', 'Edifício - beirado'), ('2.3', 'Edifício - ponto mais alto'), ('888', 'SEM DADOS');
create table if not exists {schema}.ponto_cotado (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_classifica_las varchar(10) NOT NULL,
	geometria geometry(pointz, 3763) NOT NULL,
	CONSTRAINT ponto_cotado_pkey PRIMARY KEY (identificador),
	CONSTRAINT valor_classifica_las_id FOREIGN KEY (valor_classifica_las) REFERENCES {schema}.valor_classifica_las(identificador)
);

create table if not exists {schema}.valor_tipo_curva (
	identificador varchar(10) not null,
	descricao varchar(255) not null,
	constraint valor_tipo_curva_pkey primary key (identificador)
);
insert into {schema}.valor_tipo_curva (identificador, descricao) values
('1', 'Mestra')
, ('2', 'Secundária')
, ('3', 'Auxiliar')
, ('888', 'SEM DADOS');
create table if not exists {schema}.curva_de_nivel (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_tipo_curva varchar(10) NOT NULL,
	geometria geometry(linestringz, 3763) NOT NULL,
	CONSTRAINT curva_de_nivel_pkey PRIMARY KEY (identificador),
	CONSTRAINT valor_tipo_curva_id FOREIGN KEY (valor_tipo_curva) REFERENCES {schema}.valor_tipo_curva(identificador)
);

--
-- Mobiliario Urbano
--
create table if not exists {schema}.valor_tipo_de_mob_urbano_sinal (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_de_mob_urbano_sinal_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_de_mob_urbano_sinal VALUES
('1','Armário de semáforos')
, ('2','Banco de jardim')
, ('3','Canteiro')
, ('4','Contentor')
, ('5','Ecoponto')
, ('6','Equipamento de exercício físico ao ar livre')
, ('7','Estacionamento para velocipedes')
, ('8','Marco de correio')
, ('9','Painel publicitário')
, ('10','Papeleira')
, ('11','Parque infantil')
, ('12','Parquímetro')
, ('13','Passadeira de peões')
, ('14','Placa informativa')
, ('15','Pérgula')
, ('16','Posto de carregamento elétrico')
, ('17','Quiosque fixo')
, ('18','Sanitário público')
, ('19','Semáforo')
, ('20','Sinal de trânsito')
, ('21','Sinalização')
, ('888', 'SEM DADOS');
create table if not exists {schema}.mob_urbano_sinal (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	valor_tipo_de_mob_urbano_sinal varchar(10) NOT NULL,
	geometria geometry(GEOMETRY, 3763) NOT NULL,
	CONSTRAINT mob_urbano_sinal_pkey PRIMARY KEY (identificador)
);

--
-- Unidades Administrativas
--
create table if not exists {schema}.distrito (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	data_publicacao date NOT NULL,
	di varchar(255) NOT NULL,
	nome varchar(255) NOT NULL,
	geometria geometry(MULTIPOLYGON, 3763) NOT NULL,
	CONSTRAINT distrito_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.concelho (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	data_publicacao date NOT NULL,
	dico varchar(255) NOT NULL,
	nome varchar(255) NOT NULL,
	geometria geometry(MULTIPOLYGON, 3763) NOT NULL,
	CONSTRAINT concelho_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.freguesia (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	data_publicacao date NOT NULL,
	dicofre varchar(255) NOT NULL,
	nome varchar(255) NOT NULL,
	geometria geometry(MULTIPOLYGON, 3763) NOT NULL,
	CONSTRAINT freguesia_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_estado_fronteira (
	identificador varchar(10) not null,
	descricao varchar(255) not null,
	constraint valor_estado_fronteira_pkey primary key (identificador)
);
insert into {schema}.valor_estado_fronteira (identificador, descricao) values
('1', 'Definido')
, ('2', 'Por acordar')
, ('888', 'SEM DADOS');
create table if not exists {schema}.fronteira (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	valor_estado_fronteira varchar(10) NOT NULL,
	data_publicacao date NOT NULL,
	geometria geometry(LINESTRING, 3763) NOT NULL,
	CONSTRAINT fronteira_pkey PRIMARY KEY (identificador),
	CONSTRAINT valor_estado_fronteira_id FOREIGN KEY (valor_estado_fronteira) REFERENCES {schema}.valor_estado_fronteira(identificador)
);

--
-- Infrastruturas e Servicos Publicos
--
create table if not exists {schema}.valor_instalacao_gestao_ambiental (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_instalacao_gestao_ambiental_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_instalacao_gestao_ambiental VALUES
('1','Resíduos sólidos')
, ('2','Resíduos líquidos')
, ('3','Resíduos industriais')
, ('4','Resíduos tóxicos')
, ('888', 'SEM DADOS');
create table if not exists {schema}.inst_gestao_ambiental (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NOT NULL,
	valor_instalacao_gestao_ambiental varchar(10) NOT NULL,
	CONSTRAINT inst_gestao_ambiental_pkey PRIMARY KEY (identificador),
	CONSTRAINT valor_instalacao_gestao_ambiental_id FOREIGN KEY (valor_instalacao_gestao_ambiental) REFERENCES {schema}.valor_instalacao_gestao_ambiental(identificador)
);

create table if not exists {schema}.valor_instalacao_producao (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_instalacao_producao_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_instalacao_producao VALUES
('1','Pecuária'), ('1.1','Vacaria'), ('1.2','Suinicultura'), ('1.3','Aviário'), ('1.4','Matadouro')
, ('2','Adega')
, ('3','Lagar de azeite')
, ('4','Indústria extrativa'), ('4.1','Pedreira'), ('4.2','Mina'), ('4.3','Extração de inertes'), ('4.4','Salina')
, ('5','Fábrica')
, ('6','Fábrica de materiais explosivos')
, ('7','Oficina'), ('7.1','Oficina em geral'), ('7.2','Oficina de pirotecnia'), ('7.3','Oficina de reparação automóvel')
, ('8','Estaleiro naval')
, ('9','Armazém')
, ('10','Estação de emissão ou receção')
, ('11','Aquicultura')
, ('12','Parque de sucata')
, ('888', 'SEM DADOS');
create table if not exists {schema}.inst_producao (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NOT NULL,
	descricao_da_funcao varchar(255) NULL,
	valor_instalacao_producao varchar(10) NOT NULL,
	CONSTRAINT inst_producao_pkey PRIMARY KEY (identificador),
	CONSTRAINT valor_instalacao_producao_id FOREIGN KEY (valor_instalacao_producao) REFERENCES {schema}.valor_instalacao_producao(identificador)
);

create table if not exists {schema}.valor_conduta_agua (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_conduta_agua_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_conduta_agua VALUES
('1','Aqueduto')
, ('2','Conduta')
, ('3','Valeta')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_posicao_vertical (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_posicao_vertical_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_posicao_vertical VALUES
('1','Suspenso ou elevado')
, ('0','Ao nível do solo')
, ('-1','No subsolo')
, ('888', 'SEM DADOS');
create table if not exists {schema}.conduta_de_agua (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	diametro real,
	valor_conduta_agua varchar(10) NOT NULL,
	valor_posicao_vertical varchar(10) NOT NULL,
	geometria geometry(LINESTRING, 3763) not null,
	CONSTRAINT conduta_de_agua_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_elemento_associado_pgq (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_elemento_associado_pgq_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_elemento_associado_pgq VALUES
('1','Petróleo ou derivados')
, ('2','Gás'), ('2.1','Estação da RNTGN'), ('2.1.1','Estação de seccionamento'), ('2.1.2','Estação de derivação'), ('2.1.3','Estação de redução e medição de gás'), ('2.1.4','Ponto de entrega'), ('2.2','Instalação de armazenamento subterrâneo de gás natural'), ('2.3','Terminal de GNL'), ('2.4','Unidade autónoma de gás natural (UAG)')
, ('3','Substâncias químicas')
, ('888', 'SEM DADOS');
create table if not exists {schema}.elem_assoc_pgq (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	valor_elemento_associado_pgq varchar(10) NOT NULL,
	geometria geometry(GEOMETRY, 3763) not null,
	CONSTRAINT elem_assoc_pgq_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_gasoduto_oleoduto_sub_quimicas (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_gasoduto_oleoduto_sub_quimicas_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_gasoduto_oleoduto_sub_quimicas VALUES
('1','Gasoduto'), ('1.1','Gasoduto de 1º escalão'), ('1.2','Gasoduto de 2º escalão'), ('1.3','Gasoduto de 3º escalão')
, ('2','Oleoduto')
, ('3','Outros produtos')
, ('888', 'SEM DADOS');
create table if not exists {schema}.oleoduto_gasoduto_subtancias_quimicas (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	diametro real,
	valor_gasoduto_oleoduto_sub_quimicas varchar(10) NOT NULL,
	valor_posicao_vertical varchar(10) NOT NULL,
	geometria geometry(LINESTRING, 3763) not null,
	CONSTRAINT oleoduto_gasoduto_subtancias_quimicas_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_elemento_associado_telecomunicacoes (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_elemento_associado_telecomunicacoes_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_elemento_associado_telecomunicacoes VALUES
('1','Poste telefónico')
, ('2','Cabina telefónica')
, ('3','Antena')
, ('888', 'SEM DADOS');
create table if not exists {schema}.elem_assoc_telecomunicacoes (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	valor_elemento_associado_telecomunicacoes varchar(10) NOT NULL,
	geometria geometry(POINT, 3763) not null,
	CONSTRAINT elem_assoc_telecomunicacoes_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_tipo_adm_publica (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_adm_publica_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_adm_publica VALUES
('1','Assembleia da República, Assembleia Regional')
, ('2','Ministério, Gabinete do Secretário de Estado; Secretária-geral')
, ('3','Câmara Municipal, Assembleia Municipal')
, ('4','Junta de Freguesia')
, ('5','Outro - Administração pública')
, ('888', 'SEM DADOS');
create table if not exists {schema}.adm_publica (
	identificador uuid not null default uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone not null,
	fim_objeto timestamp without time zone,
	nome varchar(255) not null,
	ponto_de_contacto varchar(255),
	valor_tipo_adm_publica varchar(255) not null,
	constraint adm_publica_pk primary key (identificador)
);

create table if not exists {schema}.valor_tipo_equipamento_coletivo (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	constraint valor_tipo_equipamento_coletivo_pk PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_equipamento_coletivo VALUES
('1','Educação e investigação'), ('1.1','Creche, infantário ou ensino pré-escolar'), ('1.2','Ensino básico ou secundário'), ('1.3','Ensino superior e investigação'), ('1.4','Serviços de apoio - Educação e investigação'), ('1.5','Outros - Educação e investigação')
, ('2','Saúde'), ('2.1','Hospital'), ('2.2','Centro de saúde'), ('2.3','Outro - saúde')
, ('3','Ação social')
, ('4','Segurança e ordem pública'), ('4.1','Proteção civil e bombeiros'), ('4.2','Forças de segurança')
, ('5','Defesa')
, ('6','Justiça'), ('6.1','Tribunal'), ('6.2','Estabelecimento prisional')
, ('7','Desporto e lazer'), ('7.1','Parque e jardim'), ('7.2','Área verde'), ('7.3','Campo de golfe'), ('7.4','Outro – desporto e lazer')
, ('8','Cemitério')
, ('888', 'SEM DADOS');
create table if not exists {schema}.equip_util_coletiva (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp NOT NULL,
	fim_objeto timestamp NULL,
	nome varchar(255) NOT NULL,
	ponto_de_contacto varchar(255) NULL,
	CONSTRAINT equip_util_coletiva_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_elemento_associado_agua (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_elemento_associado_agua_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_elemento_associado_agua VALUES
('1','Marco de incêndio')
, ('2','Estação elevatória')
, ('3','Estação de tratamento')
, ('4','Fonte')
, ('5','Poço')
, ('6','Furo')
, ('7','Reservatório de água')
, ('8','Nora')
, ('9','Estrutura de captação de água')
, ('10','Câmara de visita')
, ('11','Sumidouro')
, ('12','Sarjeta')
, ('888', 'SEM DADOS');
create table if not exists {schema}.elem_assoc_agua (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	valor_elemento_associado_agua varchar(10) NOT NULL,
	geometria geometry(GEOMETRY, 3763) not null,
	CONSTRAINT elem_assoc_agua_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_elemento_associado_electricidade (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_elemento_associado_electricidade_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_elemento_associado_electricidade VALUES
('1','Central de produção elétrica'), ('1.1','Central hidroelétrica'), ('1.2','Central fotovoltaica'), ('1.3','Central eólica'), ('1.4','Central termoelétrica')
, ('2','Subestação elétrica')
, ('3','Aeromotor')
, ('4','Gerador eólico')
, ('5','Painel solar fotovoltaico')
, ('6','Apoio de iluminação'), ('6.1','Apoio isolado de iluminação'), ('6.2','Apoio de iluminação e baixa tensão')
, ('7','Apoio de eletricidade'), ('7.1','Apoio de alta tensão'), ('7.2','Apoio de média tensão'), ('7.3','Apoio de baixa tensão'), ('7.4','Apoio de muito alta tensão')
, ('8','Posto transformador')
, ('9','Posto de transformação aéreo')
, ('888', 'SEM DADOS');
create table if not exists {schema}.elem_assoc_eletricidade (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	valor_elemento_associado_electricidade varchar(10) NOT NULL,
	geometria geometry(GEOMETRY, 3763) not null,
	CONSTRAINT elem_assoc_eletricidade_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_designacao_tensao (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_designacao_tensao_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_designacao_tensao VALUES
('1','Muito alta')
, ('2','Alta')
, ('3','Média')
, ('4','Baixa')
, ('888', 'SEM DADOS');
create table if not exists {schema}.cabo_electrico (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	tensao_nominal real,
	valor_designacao_tensao varchar(10) NOT NULL,
	valor_posicao_vertical varchar(10) NOT NULL,
	geometria geometry(LINESTRING, 3763) not null,
	CONSTRAINT cabo_electrico_pkey PRIMARY KEY (identificador)
);

--
-- Construcoes
--
create table if not exists {schema}.valor_local_geodesico (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_local_geodesico_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_local_geodesico VALUES
('1','Igreja')
, ('2','Catavento')
, ('3','Construção')
, ('4','Moinho')
, ('5','Cruzeiro')
, ('6','Castelo')
, ('7','Depósito elevado')
, ('8','Farol')
, ('9','Posto de vigia')
, ('10','Para-raios')
, ('11','Terreno')
, ('995','Não aplicável')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_ordem (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_ordem_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_ordem VALUES
('1','Primeira')
, ('2','Segunda ou terceira')
, ('995','Não aplicável')
, ('888', 'SEM DADOS');

create table if not exists {schema}.valor_tipo_sinal_geodesico (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_sinal_geodesico_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_sinal_geodesico VALUES
('1','Estação Permanente')
, ('2','Vértice Geodésico')
, ('3','Marca de Nivelamento')
, ('4','Marégrafo')
, ('5','Estação Gravimétrica')
, ('888', 'SEM DADOS');
create table if not exists {schema}.sinal_geodesico (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	data_revisao date NOT NULL,
	nome varchar(255),
	valor_local_geodesico varchar(10) NOT NULL,
	valor_ordem varchar(10) NOT NULL,
	valor_tipo_sinal_geodesico varchar(10) NOT NULL,
	geometria geometry(pointz, 3763) not null,
	CONSTRAINT sinal_geodesico_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_construcao_linear (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_construcao_linear_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_construcao_linear VALUES
('1','Muro de alvenaria ou betão')
, ('2','Muro de pedra')
, ('3','Sebe')
, ('4','Gradeamento ou vedação')
, ('5','Muralha')
, ('6','Portão')
, ('7','Barreira acústica')
, ('8','Pista')
, ('9','Lancil')
, ('888', 'SEM DADOS');
create table if not exists {schema}.constru_linear (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	nome varchar(255),
	suporte bool NOT NULL,
	valor_construcao_linear varchar(10) NOT NULL,
	largura real,
	geometria geometry(LINESTRING, 3763) not null,
	CONSTRAINT constru_linear_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_tipo_construcao (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_construcao_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_construcao VALUES
('1','Molhe')
, ('2','Pontão')
, ('3','Piscina')
, ('4','Tanque')
, ('5','Campo de jogos')
, ('6','Lago de jardim')
, ('7','Escadaria')
, ('8','Bancada')
, ('9','Passeio')
, ('10','Limite da construção linear')
, ('11','Rampa de acesso')
, ('888', 'SEM DADOS');
create table if not exists {schema}.constru_polig (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	nome varchar(255),
	valor_tipo_construcao varchar(10) NOT NULL,
	geometria geometry(GEOMETRY, 3763) not null,
	CONSTRAINT constru_polig_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_tipo_ponto_interesse (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_ponto_interesse_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_ponto_interesse VALUES
('1','Alminha')
, ('2','Anta')
, ('3','Árvore')
, ('4','Árvore classificada')
, ('5','Castro')
, ('6','Cruzeiro')
, ('7','Estátua')
, ('8','Menir')
, ('9','Miradouro')
, ('10','Padrão')
, ('11','Pelourinho')
, ('12','Ruínas com interesse histórico')
, ('13','Outro')
, ('888', 'SEM DADOS');
create table if not exists {schema}.ponto_interesse (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	nome varchar(255),
	valor_tipo_ponto_interesse varchar(10) NOT NULL,
	geometria geometry(GEOMETRY, 3763) not null,
	CONSTRAINT ponto_interesse_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.edificio (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inst_producao_id uuid,
	inst_gestao_ambiental_id uuid,
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	altura_edificio real NOT NULL,
	data_const date,
	valor_condicao_const varchar(10),
	valor_elemento_edificio_xy varchar(10) NOT NULL,
	valor_elemento_edificio_z varchar(10) NOT NULL,
	valor_forma_edificio varchar(10),
	geometria geometry(GEOMETRY, 3763) not null,
	import_ref varchar(255) null,
	CONSTRAINT edificio_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.nome_edificio (
	identificador uuid not null default uuid_generate_v1mc(),
	edificio_id uuid not null,
	nome varchar(255) not null,
	constraint nome_edificio_pk primary key (identificador),
	constraint nome_edificio_id_edificio_id foreign key (edificio_id) references {schema}.edificio(identificador)
);
create table if not exists {schema}.numero_policia_edificio (
	identificador uuid not null default uuid_generate_v1mc(),
	edificio_id uuid not null,
	numero_policia varchar(255) not null,
	constraint numero_policia_edificio_pkey primary key (identificador),
	constraint numero_policia_edificio_id_edificio_id foreign key (edificio_id) references {schema}.edificio(identificador)
);
create table if not exists {schema}.valor_condicao_const (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_condicao_const_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_condicao_const (identificador, descricao) values
('1', 'Demolido')
, ('2', 'Desafetado')
, ('3', 'Em construção')
, ('4', 'Projetado')
, ('5', 'Ruína')
, ('6', 'Funcional')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_elemento_edificio_xy (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_elemento_edificio_xy_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_elemento_edificio_xy (identificador, descricao) values
('1', 'Combinado')
, ('2', 'Ponto de entrada')
, ('3', 'Invólucro')
, ('4', 'Implantação')
, ('5', 'Piso mais baixo acima do solo')
, ('6', 'Beira do telhado')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_elemento_edificio_z (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_elemento_edificio_z_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_elemento_edificio_z (identificador, descricao) values
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
, ('16', 'Ponto mais baixo no solo')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_forma_edificio (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_forma_edificio_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_forma_edificio (identificador, descricao) VALUES
('1', 'Anfiteatro ao ar livre')
, ('2', 'Arco')
, ('3', 'Azenha')
, ('4', 'Barraca')
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
, ('26', 'Depósito de armazenamento')
, ('27', 'Telheiro')
, ('28', 'Templo')
, ('29', 'Torre')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_utilizacao_atual (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_utilizacao_atual_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_utilizacao_atual (identificador, descricao) values
('1', 'Habitação'), ('1.1', 'Residencial'), ('1.2', 'Associado à residencia')
, ('2', 'Agricultura e pescas'), ('2.1', 'Agricultura'), ('2.2', 'Floresta'), ('2.3', 'Pesca e aquicultura')
, ('3', 'Indústria')
, ('4', 'Comércio'), ('4.1', 'Comércio tradicional'), ('4.2', 'Mercado'), ('4.3', 'Centro comercial'), ('4.4', 'Grande loja')
, ('5', 'Alojamento e restauração'), ('5.1', 'Alojamento'), ('5.2', 'Edifício de apoio ao alojamento'), ('5.3', 'Restauração')
, ('6', 'Transportes'), ('6.1', 'Transporte aéreo'), ('6.1.1', 'Terminal aéreo'), ('6.1.2', 'Torre de controlo')
, ('6.2', 'Transporte ferroviário'), ('6.2.1', 'Estação'), ('6.2.2', 'Apeadeiro')
, ('6.3', 'Transporte por via navegável'), ('6.3.1', 'Terminal marítimo ou fluvial'), ('6.3.2', 'Centro de controlo')
, ('6.4', 'Transporte rodoviário'), ('6.4.1', 'Paragem rodoviária'), ('6.4.2', 'Terminal rodoviário'), ('6.4.3', 'Parque de estacionamento em edifício')
, ('6.5', 'Elevador ou ascensor')
, ('6.6', 'Outro - Transportes')
, ('7', 'Serviços'), ('7.1', 'Serviços da Administração Pública'), ('7.2', 'Serviços de utilização coletiva'), ('7.3', 'Outros - Serviços')
, ('8', 'Serviços coletivos sociais e pessoais'), ('8.1', 'Atividades associativas'), ('8.2', 'Culto e inumação'), ('8.3', 'Atividades recreativas e culturais'), ('8.4', 'Atividades desportivas e de lazer')
, ('9', 'Organismos internacionais')
, ('888', 'SEM DADOS');

--
-- Transporte
--
create table if not exists {schema}.valor_posicao_vertical_transportes (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_posicao_vertical_transportes_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_posicao_vertical_transportes VALUES
('3','Suspenso ou elevado: nível acima do nível 2')
,('2','Suspenso ou elevado: nível 2, acima de nível 1')
,('1','Suspenso ou elevado: nível 1')
,('0','Ao nível do solo')
,('-1','No subsolo: nível -1')
,('-2','No subsolo: nível mais profundo que nível -1')
,('-3','No subsolo: nível mais profundo que nível -2')
, ('888', 'SEM DADOS');

-- Transporte por Cabo
create table if not exists {schema}.area_infra_trans_cabo (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	geometria geometry(POLYGON, 3763) not null,
	PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_tipo_via_cabo (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_via_cabo_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_via_cabo VALUES
('1','Cabina')
, ('2','Cadeira')
, ('3','Teleski')
, ('888', 'SEM DADOS');
create table if not exists {schema}.seg_via_cabo (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	nome varchar(255),
	valor_tipo_via_cabo varchar(10),
	geometria geometry(LINESTRING, 3763) not null,
	CONSTRAINT seg_via_cabo_pkey PRIMARY KEY (identificador)
);

-- Transporte por Via Navegavel
create table if not exists {schema}.valor_tipo_area_infra_trans_via_navegavel (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_area_infra_trans_via_navegavel_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_area_infra_trans_via_navegavel VALUES
('1','Área do porto')
, ('2','Área do cais')
, ('3','Área da doca')
, ('888', 'SEM DADOS');
create table if not exists {schema}.area_infra_trans_via_navegavel (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	valor_tipo_area_infra_trans_via_navegavel varchar(10) NOT NULL,
	geometria geometry(POLYGON, 3763) not null,
	CONSTRAINT area_infra_trans_via_navegavel_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_tipo_infra_trans_via_navegavel (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_infra_trans_via_navegavel_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_infra_trans_via_navegavel VALUES
('1','Porto')
, ('2','Cais')
, ('3','Doca')
, ('888', 'SEM DADOS');
create table if not exists {schema}.infra_trans_via_navegavel (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	nome varchar(255) NOT NULL,
	codigo_via_navegavel varchar(255),
	valor_tipo_infra_trans_via_navegavel varchar(10) NOT NULL,
	geometria geometry(POINT, 3763) not null,
	CONSTRAINT infra_trans_via_navegavel_pkey PRIMARY KEY (identificador)
);

-- Transporte por Aereo
create table if not exists {schema}.valor_tipo_area_infra_trans_aereo (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_area_infra_trans_aereo_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_area_infra_trans_aereo VALUES
('1','Área da infraestrutura')
, ('2','Área de pista')
, ('3','Área de circulação')
, ('4','Plataforma de estacionamento')
, ('888', 'SEM DADOS');
create table if not exists {schema}.area_infra_trans_aereo (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	valor_tipo_area_infra_trans_aereo varchar(10) NOT NULL,
	geometria geometry(POLYGON, 3763) not null,
	CONSTRAINT area_infra_trans_aereo_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_categoria_infra_trans_aereo (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_categoria_infra_trans_aereo_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_categoria_infra_trans_aereo VALUES
('1','Internacional')
, ('2','Nacional')
, ('3','Regional')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_restricao_infra_trans_aereo (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_restricao_infra_trans_aereo_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_restricao_infra_trans_aereo VALUES
('1','Fins exclusivamente militares')
, ('2','Restrições temporais')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_tipo_infra_trans_aereo (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_infra_trans_aereo_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_infra_trans_aereo VALUES
('1','Aeródromo')
, ('2','Heliporto')
, ('3','Aeródromo com heliporto')
, ('4','Local de aterragem')
, ('888', 'SEM DADOS');
create table if not exists {schema}.infra_trans_aereo (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	codigo_iata varchar(255),
	codigo_icao varchar(255),
	nome varchar(255),
	valor_categoria_infra_trans_aereo varchar(10) NOT NULL,
	valor_restricao_infra_trans_aereo varchar(10),
	valor_tipo_infra_trans_aereo varchar(10) NOT NULL,
	geometria geometry(POINT, 3763) not null,
	CONSTRAINT infra_trans_aereo_pkey PRIMARY KEY (identificador)
);

-- Transporte Ferroviario
create table if not exists {schema}.valor_categoria_bitola (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_categoria_bitola_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_categoria_bitola VALUES
('1','Ibérica')
, ('2','Europeia')
, ('3','Métrica')
, ('888', 'SEM DADOS')
, ('995','Não aplicável');
create table if not exists {schema}.valor_estado_linha_ferrea (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_estado_linha_ferrea_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_estado_linha_ferrea VALUES
('1','Desmantelada')
, ('2','Em construção')
, ('3','Em desuso')
, ('4','Projetada')
, ('5','Funcional')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_tipo_linha_ferrea (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_linha_ferrea_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_linha_ferrea VALUES
('1','Ferrovia de cremalheira')
, ('2','Funicular')
, ('3','Levitação magnética')
, ('4','Metro')
, ('5','Carril único')
, ('6','Carril único (suspenso)')
, ('7','Comboio (dois carris paralelos)')
, ('8','Elétrico')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_tipo_troco_via_ferrea (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_troco_via_ferrea_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_troco_via_ferrea VALUES
('1','Via única')
, ('2','Via dupla')
, ('3','Via múltipla')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_via_ferrea (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_via_ferrea_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_via_ferrea VALUES
('1','Plena via')
, ('2','Linha de estação')
, ('3','Linha de estacionamento')
, ('4','Linha de segurança')
, ('5','Ramal particular')
, ('888', 'SEM DADOS');
create table if not exists {schema}.seg_via_ferrea (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	eletrific bool NOT NULL,
	gestao varchar(255),
	velocidade_max int4,
	valor_categoria_bitola varchar(10) NOT NULL,
	valor_estado_linha_ferrea varchar(10),
	valor_posicao_vertical_transportes varchar(10) NOT NULL,
	valor_tipo_linha_ferrea varchar(10) NOT NULL,
	valor_tipo_troco_via_ferrea varchar(10) NOT NULL,
	valor_via_ferrea varchar(10),
	jurisdicao varchar(255),
	geometria geometry(linestringz, 3763) not null,
	CONSTRAINT seg_via_ferrea_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.linha_ferrea (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	codigo_linha_ferrea varchar(255) NOT NULL,
	nome varchar(255) NOT NULL,
	CONSTRAINT linha_ferrea_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.area_infra_trans_ferrov (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	infra_trans_ferrov_id uuid NOT NULL,
	geometria geometry(POLYGON, 3763) not null,
	constraint area_infra_trans_ferrov_pk PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_tipo_uso_infra_trans_ferrov (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	constraint valor_tipo_uso_infra_trans_ferrov_pk PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_uso_infra_trans_ferrov VALUES
('1','Passageiros')
, ('2','Mercadorias')
, ('3','Misto')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_tipo_infra_trans_ferrov (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	constraint valor_tipo_infra_trans_ferrov_pk PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_infra_trans_ferrov VALUES
('1','Estação')
, ('2','Apeadeiro')
, ('3','Outros')
, ('888', 'SEM DADOS');
create table if not exists {schema}.infra_trans_ferrov (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	codigo_infra_ferrov varchar(255),
	nome varchar(255),
	nplataformas int4,
	valor_tipo_uso_infra_trans_ferrov varchar(10),
	valor_tipo_infra_trans_ferrov varchar(10) NOT NULL,
	geometria geometry(POINT, 3763) not null,
	constraint infra_trans_ferrov_pk PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_tipo_no_trans_ferrov (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	constraint valor_tipo_no_trans_ferrov_pk PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_no_trans_ferrov VALUES
('1','Junção')
, ('2','Passagem de nível')
, ('3','Pseudo-nó')
, ('4','Fim da via ferroviária')
, ('5','Paragem')
, ('888', 'SEM DADOS');
create table if not exists {schema}.no_trans_ferrov (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	valor_tipo_no_trans_ferrov varchar(10) NOT NULL,
	geometria geometry(pointz, 3763) not null,
	constraint no_trans_ferrov_pk PRIMARY KEY (identificador)
);

-- Transporte Rodoviario
create table if not exists {schema}.valor_caract_fisica_rodov (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	constraint valor_caract_fisica_rodov_pk PRIMARY KEY (identificador)
);
insert into {schema}.valor_caract_fisica_rodov VALUES
('1','Autoestrada ou via reservada a automóveis e motociclos')
, ('2','Estrada')
, ('3','Via urbana')
, ('4','Via rural')
, ('5','Aceiro')
, ('6','Ciclovia')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_estado_via_rodov (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	constraint valor_estado_via_rodov_pk PRIMARY KEY (identificador)
);
insert into {schema}.valor_estado_via_rodov VALUES
('1','Desmantelada')
, ('2','Em construção')
, ('3','Em desuso')
, ('4','Projetada')
, ('5','Funcional')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_restricao_acesso (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	constraint valor_restricao_acesso_pk PRIMARY KEY (identificador)
);
insert into {schema}.valor_restricao_acesso VALUES
('1','Livre')
, ('2','Pago')
, ('3','Privado')
, ('4','Proibido por lei')
, ('5','Sazonal')
, ('6','Acesso físico impossível')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_sentido (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	constraint valor_sentido_pk PRIMARY KEY (identificador)
);
insert into {schema}.valor_sentido VALUES
('1','Duplo')
, ('2','No sentido')
, ('3','Sentido contrário')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_tipo_troco_rodoviario (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	constraint valor_tipo_troco_rodoviario_pk PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_troco_rodoviario VALUES
('1','Plena via')
, ('2','Ramo de ligação')
, ('3','Rotunda')
, ('4','Via de serviço')
, ('5','Via em escada')
, ('6','Trilho')
, ('7','Passadiço')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_tipo_circulacao (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	constraint valor_tipo_circulacao_pk PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_circulacao VALUES
('1','Veículo ligeiro ou pesado')
, ('2','Veículo agrícola ou com tração às quatro rodas')
, ('3','Velocipede')
, ('4','Pedonal')
, ('888', 'SEM DADOS');
create table if not exists {schema}.seg_via_rodov (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	gestao varchar(255),
	largura_via_rodov real,
	multipla_faixa_rodagem bool,
	num_vias_transito int4 NOT NULL,
	pavimentado bool NOT NULL,
	velocidade_max int4,
	jurisdicao varchar(255),
	valor_caract_fisica_rodov varchar(10) NOT NULL,
	valor_estado_via_rodov varchar(10),
	valor_posicao_vertical_transportes varchar(10) NOT NULL,
	valor_restricao_acesso varchar(10),
	valor_sentido varchar(10) NOT NULL,
	valor_tipo_troco_rodoviario varchar(10) NOT NULL,
	geometria geometry(linestringz, 3763) not null,
	constraint seg_via_rodov_pk PRIMARY KEY (identificador)
);

create table if not exists {schema}.area_infra_trans_rodov (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	infra_trans_rodov_id uuid NOT NULL,
	geometria geometry(POLYGON, 3763) not null,
	import_ref varchar(255) null,
	PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_tipo_infra_trans_rodov (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_infra_trans_rodov_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_infra_trans_rodov (identificador, descricao) VALUES
('1', 'Local de paragem')
, ('2', 'Terminal')
, ('3', 'Parqueamento')
, ('4', 'Parque de estacionamento')
, ('5', 'Portagem')
, ('6', 'Área de repouso')
, ('7', 'Área de serviço')
, ('8', 'Posto de abastecimento de combustíveis')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_tipo_servico (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_servico_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_servico (identificador, descricao) VALUES
('1', 'Abastecimento de combustível')
, ('2', 'Carregamento elétrico')
, ('3', 'Loja de conveniência')
, ('4', 'Restauração')
, ('5', 'Estacionamento')
, ('6', 'Estacionamento para veículos pesados')
, ('7', 'Estacionamento para caravanas')
, ('8', 'Apoio automóvel')
, ('9', 'Parque infantil')
, ('10', 'Instalações sanitárias')
, ('11', 'Duche')
, ('12', 'Área de piquenique')
, ('995', 'Não aplicável')
, ('888', 'SEM DADOS');
create table if not exists {schema}.infra_trans_rodov (
	identificador uuid not null default uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone not null,
	fim_objeto timestamp without time zone,
	nome varchar(255),
	valor_tipo_infra_trans_rodov varchar(255) not null,
	valor_tipo_servico varchar(255) not null,
	geometria geometry(POINT, 3763) not null,
	import_ref varchar(255) null,
	constraint infra_trans_rodov_pk primary key (identificador)
);

create table if not exists {schema}.valor_tipo_no_trans_rodov (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_no_trans_rodov_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_no_trans_rodov (identificador, descricao) VALUES
('1', 'Junção')
, ('2', 'Passagem de nível')
, ('3', 'Pseudo-nó')
, ('4', 'Fim da via rodoviária')
, ('5', 'Infraestrutura')
, ('888', 'SEM DADOS');
create table if not exists {schema}.no_trans_rodov (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	valor_tipo_no_trans_rodov varchar(10) NOT NULL,
	geometria geometry(pointz, 3763) not null,
	CONSTRAINT no_trans_rodov_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.via_rodov (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	codigo_via_rodov varchar(255) NOT NULL,
	data_cat date NOT NULL,
	fonte_aquisicao_dados varchar(255) NOT NULL,
	nome varchar(255) NOT NULL,
	nome_alternativo varchar(255),
	tipo_via_rodov_abv varchar(255) NOT NULL,
	tipo_via_rodov_c varchar(255) NOT NULL,
	tipo_via_rodov_d varchar(255) NOT NULL,
	CONSTRAINT via_rodov_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_tipo_limite (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_limite_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_limite VALUES
('1','Limite exterior sem berma')
, ('2','Separador')
, ('3','Limite exterior com berma pavimentada')
, ('888', 'SEM DADOS');
create table if not exists {schema}.via_rodov_limite (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	valor_tipo_limite varchar(10) NOT NULL,
	geometria geometry(linestringz, 3763) not null,
	CONSTRAINT via_rodov_limite_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_tipo_obra_arte (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_obra_arte_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_obra_arte VALUES
('1','Ponte')
, ('2','Viaduto')
, ('3','Passagem superior')
, ('4','Passagem inferior')
, ('5','Túnel')
, ('6','Passagem hidráulica')
, ('7','Passagem pedonal')
, ('8','Pilar')
, ('888', 'SEM DADOS');
create table if not exists {schema}.obra_arte (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	nome varchar(255),
	valor_tipo_obra_arte varchar(10) NOT NULL,
	geometria geometry(polygonz, 3763) not null,
	CONSTRAINT obra_arte_pkey PRIMARY KEY (identificador)
);

--
-- Hidrografia
--
create table if not exists {schema}.valor_persistencia_hidrologica (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_persistencia_hidrologica_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_persistencia_hidrologica VALUES
('1','Seco')
, ('2','Efémero')
, ('3','Intermitente')
, ('4','Perene')
, ('888', 'SEM DADOS');
create table if not exists {schema}.valor_tipo_nascente (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_nascente_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_nascente VALUES
('1','Água de nascente')
, ('2','Água mineral')
, ('888', 'SEM DADOS');
create table if not exists {schema}.nascente (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	nome varchar(255),
	id_hidrografico varchar(255),
	valor_persistencia_hidrologica varchar(10),
	valor_tipo_nascente varchar(10),
	geometria geometry(pointz, 3763) not null,
	CONSTRAINT nascente_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_agua_lentica (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_agua_lentica_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_agua_lentica VALUES
('1','Lagoa')
, ('2','Albufeira')
, ('3','Charca')
, ('888', 'SEM DADOS');
create table if not exists {schema}.agua_lentica (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	nome varchar(255),
	cota_plena_armazenamento bool NOT NULL,
	data_fonte_dados DATE,
	mare bool NOT NULL,
	origem_natural bool,
	profundidade_media real,
	id_hidrografico varchar(255),
	valor_agua_lentica varchar(10) NOT NULL,
	valor_persistencia_hidrologica varchar(10),
	geometria geometry(polygonz, 3763) not null,
	CONSTRAINT agua_lentica_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_tipo_margem (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_margem VALUES
('1','Pedregulho')
, ('2','Argila')
, ('3','Cascalho')
, ('4','Lama')
, ('5','Rocha')
, ('6','Areia')
, ('7','Seixos')
, ('8','Pedra')
, ('995','Não aplicável')
, ('888', 'SEM DADOS');
create table if not exists {schema}.margem (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	nome varchar(255),
	id_hidrografico varchar(255),
	valor_tipo_margem varchar(10) NOT NULL,
	geometria geometry(POLYGON, 3763) not null,
	CONSTRAINT margem_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_curso_de_agua (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_curso_de_agua_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_curso_de_agua VALUES
('1','Rio navegável ou flutuável')
, ('2','Rio não navegável nem flutuável')
, ('3','Ribeira')
, ('4','Linha de água')
, ('5','Canal')
, ('6','Vala')
, ('888', 'SEM DADOS');
create table if not exists {schema}.curso_de_agua_eixo (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	nome varchar(255),
	comprimento real,
	delimitacao_conhecida bool NOT NULL,
	ficticio bool NOT NULL,
	largura real,
	id_hidrografico varchar(255),
	id_curso_de_agua_area uuid,
	ordem_hidrologica varchar(255),
	origem_natural bool,
	valor_curso_de_agua varchar(10) NOT NULL,
	valor_persistencia_hidrologica varchar(10),
	valor_posicao_vertical varchar(10) NOT NULL,
	geometria geometry(linestringz, 3763) not null,
	CONSTRAINT curso_de_agua_eixo_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.curso_de_agua_area (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	delimitacao_conhecida bool NOT NULL,
	geometria geometry(polygonz, 3763) not null,
	CONSTRAINT curso_de_agua_area_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.queda_de_agua (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	nome varchar(255),
	altura real,
	id_hidrografico varchar(255),
	geometria geometry(pointz, 3763) not null,
	CONSTRAINT queda_de_agua_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_zona_humida (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_zona_humida_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_zona_humida VALUES
('1','Sapal')
, ('2','Turfeira')
, ('3','Paul')
, ('888', 'SEM DADOS');
create table if not exists {schema}.zona_humida (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	nome varchar(255),
	mare bool NOT NULL,
	id_hidrografico varchar(255),
	valor_zona_humida varchar(10) NOT NULL,
	geometria geometry(polygonz, 3763) not null,
	CONSTRAINT zona_humida_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_tipo_no_hidrografico (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_tipo_no_hidrografico_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_tipo_no_hidrografico VALUES
('1','Início')
, ('2','Fim')
, ('3','Junção')
, ('4','Pseudo-nó')
, ('5','Variação de fluxo')
, ('6','Regulação de fluxo')
, ('7','Fronteira')
, ('888', 'SEM DADOS');
create table if not exists {schema}.no_hidrografico (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	nome varchar(255),
	id_hidrografico varchar(255),
	valor_tipo_no_hidrografico varchar(10) NOT NULL,
	geometria geometry(pointz, 3763) not null,
	CONSTRAINT no_hidrografico_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.valor_barreira (
	identificador varchar(10) NOT NULL,
	descricao varchar(255) NOT NULL,
	CONSTRAINT valor_barreira_pkey PRIMARY KEY (identificador)
);
insert into {schema}.valor_barreira VALUES
('1','Comporta')
, ('2','Eclusa')
, ('3','Barreira da barragem de betão')
, ('4','Barreira da barragem de terra')
, ('5','Barreira do açude ou represa')
, ('6','Dique')
, ('888', 'SEM DADOS');
create table if not exists {schema}.barreira (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	nome varchar(255),
	id_hidrografico varchar(255),
	valor_barreira varchar(10) NOT NULL,
	geometria geometry(GEOMETRY, 3763) not null,
	CONSTRAINT barreira_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.fronteira_terra_agua (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	inicio_objeto timestamp without time zone NOT NULL,
	fim_objeto timestamp without time zone,
	data_fonte_dados date NOT NULL,
	ilha bool NOT NULL,
	geometria geometry(linestringz, 3763) not null,
	CONSTRAINT fronteira_terra_agua_pkey PRIMARY KEY (identificador)
);

--
-- tabela area_trabalho auxiliar
--
create table if not exists {schema}.area_trabalho (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	data date NOT NULL,
	nivel_de_detalhe varchar(255) NOT NULL,
	nome varchar(255) NOT NULL,
	nome_proprietario varchar(255) NOT NULL,
	nome_produtor varchar(255) NOT NULL,
	data_homologacao date,
	geometria geometry(POLYGON, 3763) not null,
	CONSTRAINT area_trabalho_pkey PRIMARY KEY (identificador)
);

--
-- tabelas lig
--
create table if not exists {schema}.lig_valor_utilizacao_atual_edificio (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	edificio_id uuid NOT NULL,
	valor_utilizacao_atual_id varchar(10) NOT NULL,
	CONSTRAINT lig_valor_utilizacao_atual_edificio_pkey PRIMARY KEY (identificador),
	CONSTRAINT lig_valor_utilizacao_atual_edificio_edificio FOREIGN KEY (edificio_id) REFERENCES {schema}.edificio(identificador) ON DELETE CASCADE,
	CONSTRAINT lig_valor_utilizacao_atual_edificio_valor_utilizacao_atual FOREIGN KEY (valor_utilizacao_atual_id) REFERENCES {schema}.valor_utilizacao_atual(identificador)
);

create table if not exists {schema}.lig_adm_publica_edificio (
	identificador uuid not null default uuid_generate_v1mc(),
	adm_publica_id uuid not null,
	edificio_id uuid not null,
	constraint lig_adm_publica_edificio_pk primary key (identificador),
	constraint lig_adm_publica_edificio_adm_publica_id_fk foreign key (adm_publica_id) references {schema}.adm_publica(identificador),
	constraint lig_adm_publica_edificio_edificio_id_fk foreign key (edificio_id) references {schema}.edificio(identificador)
);

create table if not exists {schema}.lig_equip_util_coletiva_edificio (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	equip_util_coletiva_id uuid NOT NULL,
	edificio_id uuid NOT NULL,
	CONSTRAINT lig_equip_util_coletiva_edificio_pkey PRIMARY KEY (identificador),
	CONSTRAINT localizacao_equip_util_coletiva_1 FOREIGN KEY (edificio_id) REFERENCES {schema}.edificio(identificador) ON DELETE CASCADE,
	CONSTRAINT localizacao_equip_util_coletiva_2 FOREIGN KEY (equip_util_coletiva_id) REFERENCES {schema}.equip_util_coletiva(identificador) ON DELETE CASCADE
);

create table if not exists {schema}.lig_valor_tipo_servico_infra_trans_rodov (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	infra_trans_rodov_id uuid NOT NULL,
	valor_tipo_servico_id varchar(10) NOT NULL,
	CONSTRAINT lig_valor_tipo_servico_infra_trans_rodov_pkey PRIMARY KEY (identificador),
	CONSTRAINT valor_tipo_servico_infra_trans_rodov_infra_trans_rodov FOREIGN KEY (infra_trans_rodov_id) REFERENCES {schema}.infra_trans_rodov(identificador) ON DELETE CASCADE,
	CONSTRAINT valor_tipo_servico_infra_trans_rodov_valor_tipo_servico FOREIGN KEY (valor_tipo_servico_id) REFERENCES {schema}.valor_tipo_servico(identificador)
);

create table if not exists {schema}.lig_infratransrodov_notransrodov (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	infra_trans_rodov_id uuid NOT NULL,
	no_trans_rodov_id uuid NOT NULL,
	CONSTRAINT lig_infratransrodov_notransrodov_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.lig_valor_tipo_equipamento_coletivo_equip_util_coletiva (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	equip_util_coletiva_id uuid NOT NULL,
	valor_tipo_equipamento_coletivo_id varchar(10) NOT NULL,
	CONSTRAINT lig_valor_tipo_equipamento_coletivo_equip_util_coletiva_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.lig_infratransferrov_notransferrov (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	infra_trans_ferrov_id uuid NOT NULL,
	no_trans_ferrov_id uuid NOT NULL,
	CONSTRAINT lig_infratransferrov_notransferrov_pkey PRIMARY KEY (identificador)
);

create table if not exists {schema}.lig_segviaferrea_linhaferrea (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	seg_via_ferrea_id uuid NOT NULL,
	linha_ferrea_id uuid NOT NULL,
	CONSTRAINT lig_segviaferrea_linhaferrea_pkey PRIMARY KEY (identificador),
	CONSTRAINT lig_segviaferrea_linhaferrea_1 FOREIGN KEY (seg_via_ferrea_id) REFERENCES {schema}.seg_via_ferrea(identificador) ON DELETE CASCADE,
	CONSTRAINT lig_segviaferrea_linhaferrea_2 FOREIGN KEY (linha_ferrea_id) REFERENCES {schema}.linha_ferrea(identificador) ON DELETE CASCADE
);

create table if not exists {schema}.lig_segviarodov_viarodov (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	seg_via_rodov_id uuid NOT NULL,
	via_rodov_id uuid NOT NULL,
	CONSTRAINT lig_segviarodov_viarodov_pkey PRIMARY KEY (identificador),
	CONSTRAINT lig_segviarodov_viarodov_1 FOREIGN KEY (seg_via_rodov_id) REFERENCES {schema}.seg_via_rodov(identificador) ON DELETE CASCADE,
	CONSTRAINT lig_segviarodov_viarodov_2 FOREIGN KEY (via_rodov_id) REFERENCES {schema}.via_rodov(identificador) ON DELETE CASCADE
);

create table if not exists {schema}.lig_segviarodov_viarodovlimite (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	seg_via_rodov_id uuid NOT NULL,
	via_rodov_limite_id uuid NOT NULL,
	CONSTRAINT lig_segviarodov_viarodovlimite_pkey PRIMARY KEY (identificador),
	CONSTRAINT lig_segviarodov_viarodovlimite_1 FOREIGN KEY (via_rodov_limite_id) REFERENCES {schema}.via_rodov_limite(identificador) ON DELETE CASCADE,
	CONSTRAINT lig_segviarodov_viarodovlimite_2 FOREIGN KEY (seg_via_rodov_id) REFERENCES {schema}.seg_via_rodov(identificador) ON DELETE CASCADE
);

create table if not exists {schema}.lig_valor_tipo_circulacao_seg_via_rodov (
	identificador uuid NOT NULL DEFAULT uuid_generate_v1mc(),
	seg_via_rodov_id uuid NOT NULL,
	valor_tipo_circulacao_id varchar(10) NOT NULL,
	CONSTRAINT lig_valor_tipo_circulacao_seg_via_rodov_pkey PRIMARY KEY (identificador),
	CONSTRAINT valor_tipo_circulacao_seg_via_rodov_seg_via_rodov FOREIGN KEY (seg_via_rodov_id) REFERENCES {schema}.seg_via_rodov(identificador) ON DELETE CASCADE,
	CONSTRAINT valor_tipo_circulacao_seg_via_rodov_valor_tipo_circulacao FOREIGN KEY (valor_tipo_circulacao_id) REFERENCES {schema}.valor_tipo_circulacao(identificador)
);
