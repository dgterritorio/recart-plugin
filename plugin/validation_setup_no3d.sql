create or replace procedure validation.do_validation (nd1 bool) language plpgsql as $$
declare 
	tbl text;
	pkey text;
	total int; good int; bad int;
	oneresult RECORD;
	onerule RECORD;
	rules CURSOR FOR SELECT * FROM validation.rules where enabled and run order by code;
begin 
	OPEN rules;
	LOOP
		FETCH rules INTO onerule;
		EXIT WHEN NOT FOUND;
	
		if onerule.query is not null then
			if nd1 is true then
				execute onerule.query INTO total, good, bad;
			else
				-- só adianta escrever uma regra própria para o ND2 se for diferente da regra para o ND1
				if onerule.query_nd2 is not null then
					execute onerule.query_nd2 INTO total, good, bad;
				else 
					execute onerule.query INTO total, good, bad;
				end if;
			end if;
			raise notice 'Good? % % %', total, good, bad;
			EXECUTE format('UPDATE validation.rules SET total = %s, good = %s, bad = %s WHERE CURRENT OF rules', total, good, bad);
		end if;
	
		if bad > 0 and onerule.report is not null then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- table without indexes
			tbl := 'errors.' || onerule.entity || '_' || onerule.code;
			raise notice '%', tbl;
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I)', tbl, onerule.entity);
			execute format('delete from %s', tbl);
			execute format('insert into %s %s', tbl, onerule.report);
		end if;
	
	end loop;
	CLOSE rules;
end; $$;

create or replace procedure validation.do_validation (nd1 bool, _code varchar) language plpgsql as $$
declare 
	tbl text;
	pkey text;
	total int;
	good int;
	bad int;

	_query text;
	_query_nd2 text;
	_report text;
	_entity text;
begin
	select query, query_nd2, report, entity from validation.rules where code=_code into _query, _query_nd2, _report, _entity;

	if _query is not null then
		if nd1 is true then
			execute _query INTO total, good, bad;
		else
			-- só adianta escrever uma regra própria para o ND2 se for diferente da regra para o ND1
			if _query_nd2 is not null then
				execute _query_nd2 INTO total, good, bad;
			else 
				execute _query INTO total, good, bad;
			end if;
		end if;
		raise notice 'Good? % % %', total, good, bad;
		execute format('UPDATE validation.rules SET total = %s, good = %s, bad = %s WHERE code = %L', total, good, bad, _code);
	end if;

	if bad > 0 and _report is not null then
		CREATE SCHEMA IF NOT EXISTS errors;
		-- table without indexes
		tbl := 'errors.' || _entity || '_' || _code;
		raise notice '%', tbl;
		execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I)', tbl, _entity);
		execute format('delete from %s', tbl);
		execute format('insert into %s %s', tbl, _report);
	end if;
end; $$;

-- supporting functions

create or replace function validation.validate_table_rows(table_name text, erows jsonb)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
declare
	val_result json;
begin
	execute format('with expected_results as (
		select * from json_to_recordset(''%1$s'') as x("identificador" varchar, "descricao" varchar)
	),
	actual_results as (
		select identificador, descricao from {schema}.%2$s
	)
	select case when not exists (select * from expected_results except select * from actual_results)
	and not exists (select * from actual_results except select * from expected_results) then ''[]''::json else (select json_agg(t) from (select * from expected_results except select * from actual_results) t) end as tres', erows, table_name) into val_result;

	return val_result;
end;
$function$
;

create or replace function validation.validate_table_columns(tname text, expected_columns jsonb)
returns boolean
language plpgsql
as $$
declare
	actual_columns jsonb;
	is_valid boolean;
begin
	select jsonb_agg(column_name) from information_schema.columns 
		where table_schema = '{schema}' and table_name = tname
	into actual_columns;

	is_valid := (actual_columns @> expected_columns) and (expected_columns @> actual_columns);

	return is_valid;
end;
$$;

create or replace function validation.initcap_pt (nome varchar) returns varchar as $$
declare 
	aux varchar;
begin
	select nome into aux;
	if regexp_match(aux, '^[A-Z]+$') is null then
		select initcap(nome) into aux;
		select REGEXP_REPLACE(aux, ' D([aeo]) ', ' d\1 ', 'g') into aux;
		select REGEXP_REPLACE(aux, ' D([ao])s ', ' d\1s ', 'g') into aux;
		select REGEXP_REPLACE(aux, ' E ', ' e ', 'g') into aux;
		select REGEXP_REPLACE(aux, ' A ', ' a ', 'g') into aux;
		select REGEXP_REPLACE(aux, ' À ', ' à ', 'g') into aux;
		select REGEXP_REPLACE(aux, 'Eb([123]) ', 'EB\1 ', 'g') into aux;
		select REGEXP_REPLACE(aux, 'Ji ', 'JI ', 'g') into aux;
		select REGEXP_REPLACE(aux, 'Sa$', 'SA', 'g') into aux;
	end if;
	return aux;
end;
$$ language plpgsql;

CREATE OR REPLACE FUNCTION validation.validcap_pt(nome character varying)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
declare 
	parts varchar[];
	word varchar;
	aux varchar;
	res bool;
begin
	res = true;
	select coalesce(regexp_split_to_array(nome, '[\sºª]+'), '{}') into parts;

	foreach word in array parts
	loop
		select word into aux;
		if upper(word) <> word then
			select upper(left(word, 1)) || right(word, -1) into aux;
			select REGEXP_REPLACE(aux, 'D([aeo''])$', 'd\1', 'g') into aux;
			select REGEXP_REPLACE(aux, 'D([ao])s$', 'd\1s', 'g') into aux;
			select REGEXP_REPLACE(aux, 'O([s]*)$', 'o\1', 'g') into aux;
			select REGEXP_REPLACE(aux, 'A([s]*)$', 'a\1', 'g') into aux;
			select REGEXP_REPLACE(aux, 'N([oa]{{1}}[s]*)$', 'n\1', 'g') into aux;
			select REGEXP_REPLACE(aux, 'Com$', 'com', 'g') into aux;
			select REGEXP_REPLACE(aux, 'Para$', 'para', 'g') into aux;
			select REGEXP_REPLACE(aux, 'Em$', 'em', 'g') into aux;
			select REGEXP_REPLACE(aux, 'E$', 'e', 'g') into aux;
			select REGEXP_REPLACE(aux, 'A$', 'a', 'g') into aux;
			select REGEXP_REPLACE(aux, 'À$', 'à', 'g') into aux;
			select REGEXP_REPLACE(aux, 'Eb([123])$', 'EB\1', 'g') into aux;
			select REGEXP_REPLACE(aux, 'Ji$', 'JI', 'g') into aux;
			select REGEXP_REPLACE(aux, 'Sa$', 'SA', 'g') into aux;
		
			if word <> aux then
				raise notice '% - %', word, aux;
				res = false;
				exit;
			end if;
		end if;
	end loop;

	return res;
end;
$function$
;

CREATE OR REPLACE FUNCTION validation.valid_noabbr(nome character varying)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
declare 
	parts varchar[];
	word varchar;
	aux varchar;
	res bool;
begin
	res = true;
	select coalesce(regexp_split_to_array(nome, '[\sºª]+'), '{}') into parts;

	foreach word in array parts
	loop
		if word ~ '[A-Z]+[.]+' then
			res = false;
			exit;
		end if;
	end loop;

	return res;
end;
$function$
;

-- validation.rg1_2_validation
-- Invocação:
-- select * from validation.rg1_2_validation (1, 1, true );
-- select * from validation.rg1_2_validation (2, 1, true );
-- Parâmetros:
-- rg:  1|2
-- versao: 1|2|3|...
-- nd1: true|false
create or replace function validation.rg1_2_validation (rg int, versao int, nd1 boolean) returns table (total int, good int, bad int) as $$
declare 
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
	all_aux integer;
	good_aux integer;
	bad_aux integer;
	tabela text;
	tabela_erro text;
	tabelas text;
	cvalue integer;
begin
	if nd1=true then
		cvalue = 4;
	else
		cvalue = 20;
	end if;

	if rg = 1 then
		tabelas := 'select f_table_name, f_geometry_column from geometry_columns where f_table_schema = ''{schema}'' and (type = ''POLYGON'' or type = ''GEOMETRY'') and LEFT(f_table_name, 1) != ''_'' ';
	else
		if versao = 1 then
			tabelas := $q$WITH  dupla_geometria (f_table_name, f_geometry_column) AS (VALUES 
			('edificio','geometria'), 
			('ponto_interesse','geometria'), 
			('elem_assoc_agua','geometria'), 
			('elem_assoc_eletricidade','geometria'), 
			('mob_urbano_sinal','geometria'))
			SELECT * FROM dupla_geometria	$q$;
		else
			tabelas := $q$WITH  dupla_geometria (f_table_name, f_geometry_column) AS (VALUES 
			('constru_polig','geometria'), 
			('edificio','geometria'), 
			('ponto_interesse','geometria'), 
			('elem_assoc_agua','geometria'), 
			('elem_assoc_eletricidade','geometria'), 
			('elem_assoc_pgq','geometria'), 
			('mob_urbano_sinal','geometria'))
			SELECT * FROM dupla_geometria	$q$;
		end if;
	end if;

	for tabela in execute tabelas
	loop 
		-- RAISE NOTICE '-------------------------- table % -------------------------------------------------', rec.f_table_name;
		execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON''', tabela ) INTO all_aux;
		-- RAISE NOTICE 'All is % for table %', all_aux, rec.f_table_name;
		count_all := count_all + all_aux;
		execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and st_area(geometria) >= %s', tabela, cvalue) INTO good_aux;
		-- RAISE NOTICE 'Good is % for table %', good_aux, rec.f_table_name;
		count_good := count_good + good_aux;
		execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and st_area(geometria) < %s', tabela, cvalue) INTO bad_aux;
		-- RAISE NOTICE 'Bad is % for table %', bad_aux, rec.f_table_name;
		count_bad := count_bad + bad_aux;
	
		if bad_aux > 0 then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- table without indexes
			tabela_erro := 'errors.' || tabela || '_rg_' || rg;
			-- raise notice '%', tbl;
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I)', tabela_erro, tabela);
			execute format('delete from %s', tabela_erro);
			execute format('insert into %s select * from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and st_area(geometria) < %s', tabela_erro, tabela, cvalue);
		end if;
	end loop;
return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.rg1_2_validation (rg int, versao int, nd1 boolean, _args json) returns table (total int, good int, bad int) as $$
declare 
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
	all_aux integer;
	good_aux integer;
	bad_aux integer;
	tabela text;
	tabela_erro text;
	tabelas text;
	cvalue integer;
begin
	if nd1=true then
		select coalesce(_args->>'rg1_ndd1', '4')::int into cvalue;
	else
		select coalesce(_args->>'rg1_ndd2', '20')::int into cvalue;
	end if;

	if rg = 1 then
		tabelas := 'select f_table_name, f_geometry_column from geometry_columns where f_table_schema = ''{schema}'' and f_geometry_column=''geometria'' and (type = ''POLYGON'' or type = ''GEOMETRY'') and LEFT(f_table_name, 1) != ''_'' ';
	else
		if versao = 1 then
			tabelas := $q$WITH  dupla_geometria (f_table_name, f_geometry_column) AS (VALUES 
			('edificio','geometria'), 
			('ponto_interesse','geometria'), 
			('elem_assoc_agua','geometria'), 
			('elem_assoc_eletricidade','geometria'), 
			('mob_urbano_sinal','geometria'))
			SELECT * FROM dupla_geometria	$q$;
		else
			tabelas := $q$WITH  dupla_geometria (f_table_name, f_geometry_column) AS (VALUES 
			('constru_polig','geometria'), 
			('edificio','geometria'), 
			('ponto_interesse','geometria'), 
			('elem_assoc_agua','geometria'), 
			('elem_assoc_eletricidade','geometria'), 
			('elem_assoc_pgq','geometria'), 
			('mob_urbano_sinal','geometria'))
			SELECT * FROM dupla_geometria	$q$;
		end if;
	end if;

	for tabela in execute tabelas
	loop 
		-- RAISE NOTICE '-------------------------- table % -------------------------------------------------', rec.f_table_name;
		execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON''', tabela ) INTO all_aux;
		-- RAISE NOTICE 'All is % for table %', all_aux, rec.f_table_name;
		count_all := count_all + all_aux;
		execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and st_area(geometria) >= %s', tabela, cvalue) INTO good_aux;
		-- RAISE NOTICE 'Good is % for table %', good_aux, rec.f_table_name;
		count_good := count_good + good_aux;
		execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and st_area(geometria) < %s', tabela, cvalue) INTO bad_aux;
		-- RAISE NOTICE 'Bad is % for table %', bad_aux, rec.f_table_name;
		count_bad := count_bad + bad_aux;
	
		if bad_aux > 0 then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- table without indexes
			tabela_erro := 'errors.' || tabela || '_rg_' || rg;
			-- raise notice '%', tbl;
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I)', tabela_erro, tabela);
			execute format('delete from %s', tabela_erro);
			execute format('insert into %s select * from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and st_area(geometria) < %s', tabela_erro, tabela, cvalue);
		end if;
	end loop;
return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;


-- select * from validation.rg5_validation ();
create or replace function validation.rg5_validation () returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
	all_aux integer;
	good_aux integer;
	bad_aux integer;
	tabela text;
	tabela_erro text;
	tabelas text[];
begin
	tabelas = array['agua_lentica', 'curso_de_agua_area', 'margem', 'zona_humida', 'area_infra_trans_aereo', 'area_agricola_florestal_mato', 'areas_artificializadas'];

	for tabela in select unnest(tabelas)
	loop 
		RAISE NOTICE '-------------------------- table % -------------------------------------------------', tabela;
		execute format('select count(*) from {schema}.%I', tabela) INTO all_aux;
		RAISE NOTICE 'All is % for table %', all_aux, tabela;
		count_all := count_all + all_aux;
	
		execute format('select count(t.*) from {schema}.%I t, {schema}.area_trabalho adt
			where St_Contains(adt.geometria, t.geometria)', tabela) INTO good_aux;
		RAISE NOTICE 'Good is % for table %', good_aux, tabela;
		count_good := count_good + good_aux;
	
		execute format('select count(t.*) from {schema}.%I t, {schema}.area_trabalho adt
			where not St_Contains(adt.geometria, t.geometria)', tabela) INTO bad_aux;
		RAISE NOTICE 'Bad is % for table %', bad_aux, tabela;
		count_bad := count_bad + bad_aux;

		if bad_aux > 0 then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- table without indexes
			tabela_erro := 'errors.' || tabela || '_rg_5';
			-- raise notice '%', tbl;
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I)', tabela_erro, tabela);
			execute format('delete from %s', tabela_erro);
			execute format('insert into %s select t.* from {schema}.%I t, {schema}.area_trabalho adt
				where not St_Contains(adt.geometria, t.geometria)', tabela_erro, tabela);
		end if;
	end loop;
	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

-- select * from validation.rg6_validation ();
create or replace function validation.rg6_validation () returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
	all_aux integer;
	good_aux integer;
	bad_aux integer;
	tabela text;
	tabela_erro text;
	tabelas text;
begin
	tabelas := $q$select t.table_name from information_schema.tables t
		inner join information_schema.columns c on
			t.table_name = c.table_name and t.table_schema = c.table_schema
		where
			t.table_schema = '{schema}'
			and t.table_type= 'BASE TABLE'
			and c.table_schema = t.table_schema
			and c.column_name = 'nome'
			and LEFT(t.table_name, 1) != '_'$q$;
	RAISE NOTICE '------------------------------------------------------------------------------';
	RAISE NOTICE '%', tabelas;
	RAISE NOTICE '------------------------------------------------------------------------------';
	for tabela in execute tabelas
	loop
		RAISE NOTICE '-------------------------- table % -------------------------------------------------', tabela;
		execute format('select count(*) from {schema}.%I where nome is not null', tabela ) INTO all_aux;
		RAISE NOTICE 'All is % for table %', all_aux, tabela;
		count_all := count_all + all_aux;
	
		execute format('select count(*) from {schema}.%I where validation.validcap_pt(nome)=true', tabela ) INTO good_aux;
		RAISE NOTICE 'Good is % for table %', good_aux, tabela;
		count_good := count_good + good_aux;
	
		execute format('select count(*) from {schema}.%I where validation.validcap_pt(nome)<>true', tabela ) INTO bad_aux;
		RAISE NOTICE 'Bad is % for table %', bad_aux, tabela;
		count_bad := count_bad + bad_aux;

		if bad_aux > 0 then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- table without indexes
			tabela_erro := 'errors.' || tabela || '_rg_6';
			-- raise notice '%', tbl;
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I)', tabela_erro, tabela);
			execute format('delete from %s', tabela_erro);
			execute format('insert into %s select * from {schema}.%I where validation.validcap_pt(nome)<>true', tabela_erro, tabela);
		end if;
	end loop;
return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

-- select * from validation.rg7_validation ();
create or replace function validation.rg7_validation () returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
	all_aux integer;
	good_aux integer;
	bad_aux integer;
	tabela text;
	coluna text;
	tabela_erro text;
	tabelas text;
begin
	tabelas := $q$select t.table_name, c.column_name from information_schema.tables t
		inner join information_schema.columns c on
			t.table_name = c.table_name and t.table_schema = c.table_schema
		where
			t.table_schema = '{schema}'
			and t.table_type= 'BASE TABLE'
			and c.table_schema = t.table_schema
			and (c.column_name = 'nome' or c.column_name = 'nome_alternativo' or c.column_name = 'nome_proprietario' or c.column_name = 'nome_produtor')
			and LEFT(t.table_name, 1) != '_'
			and t.table_name <> 'via_rodov'$q$;
	RAISE NOTICE '------------------------------------------------------------------------------';
	RAISE NOTICE '%', tabelas;
	RAISE NOTICE '------------------------------------------------------------------------------';
	for tabela, coluna in execute tabelas
	loop 
		RAISE NOTICE '-------------------------- table % -------------------------------------------------', tabela;
		execute format('select count(*) from {schema}.%I where %s is not null', tabela, coluna) INTO all_aux;
		RAISE NOTICE 'All is % for table %', all_aux, tabela;
		count_all := count_all + all_aux;
	
		execute format('select count(*) from {schema}.%I where validation.valid_noabbr(%s)=true', tabela, coluna) INTO good_aux;
		RAISE NOTICE 'Good is % for table %', good_aux, tabela;
		count_good := count_good + good_aux;
	
		execute format('select count(*) from {schema}.%I where validation.valid_noabbr(%s)<>true', tabela, coluna) INTO bad_aux;
		RAISE NOTICE 'Bad is % for table %', bad_aux, tabela;
		count_bad := count_bad + bad_aux;

		if bad_aux > 0 then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- table without indexes
			tabela_erro := 'errors.' || tabela || '_rg_7';
			-- raise notice '%', tbl;
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I)', tabela_erro, tabela);
			execute format('delete from %s', tabela_erro);
			execute format('insert into %s select * from {schema}.%I where validation.valid_noabbr(%s)<>true', tabela_erro, tabela, coluna);
		end if;
	end loop;
return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;


create or replace function validation.rg_min_area (rg text, tabela text, minv int) returns table (total int, good int, bad int) as $$
declare 
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;

	tabela_erro text;
begin
	execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON''', tabela) into count_all;
	execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and st_area(geometria) >= %s', tabela, minv) into count_good;
	execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and st_area(geometria) < %s', tabela, minv) into count_bad;

	if count_bad > 0 then
		create schema if not exists errors;
		-- table without indexes
		tabela_erro := 'errors.' || tabela || '_' || rg;
		-- raise notice '%', tbl;
		execute format('create table if not exists %s (like {schema}.%I)', tabela_erro, tabela);
		execute format('delete from %s', tabela_erro);
		execute format('insert into %s select * from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and st_area(geometria) < %s', tabela_erro, tabela, minv);
	end if;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;


-- select * from validation.re3_2_validation ();
create or replace function validation.re3_2_validation (ndd integer) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;

	valor_equi integer := 0;
begin
	if ndd = 1 then
		valor_equi = 2;
	else
		valor_equi = 5;
	end if;

	with 
	pares as (SELECT
			round( abs(st_z(ST_PointN(all_cdn.geometria, 1)) - st_z(ST_PointN(closest_cdn.geometria, 1)))::numeric, 2) as z_distance
		FROM {schema}.curva_de_nivel as all_cdn
		CROSS JOIN LATERAL 
		(SELECT geometria
			FROM {schema}.curva_de_nivel ports
			where all_cdn.identificador != ports.identificador and valor_tipo_curva in ('1','2')
			ORDER BY ST_PointN(all_cdn.geometria, 1) <-> ports.geometria
			LIMIT 1
		) AS closest_cdn
		where valor_tipo_curva in ('1','2')
	),
	total as (select count(*) from pares),
	good as (select count(*) from pares where z_distance = 0 or z_distance = valor_equi),
	bad as (select count(*)	from pares where not (z_distance = 0 or z_distance = valor_equi))
	select total.count as total, good.count as good, bad.count as bad
	from total, good, bad into count_all, count_good, count_bad;

	RAISE NOTICE 'All is % for table %', count_all, 'curva_de_nivel';
	RAISE NOTICE 'Good is % for table %', count_good, 'curva_de_nivel';
	RAISE NOTICE 'Bad is % for table %', count_bad, 'curva_de_nivel';

	if count_bad > 0 then
		CREATE SCHEMA IF NOT EXISTS errors;
		-- table without indexes
		-- raise notice '%', tbl;
		CREATE TABLE IF NOT exists errors.curva_de_nivel_re3_2 (like {schema}.curva_de_nivel);

		delete from errors.curva_de_nivel_re3_2;
		insert into errors.curva_de_nivel_re3_2 (
			with 
				pares as (select all_cdn.identificador,
						round( abs(st_z(ST_PointN(all_cdn.geometria, 1)) - st_z(ST_PointN(closest_cdn.geometria, 1)))::numeric, 2) as z_distance
					FROM {schema}.curva_de_nivel as all_cdn
					CROSS JOIN LATERAL 
					(SELECT geometria
						FROM {schema}.curva_de_nivel ports
						where all_cdn.identificador != ports.identificador and valor_tipo_curva in ('1','2')
						ORDER BY ST_PointN(all_cdn.geometria, 1) <-> ports.geometria
						LIMIT 1
					) AS closest_cdn
					where valor_tipo_curva in ('1','2')),
				bad as (select * from pares where not (z_distance = 0 or z_distance = valor_equi))
			select cn.* 
			from {schema}.curva_de_nivel cn, bad
			where cn.identificador = bad.identificador
		);
	end if;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

-- select * from validation.re4_10_validation ();
create or replace function validation.re4_10_validation () returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
	all_aux integer;
	good_aux integer;
	bad_aux integer;
	tabela text;
	tabela_erro text;
	tabelas text[];
	tipo_no text;
begin
	tabelas = array['queda_de_agua', 'zona_humida', 'barreira'];

	for tabela in select unnest(tabelas)
	loop 
		RAISE NOTICE '-------------------------- table % -------------------------------------------------', tabela;
		execute format('select count(*) from {schema}.%I', tabela) INTO all_aux;
		RAISE NOTICE 'All is % for table %', all_aux, tabela;
		count_all := count_all + all_aux;

		if tabela='barreira' then
			tipo_no := '6';
		else
			tipo_no := '5';
		end if;

		execute format('select count(t.*) from {schema}.%I t, {schema}.no_hidrografico nh
			where St_intersects(t.geometria, nh.geometria) and nh.valor_tipo_no_hidrografico=''%s''', tabela, tipo_no) INTO good_aux;

		RAISE NOTICE 'Good is % for table %', good_aux, tabela;
		count_good := count_good + good_aux;

		execute format('select count(t.*) from {schema}.%1$I t
			where (not (select ST_intersects(t.geometria, f.geometria) from 
					(select geom_col as geometria from validation.no_hidro) as f)
				or t.identificador not in (select distinct ta.identificador from {schema}.%1$I ta, {schema}.no_hidrografico nh 
					where St_intersects(ta.geometria, nh.geometria) and nh.valor_tipo_no_hidrografico=''%2$s''))', tabela, tipo_no) INTO bad_aux;
	
		RAISE NOTICE 'Bad is % for table %', bad_aux, tabela;
		count_bad := count_bad + bad_aux;

		if bad_aux > 0 then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- table without indexes
			tabela_erro := 'errors.' || tabela || '_re4_10_1';
			-- raise notice '%', tbl;
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I)', tabela_erro, tabela);

			execute format('delete from %1$s', tabela_erro);
			execute format('insert into %1$s select t.* from {schema}.%2$I t
				where (not (select ST_intersects(t.geometria, f.geometria) from 
						(select geom_col as geometria from validation.no_hidro) as f)
					or t.identificador not in (select distinct ta.identificador from {schema}.%2$I ta, {schema}.no_hidrografico nh 
						where St_intersects(ta.geometria, nh.geometria) and nh.valor_tipo_no_hidrografico=''%3$s''))', tabela_erro, tabela, tipo_no);
		end if;
	end loop;
	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

-- Criar area de trabalho multi-poligono para casos com multiplas areas de trabalho no mesmo projecto

CREATE TABLE IF NOT EXISTS validation.area_trabalho_multi AS
(
	SELECT st_collect(geometria)::geometry(multipolygon,3763) as geometria
	FROM {schema}.area_trabalho
);
CREATE INDEX ON validation.area_trabalho_multi USING gist(geometria);


CREATE TABLE IF NOT EXISTS validation.no_hidro AS (
	SELECT ST_Collect(f.geometria) AS geom_col FROM (
		SELECT geometria FROM {schema}.no_hidrografico
	) AS f
);

CREATE TABLE IF NOT EXISTS validation.no_hidro_juncao AS (
	SELECT ST_Collect(f.geometria) AS geom_col FROM (
		SELECT geometria FROM {schema}.no_hidrografico n where n.valor_tipo_no_hidrografico='3'
	) AS f
);

-- barreira é 2D apenas
CREATE TABLE IF NOT EXISTS validation.interrupcao_fluxo AS (
	SELECT ST_Collect(f.geometria) AS geom_col FROM (
		SELECT geometria FROM {schema}.queda_de_agua union all
		SELECT geometria FROM {schema}.zona_humida -- union all
		-- SELECT geometria FROM {schema}.barreira
	) AS f
);

CREATE INDEX IF NOT EXISTS idx_val_eixos ON {schema}.curso_de_agua_eixo USING GIST (geometria);
CREATE TABLE IF NOT EXISTS validation.juncao_fluxo_dattr AS (
	select st_intersection(a.geometria, b.geometria) as geom_col
		from {schema}.curso_de_agua_eixo a
		inner join {schema}.curso_de_agua_eixo b ON a.identificador <> b.identificador AND ST_Intersects(a.geometria, b.geometria)
		where not (coalesce(a.nome, '')<>coalesce(b.nome, '') or
				coalesce(a.delimitacao_conhecida, false)<>coalesce(b.delimitacao_conhecida, false) or
				coalesce(a.ficticio, false)<>coalesce(b.ficticio, false) or
				coalesce(a.largura, 0)<>coalesce(b.largura, 0) or
				coalesce(a.id_hidrografico, '')<>coalesce(b.id_hidrografico, '') or
				coalesce(a.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')<>coalesce(b.id_curso_de_agua_area, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') or
				coalesce(a.ordem_hidrologica, '')<>coalesce(b.ordem_hidrologica, '') or
				coalesce(a.origem_natural, false)<>coalesce(b.origem_natural, false) or
				coalesce(a.valor_curso_de_agua, '')<>coalesce(b.valor_curso_de_agua, '') or
				coalesce(a.valor_persistencia_hidrologica, '')<>coalesce(b.valor_persistencia_hidrologica, '') or
				coalesce(a.valor_posicao_vertical, '')<>coalesce(b.valor_posicao_vertical, ''))
);
CREATE INDEX IF NOT EXISTS idx_val_juncao_fluxo_dattr_eixos ON validation.juncao_fluxo_dattr USING GIST (geom_col);

--
-- validation rules
--

update validation.rules set run = false where code ilike 're3_2';
update validation.rules set run = false where code ilike 'rg_4_1';
update validation.rules set run = false where code ilike 'rg_4_2';
