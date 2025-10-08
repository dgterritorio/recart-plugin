/* create or replace procedure validation.do_validation (nd1 bool) language plpgsql as $$
declare 
	tbl text;
	pkey text;
	total int; good int; bad int;
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
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tbl, onerule.entity);
			execute format('delete from %s', tbl);
			execute format('insert into %s %s', tbl, onerule.report);
		end if;
	
	end loop;
	CLOSE rules;
end; $$; 
*/

/* create or replace procedure validation.do_validation (nd1 bool, _code varchar) language plpgsql as $$
declare 
	tbl text;
	pkey text;
	total int;
	good int;
	bad int;
	tblname text;
	schname text;

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
		-- tables are created without indexes
		tblname := substring(_entity from position('.' in _entity)+1 );
		-- tbl := 'errors.' || tblname || '_' || _code;
		tbl = format('%I.%I', 'errors', tblname || '_' || _code );
		raise notice '%', tbl;
		if position('.' in _entity) > 0 then
			schname = substring(_entity from 1 for position('.' in _entity)-1 );
			execute format('CREATE TABLE IF NOT exists %s (like %I.%I INCLUDING ALL)', tbl, schname, tblname);
		else
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tbl, _entity);
		end if;		
		execute format('delete from %s', tbl);
		execute format('insert into %s %s', tbl, format(_report, _args));
	end if;
end; $$;
*/
create or replace procedure validation.do_validation (nd1 bool, vrs varchar, _code varchar, _args json) language plpgsql as $$
declare 
	tbl text;
	pkey text;
	total int;
	good int;
	bad int;
	tblname text;
	schname text;

	_query text;
	_query_nd2 text;
	_report text;
	_entity text;
begin
	select query, query_nd2, report, entity from validation.rules where code=_code and vrs=any(versoes) into _query, _query_nd2, _report, _entity;

	if _query is not null then
		if nd1 is true then
			execute format(_query, _args) INTO total, good, bad;
		else
			-- só adianta escrever uma regra própria para o ND2 se for diferente da regra para o ND1
			if _query_nd2 is not null then
				execute format(_query_nd2, _args) INTO total, good, bad;
			else 
				execute format(_query, _args) INTO total, good, bad;
			end if;
		end if;
		raise notice 'Good? % % %', total, good, bad;
		execute format('UPDATE validation.rules SET total = %s, good = %s, bad = %s WHERE code = %L', total, good, bad, _code);
	end if;

	if bad > 0 and _report is not null then
		CREATE SCHEMA IF NOT EXISTS errors;
		-- tables are created without indexes
		tblname := substring(_entity from position('.' in _entity)+1 );
		-- tbl := 'errors.' || tblname || '_' || _code;
		tbl = format('%I.%I', 'errors', tblname || '_' || _code );
		raise notice '%', tbl;
		if position('.' in _entity) > 0 then
			schname = substring(_entity from 1 for position('.' in _entity)-1 );
			execute format('CREATE TABLE IF NOT exists %s (like %I.%I INCLUDING ALL)', tbl, schname, tblname);
		else
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tbl, _entity);
		end if;		
		execute format('delete from %s', tbl);
		execute format('insert into %s %s', tbl, format(_report, _args));
	end if;
end; $$;

/* create or replace procedure validation.do_validation(nd1 bool, area_tbl varchar, _code varchar, _sec_code varchar) language plpgsql as $$
declare 
	tbl text;
	pkey text;
	total int; good int; bad int;
	geom_record RECORD;
	tblname text;
	schname text;

	_query text;
	_query_nd2 text;
	_report text;
	_entity text;
	_is_global boolean;
begin
	select query, query_nd2, report, entity, is_global from validation.rules_area where code=_code into _query, _query_nd2, _report, _entity, _is_global;

	if exists (
		select 1 from validation.rules_area_report 
		where rule_code::varchar = _code and geom_id::varchar = _sec_code
	) then
		raise notice 'Rule % already processed for geometry %', _code, _sec_code;
		return;
	end if;

	if _is_global then
		if exists (
			select 1 from validation.rules_area_report 
			where rule_code::varchar = _code
		) then
			raise notice 'Rule % already processed globally', _code;
			return;
		end if;
	end if;

	execute format('select geometria from %s where identificador::varchar=''%s'';', area_tbl, _sec_code) INTO geom_record;

	if _is_global is true and _query is not null then
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
		EXECUTE format('insert into validation.rules_area_report(rule_code, total, good, bad) values (''%s'', %s, %s, %s)', _code, total, good, bad);

		if bad > 0 and _report is not null then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- tables are created without indexes
			tblname := substring(_entity from position('.' in _entity)+1 );
			-- tbl := 'errors.' || tblname || '_' || _code;
			tbl = format('%I.%I', 'errors', tblname || '_' || _code );
			raise notice '%', tbl;
			if position('.' in _entity) > 0 then
				schname = substring(_entity from 1 for position('.' in _entity)-1 );
				execute format('CREATE TABLE IF NOT exists %s (like %I.%I INCLUDING ALL)', tbl, schname, tblname);
			else
				execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tbl, _entity);
			end if;		
			execute format('delete from %s', tbl);
			execute format('insert into %s %s', tbl, format(_report, _args));
		end if;
	else
		if _query is not null then
			if nd1 is true then
				raise notice '%', format(_query, geom_record.geometria);
				execute format(_query, geom_record.geometria) INTO total, good, bad;
			else
				-- só adianta escrever uma regra própria para o ND2 se for diferente da regra para o ND1
				if _query_nd2 is not null then
					execute format(_query_nd2, geom_record.geometria) INTO total, good, bad;
				else 
					execute format(_query, geom_record.geometria) INTO total, good, bad;
				end if;
			end if;
			raise notice 'Good? % % %', total, good, bad;
			EXECUTE format('insert into validation.rules_area_report(rule_code, geom_id, total, good, bad) values (''%s'', ''%s'', %s, %s, %s)', _code, _sec_code, total, good, bad);
		end if;
	
		if bad > 0 and _report is not null then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- tables are created without indexes
			tblname := substring(_entity from position('.' in _entity)+1 );
			-- tbl := 'errors.' || tblname || '_' || _code;
			tbl = format('%I.%I', 'errors', tblname || '_' || _code );
			raise notice '%', tbl;
			if position('.' in _entity) > 0 then
				schname = substring(_entity from 1 for position('.' in _entity)-1 );
				execute format('CREATE TABLE IF NOT exists %s (like %I.%I INCLUDING ALL)', tbl, schname, tblname);
			else
				execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tbl, _entity);
			end if;		
			execute format('delete from %s', tbl);
			execute format('insert into %s %s', tbl, format(_report, _args));
		end if;
	end if;
end; $$;
*/

create or replace procedure validation.do_validation(nd1 bool, vrs varchar, area_tbl varchar, _code varchar, _sec_code varchar, _args json) language plpgsql as $$
declare 
	tbl text;
	pkey text;
	total int; good int; bad int;
	geom_record RECORD;
	tblname text;
	schname text;
	existe int;

	_query text;
	_query_nd2 text;
	_report text;
	_entity text;
	_is_global boolean;
begin
	select query, query_nd2, report, entity, is_global from validation.rules_area where code=_code and vrs=any(versoes) into _query, _query_nd2, _report, _entity, _is_global;

	if exists (
		select 1 from validation.rules_area_report 
		where rule_code::varchar = _code and geom_id::varchar = _sec_code
	) then
		raise notice 'Rule % already processed for geometry %', _code, _sec_code;
		return;
	end if;

	if _is_global then
		if exists (
			select 1 from validation.rules_area_report 
			where rule_code::varchar = _code
		) then
			raise notice 'Rule % already processed globally', _code;
			return;
		end if;
	end if;

	execute format('select geometria from %s where identificador::varchar=''%s'';', area_tbl, _sec_code) INTO geom_record;

	if _is_global is true and _query is not null then
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
		EXECUTE format('insert into validation.rules_area_report(rule_code, total, good, bad) values (''%s'', %s, %s, %s)', _code, total, good, bad);

		if bad > 0 and _report is not null then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- tables are created without indexes
			tblname := substring(_entity from position('.' in _entity)+1 );
			-- tbl := 'errors.' || tblname || '_' || _code;
			tbl = format('%I.%I', 'errors', tblname || '_' || _code );
			raise notice '%', tbl;
			if position('.' in _entity) > 0 then
				schname = substring(_entity from 1 for position('.' in _entity)-1 );
				execute format('CREATE TABLE IF NOT exists %s (like %I.%I INCLUDING ALL)', tbl, schname, tblname);
			else
				execute format('CREATE TABLE IF NOT exists %s (like public.%I INCLUDING ALL)', tbl, _entity);
			end if;	
			-- execute format('delete from %s', tbl);
			execute format('insert into %s %s on conflict ON constraint %s_pkey do nothing', tbl, _report, tblname || '_' || _code);
		end if;
	else
		if _query is not null then
			if nd1 is true then
				raise notice '%', format(_query, geom_record.geometria, _args);
				execute format(_query, geom_record.geometria, _args) INTO total, good, bad;
			else
				-- só adianta escrever uma regra própria para o ND2 se for diferente da regra para o ND1
				if _query_nd2 is not null then
					execute format(_query_nd2, geom_record.geometria, _args) INTO total, good, bad;
				else 
					execute format(_query, geom_record.geometria, _args) INTO total, good, bad;
				end if;
			end if;
			raise notice 'Good? % % %', total, good, bad;
			EXECUTE format('insert into validation.rules_area_report(rule_code, geom_id, total, good, bad) values (''%s'', ''%s'', %s, %s, %s)', _code, _sec_code, total, good, bad);
		end if;
	
		if bad > 0 and _report is not null then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- tables are created without indexes
			tblname := substring(_entity from position('.' in _entity)+1 );
			-- tbl := 'errors.' || tblname || '_' || _code;
			tbl = format('%I.%I', 'errors', tblname || '_' || _code );
			raise notice '%', tbl;
			if position('.' in _entity) > 0 then
				schname = substring(_entity from 1 for position('.' in _entity)-1 );
				execute format('CREATE TABLE IF NOT exists %s (like %I.%I INCLUDING ALL)', tbl, schname, tblname);
			else
				execute format('CREATE TABLE IF NOT exists %s (like public.%I INCLUDING ALL)', tbl, _entity);
			end if;	
			-- execute format('delete from %s', tbl);
			raise notice '%', format('insert into %s %s on conflict ON constraint %s_pkey do nothing', tbl, format(_report, geom_record.geometria, _args), tblname || '_' || _code);
			-- intersecoes_3d_rg_4_3_2_pkey
			execute format('insert into %s %s on conflict ON constraint %s_pkey do nothing', tbl, format(_report, geom_record.geometria, _args), tblname || '_' || _code);
		end if;
	end if;
end; $$;

/* create or replace procedure validation.do_validation_sect (nd1 bool, area_tbl varchar, _code varchar) language plpgsql as $$
declare 
	tbl text;
	pkey text;
	total int; good int; bad int;
	geom_record RECORD;
	tblname text;
	schname text;

	_query text;
	_query_nd2 text;
	_report text;
	_entity text;
	_is_global boolean;
begin
	select query, query_nd2, report, entity, is_global from validation.rules_area where code=_code into _query, _query_nd2, _report, _entity, _is_global;

	if _is_global is true and _query is not null then
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
		EXECUTE format('insert into validation.rules_area_report(rule_code, total, good, bad) values (''%s'', %s, %s, %s)', _code, total, good, bad);

		if bad > 0 and _report is not null then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- tables are created without indexes
			tblname := substring(_entity from position('.' in _entity)+1 );
			-- tbl := 'errors.' || tblname || '_' || _code;
			tbl = format('%I.%I', 'errors', tblname || '_' || _code );
			raise notice '%', tbl;
			if position('.' in _entity) > 0 then
				schname = substring(_entity from 1 for position('.' in _entity)-1 );
				execute format('CREATE TABLE IF NOT exists %s (like %I.%I INCLUDING ALL)', tbl, schname, tblname);
			else
				execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tbl, _entity);
			end if;		
			execute format('delete from %s', tbl);
			execute format('insert into %s %s', tbl, format(_report, _args));
		end if;
	end if;

	FOR geom_record IN
		EXECUTE format('SELECT identificador, geometria FROM %s;', area_tbl)
	LOOP
		if exists (
			select 1 
			from validation.rules_area_report 
			where rule_code = _code 
				and geom_id = geom_record.identificador
		) then
			raise notice 'Rule % already processed for geometry %', _code, geom_record.identificador;
			continue;
		end if;

		if _query is not null then
			if nd1 is true then
				raise notice '%', format(_query, geom_record.geometria);
				execute format(_query, geom_record.geometria) INTO total, good, bad;
			else
				-- só adianta escrever uma regra própria para o ND2 se for diferente da regra para o ND1
				if _query_nd2 is not null then
					execute format(_query_nd2, geom_record.geometria) INTO total, good, bad;
				else 
					execute format(_query, geom_record.geometria) INTO total, good, bad;
				end if;
			end if;
			raise notice 'Good? % % %', total, good, bad;
			EXECUTE format('insert into validation.rules_area_report(rule_code, geom_id, total, good, bad) values (''%s'', ''%s'', %s, %s, %s)', _code, geom_record.identificador, total, good, bad);
		end if;
	
		if bad > 0 and _report is not null then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- tables are created without indexes
			tblname := substring(_entity from position('.' in _entity)+1 );
			-- tbl := 'errors.' || tblname || '_' || _code;
			tbl = format('%I.%I', 'errors', tblname || '_' || _code );
			raise notice '%', tbl;
			if position('.' in _entity) > 0 then
				schname = substring(_entity from 1 for position('.' in _entity)-1 );
				execute format('CREATE TABLE IF NOT exists %s (like %I.%I INCLUDING ALL)', tbl, schname, tblname);
			else
				execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tbl, _entity);
			end if;		
			execute format('delete from %s', tbl);
			execute format('insert into %s %s', tbl, format(_report, _args));
		end if;
	end loop;
end; $$;
*/
-- supporting functions

create or replace function validation.validate_table_rows(table_name text, erows text)
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
		tabelas := 'select f_table_name, f_geometry_column from geometry_columns where f_table_schema = ''{schema}'' and (type = ''POLYGON'' or type = ''GEOMETRY'') and LEFT(f_table_name, 1) != ''_'' and f_geometry_column = ''geometria'' ';
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
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
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

create or replace function validation.rg1_2_validation (rg int, versao int, nd1 boolean, sect geometry) returns table (total int, good int, bad int) as $$
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
		tabelas := 'select f_table_name, f_geometry_column from geometry_columns where f_table_schema = ''{schema}'' and f_geometry_column=''geometria'' and (type = ''POLYGON'' or type = ''GEOMETRY'') and LEFT(f_table_name, 1) != ''_'' and f_geometry_column = ''geometria'' ';
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
		execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON''', tabela) INTO all_aux;
		-- RAISE NOTICE 'All is % for table %', all_aux, rec.f_table_name;
		count_all := count_all + all_aux;
		-- execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and st_area(geometria) >= %s and ST_Intersects(geometria, %L)', tabela, cvalue, sect) INTO good_aux;
		-- RAISE NOTICE 'Good is % for table %', good_aux, rec.f_table_name;
		-- count_good := count_good + good_aux;
		execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and st_area(geometria) < %s and ST_Intersects(geometria, %L)', tabela, cvalue, sect) INTO bad_aux;
		-- RAISE NOTICE 'Bad is % for table %', bad_aux, rec.f_table_name;
		count_bad := count_bad + bad_aux;
	
		if bad_aux > 0 then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- table without indexes
			tabela_erro := 'errors.' || tabela || '_rg_' || rg;
			-- raise notice '%', tbl;
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
			execute format('delete from %s', tabela_erro);
			execute format('insert into %s select * from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and st_area(geometria) < %s and ST_Intersects(geometria, %L) on conflict do nothing', tabela_erro, tabela, cvalue, sect);
		end if;
	end loop;
	select (count_all - count_bad) into count_good;
return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.rg1_2_validation (rg int, versao int, nd1 boolean, sect geometry, _args json) returns table (total int, good int, bad int) as $$
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

	geom_record RECORD;
begin
	if nd1=true then
		select coalesce(_args->>'rg1_ndd1', '4')::int into cvalue;
	else
		select coalesce(_args->>'rg1_ndd2', '20')::int into cvalue;
	end if;

	if rg = 1 then
		tabelas := 'select f_table_name, f_geometry_column from geometry_columns where f_table_schema = ''{schema}'' and f_geometry_column=''geometria'' and (type = ''POLYGON'' or type = ''GEOMETRY'') and LEFT(f_table_name, 1) != ''_'' and f_geometry_column = ''geometria'' ';
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
		execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON''', tabela) INTO all_aux;
		-- RAISE NOTICE 'All is % for table %', all_aux, rec.f_table_name;
		count_all := count_all + all_aux;
		-- execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and st_area(geometria) >= %s and ST_Intersects(geometria, %s)', tabela, cvalue, sect) INTO good_aux;
		-- RAISE NOTICE 'Good is % for table %', good_aux, rec.f_table_name;
		-- count_good := count_good + good_aux;
		execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and st_area(geometria) < %s and ST_Intersects(geometria, %L)', tabela, cvalue, sect) INTO bad_aux;
		-- RAISE NOTICE 'Bad is % for table %', bad_aux, rec.f_table_name;
		count_bad := count_bad + bad_aux;
	
		if bad_aux > 0 then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- table without indexes
			tabela_erro := 'errors.' || tabela || '_rg_' || rg;
			-- raise notice '%', tbl;
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
			-- execute format('delete from %s', tabela_erro);
			execute format('insert into %s select * from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and st_area(geometria) < %s and ST_Intersects(geometria, %L) on conflict (identificador) do nothing', tabela_erro, tabela, cvalue, sect);
		end if;
	end loop;
	select (count_all - count_bad) into count_good;
return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.rg4_1_validation (ndd integer, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;

	valor_equi integer;
begin
	if ndd=1 then
		select coalesce(_args->>'re3_2_ndd1', '2')::int into valor_equi;
	else
		select coalesce(_args->>'re3_2_ndd2', '5')::int into valor_equi;
	end if;

	CREATE SCHEMA IF NOT EXISTS errors;
		-- table without indexes
		-- raise notice '%', tbl;
	CREATE TABLE IF NOT exists errors.ponto_cotado_rg_4_1 (like {schema}.ponto_cotado INCLUDING ALL);

	delete from errors.ponto_cotado_rg_4_1;

	select count(*) from {schema}.ponto_cotado into count_all;

	WITH dumped_points AS (
		select
			pc.identificador,
			pc.geometria AS ponto_cotado_geom,
			closest_cdn.geometria as cdn_geom,
			(ST_DumpPoints(closest_cdn.geometria)).geom AS dumped_point_geom
		FROM {schema}.ponto_cotado AS pc
		CROSS JOIN LATERAL (
			SELECT geometria
			FROM validation.curva_nivel_tin AS ports
			ORDER BY pc.geometria <-> ports.geometria
			LIMIT 10
		) AS closest_cdn
		),
	z_distances AS (
		select
			identificador,
			abs(st_z(ponto_cotado_geom) - st_z(dumped_point_geom)) AS z_distance
		FROM dumped_points
		),
	min_z_distances AS (
		select
			identificador,
			MIN(z_distance) AS min_z_distance
		FROM z_distances
		GROUP BY identificador
	),
	bad_rows AS (
		INSERT INTO errors.ponto_cotado_rg_4_1
	    SELECT pc.*
	    FROM {schema}.ponto_cotado pc
	    WHERE pc.identificador IN (
			SELECT identificador
	        FROM min_z_distances
	        WHERE min_z_distance > valor_equi)
		RETURNING 1
	)
	SELECT count(*) FROM bad_rows into count_bad;

	select (count_all - count_bad) into count_good;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.rg4_1_validation (ndd integer, sect geometry, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;

	valor_equi integer;
begin
	if ndd=1 then
		select coalesce(_args->>'re3_2_ndd1', '2')::int into valor_equi;
	else
		select coalesce(_args->>'re3_2_ndd2', '5')::int into valor_equi;
	end if;

	CREATE SCHEMA IF NOT EXISTS errors;
		-- table without indexes
		-- raise notice '%', tbl;
	CREATE TABLE IF NOT exists errors.ponto_cotado_rg_4_1 (like {schema}.ponto_cotado INCLUDING ALL);

	delete from errors.ponto_cotado_rg_4_1;

	select count(*) from {schema}.ponto_cotado into count_all;

	WITH dumped_points AS (
		select
			pc.identificador,
			pc.geometria AS ponto_cotado_geom,
			closest_cdn.geometria as cdn_geom,
			(ST_DumpPoints(closest_cdn.geometria)).geom AS dumped_point_geom
		FROM {schema}.ponto_cotado AS pc
		CROSS JOIN LATERAL (
			SELECT geometria
			FROM validation.curva_nivel_tin AS ports
			ORDER BY pc.geometria <-> ports.geometria
			LIMIT 10
		) AS closest_cdn
		where ST_Intersects(pc.geometria, sect)
		),
	z_distances AS (
		select
			identificador,
			abs(st_z(ponto_cotado_geom) - st_z(dumped_point_geom)) AS z_distance
		FROM dumped_points
		),
	min_z_distances AS (
		select
			identificador,
			MIN(z_distance) AS min_z_distance
		FROM z_distances
		GROUP BY identificador
	),
	bad_rows AS (
		INSERT INTO errors.ponto_cotado_rg_4_1
	    SELECT pc.*
	    FROM {schema}.ponto_cotado pc
	    WHERE pc.identificador IN (
			SELECT identificador
	        FROM min_z_distances
	        WHERE min_z_distance > valor_equi)
		RETURNING 1
	)
	SELECT count(*) FROM bad_rows into count_bad;

	select (count_all - count_bad) into count_good;

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
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
			execute format('delete from %s', tabela_erro);
			execute format('insert into %s select t.* from {schema}.%I t, {schema}.area_trabalho adt
				where not St_Contains(adt.geometria, t.geometria)', tabela_erro, tabela);
		end if;
	end loop;
	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.rg5_validation(sect geometry) returns table (total int, good int, bad int) as $$
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
			where ST_Intersects(t.geometria, %L) and St_Contains(adt.geometria, t.geometria)', tabela, sect) INTO good_aux;
		RAISE NOTICE 'Good is % for table %', good_aux, tabela;
		count_good := count_good + good_aux;
	
		execute format('select count(t.*) from {schema}.%I t, {schema}.area_trabalho adt
			where ST_Intersects(t.geometria, %L) and not St_Contains(adt.geometria, t.geometria)', tabela, sect) INTO bad_aux;
		RAISE NOTICE 'Bad is % for table %', bad_aux, tabela;
		count_bad := count_bad + bad_aux;

		if bad_aux > 0 then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- table without indexes
			tabela_erro := 'errors.' || tabela || '_rg_5';
			-- raise notice '%', tbl;
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
			execute format('delete from %s', tabela_erro);
			execute format('insert into %s select t.* from {schema}.%I t, {schema}.area_trabalho adt
				where ST_Intersects(t.geometria, %L) and not St_Contains(adt.geometria, t.geometria)', tabela_erro, tabela, sect);
		end if;
	end loop;
	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

-- select * from validation.rg5_validation ();
create or replace function validation.rg5_validation_v2 () returns table (total int, good int, bad int) as $$
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
	tabelas = array['agua_lentica', 'curso_de_agua_area', 'terreno_marginal', 'zona_humida', 'area_infra_trans_aereo', 'area_agricola_florestal_mato', 'areas_artificializadas'];

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
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
			execute format('delete from %s', tabela_erro);
			execute format('insert into %s select t.* from {schema}.%I t, {schema}.area_trabalho adt
				where not St_Contains(adt.geometria, t.geometria)', tabela_erro, tabela);
		end if;
	end loop;
	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.rg5_validation_v2(sect geometry) returns table (total int, good int, bad int) as $$
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
	tabelas = array['agua_lentica', 'curso_de_agua_area', 'terreno_marginal', 'zona_humida', 'area_infra_trans_aereo', 'area_agricola_florestal_mato', 'areas_artificializadas'];

	for tabela in select unnest(tabelas)
	loop 
		RAISE NOTICE '-------------------------- table % -------------------------------------------------', tabela;
		execute format('select count(*) from {schema}.%I', tabela) INTO all_aux;
		RAISE NOTICE 'All is % for table %', all_aux, tabela;
		count_all := count_all + all_aux;
	
		execute format('select count(t.*) from {schema}.%I t, {schema}.area_trabalho adt
			where ST_Intersects(t.geometria, %L) and St_Contains(adt.geometria, t.geometria)', tabela, sect) INTO good_aux;
		RAISE NOTICE 'Good is % for table %', good_aux, tabela;
		count_good := count_good + good_aux;
	
		execute format('select count(t.*) from {schema}.%I t, {schema}.area_trabalho adt
			where ST_Intersects(t.geometria, %L) and not St_Contains(adt.geometria, t.geometria)', tabela, sect) INTO bad_aux;
		RAISE NOTICE 'Bad is % for table %', bad_aux, tabela;
		count_bad := count_bad + bad_aux;

		if bad_aux > 0 then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- table without indexes
			tabela_erro := 'errors.' || tabela || '_rg_5';
			-- raise notice '%', tbl;
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
			execute format('delete from %s', tabela_erro);
			execute format('insert into %s select t.* from {schema}.%I t, {schema}.area_trabalho adt
				where ST_Intersects(t.geometria, %L) and not St_Contains(adt.geometria, t.geometria)', tabela_erro, tabela, sect);
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
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
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
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
			execute format('delete from %s', tabela_erro);
			execute format('insert into %s select * from {schema}.%I where validation.valid_noabbr(%s)<>true', tabela_erro, tabela, coluna);
		end if;
	end loop;
return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;


create or replace function validation.descontinuidades_seg_via_rodov_quadrantes () returns table (p1_id uuid, p2_id uuid, dist_p1_p2 double precision, p1_endpoint_geom geometry) as $$
begin
	return query WITH p AS (
		SELECT  {schema}.seg_via_rodov.identificador AS id, {schema}.st_startpoint(seg_via_rodov.geometria) AS geom
			FROM {schema}.seg_via_rodov
		UNION
		SELECT  {schema}.seg_via_rodov.identificador, {schema}.st_endpoint(seg_via_rodov.geometria) AS geom
			FROM {schema}.seg_via_rodov
	), q AS (
		SELECT  p.id, p.geom, trunc(ST_X(p.geom)/100)::text || ',' || trunc(ST_Y(p.geom)/100)::text AS quad
			FROM p
	)
	SELECT p1.id AS p1_id, p2.id AS p2_id, st_3ddistance(p1.geom, p2.geom) AS dist_p1_p2,
	 st_setsrid((p1.geom)::geometry(PointZ), 3763) AS p1_endpoint_geom
		FROM (q p1
			JOIN q p2 ON p1.quad = p2.quad
			 AND (((st_3ddistance(p1.geom, p2.geom) <> (0)::double precision) AND (st_3ddistance(p1.geom, p2.geom) < (0.2)::double precision)))
		);
end;
$$ language plpgsql;

create or replace function validation.descontinuidades_seg_via_rodov_quadrantes (sect geometry) returns table (p1_id uuid, p2_id uuid, dist_p1_p2 double precision, p1_endpoint_geom geometry) as $$
begin
	return query WITH p AS (
		SELECT  {schema}.seg_via_rodov.identificador AS id, {schema}.st_startpoint(seg_via_rodov.geometria) AS geom
			FROM {schema}.seg_via_rodov
			where ST_Intersects(seg_via_rodov.geometria, sect)
		UNION
		SELECT  {schema}.seg_via_rodov.identificador, {schema}.st_endpoint(seg_via_rodov.geometria) AS geom
			FROM {schema}.seg_via_rodov
			where ST_Intersects(seg_via_rodov.geometria, sect)
	), q AS (
		SELECT  p.id, p.geom, trunc(ST_X(p.geom)/100)::text || ',' || trunc(ST_Y(p.geom)/100)::text AS quad
			FROM p
	)
	SELECT p1.id AS p1_id, p2.id AS p2_id, st_3ddistance(p1.geom, p2.geom) AS dist_p1_p2,
	 st_setsrid((p1.geom)::geometry(PointZ), 3763) AS p1_endpoint_geom
		FROM (q p1
			JOIN q p2 ON p1.quad = p2.quad
			 AND (((st_3ddistance(p1.geom, p2.geom) <> (0)::double precision) AND (st_3ddistance(p1.geom, p2.geom) < (0.2)::double precision)))
		);
end;
$$ language plpgsql;


create or replace function validation.valid_simple () returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;

	all_aux integer;
	bad_aux integer;

	tabela text;
	tabelas text;
	tabela_erro text;
begin
	tabelas := 'select f_table_name, f_geometry_column from geometry_columns where f_table_schema = ''{schema}'' and (type = ''LINESTRING'') and LEFT(f_table_name, 1) != ''_'' and f_geometry_column = ''geometria''';
	for tabela in execute tabelas
	loop
		execute format('select count(*) from {schema}.%I', tabela) INTO all_aux;
		count_all := count_all + all_aux;

		execute format('select count(*) from {schema}.%I where not st_issimple(geometria)', tabela) INTO bad_aux;
		count_bad := count_bad + bad_aux;

		if bad_aux > 0 then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- table without indexes
			tabela_erro := 'errors.' || tabela || '_pq2_4_1';
			-- raise notice '%', tbl;
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
			execute format('delete from %s', tabela_erro);
			execute format('ALTER TABLE %s ADD COLUMN IF NOT EXISTS motivo TEXT NULL', tabela_erro);

			execute format('insert into %s select t.*, ''not simple'' from {schema}.%I t where not st_issimple(geometria) ON CONFLICT (identificador) DO NOTHING', tabela_erro, tabela);
		end if;
	end loop;

	tabelas := 'select f_table_name, f_geometry_column from geometry_columns where f_table_schema = ''{schema}'' and (type = ''POLYGON'' or type = ''MULTIPOLYGON'') and coord_dimension = 2 and LEFT(f_table_name, 1) != ''_'' and f_geometry_column = ''geometria''';
	for tabela in execute tabelas
	loop
		execute format('select count(*) from {schema}.%I', tabela) INTO all_aux;
		count_all := count_all + all_aux;

		execute format('select count(*) from {schema}.%I where not st_isvalid(geometria)', tabela) INTO bad_aux;
		count_bad := count_bad + bad_aux;

		if bad_aux > 0 then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- table without indexes
			tabela_erro := 'errors.' || tabela || '_pq2_4_1';
			-- raise notice '%', tbl;
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
			execute format('delete from %s', tabela_erro);
			execute format('insert into %s select t.*, st_isvalidreason(geometria) from {schema}.%I t where not st_isvalid(geometria) ON CONFLICT (identificador) DO NOTHING', tabela_erro, tabela);
		end if;
	end loop;

	select (count_all - count_bad) into count_good;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.valid_simple (sect geometry) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;

	all_aux integer;
	bad_aux integer;

	tabela text;
	tabelas text;
	tabela_erro text;
begin
	tabelas := 'select f_table_name, f_geometry_column from geometry_columns where f_table_schema = ''{schema}'' and (type = ''LINESTRING'') and LEFT(f_table_name, 1) != ''_'' and f_geometry_column = ''geometria''';
	for tabela in execute tabelas
	loop
		execute format('select count(*) from {schema}.%I', tabela) INTO all_aux;
		count_all := count_all + all_aux;

		execute format('select count(*) from {schema}.%I where not st_issimple(geometria) and ST_Intersects(geometria, %L)', tabela, sect) INTO bad_aux;
		count_bad := count_bad + bad_aux;

		if bad_aux > 0 then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- table without indexes
			tabela_erro := 'errors.' || tabela || '_pq2_4_1';
			-- raise notice '%', tbl;
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
			execute format('ALTER TABLE %s ADD COLUMN IF NOT EXISTS motivo TEXT NULL', tabela_erro);

			execute format('insert into %s select t.*, ''not simple'' from {schema}.%I t where not st_issimple(geometria) and ST_Intersects(geometria, %L) ON CONFLICT (identificador) DO NOTHING', tabela_erro, tabela, sect);
		end if;
	end loop;

	tabelas := 'select f_table_name, f_geometry_column from geometry_columns where f_table_schema = ''{schema}'' and (type = ''POLYGON'' or type = ''MULTIPOLYGON'') and coord_dimension = 2 and LEFT(f_table_name, 1) != ''_'' and f_geometry_column = ''geometria''';
	for tabela in execute tabelas
	loop
		execute format('select count(*) from {schema}.%I', tabela) INTO all_aux;
		count_all := count_all + all_aux;

		execute format('select count(*) from {schema}.%I where not st_isvalid(geometria) and ST_Intersects(geometria, %L)', tabela, sect) INTO bad_aux;
		count_bad := count_bad + bad_aux;

		if bad_aux > 0 then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- table without indexes
			tabela_erro := 'errors.' || tabela || '_pq2_4_1';
			-- raise notice '%', tbl;
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
			execute format('insert into %s select t.*, st_isvalidreason(geometria) from {schema}.%I t where not st_isvalid(geometria) and ST_Intersects(geometria, %L) ON CONFLICT (identificador) DO NOTHING', tabela_erro, tabela, sect);
		end if;
	end loop;

	select (count_all - count_bad) into count_good;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;


create or replace function validation.pq2_4_1_validation () returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;

	all_aux integer := 0;
	good_aux integer := 0;
	bad_aux integer := 0;

	rec_aux RECORD;

	tabela text;
	tabela_erro text;

	p1_id uuid;
	p2_id uuid;
	dist_p1_p2 numeric;
	p1_endpoint_geom geometry;
begin
	-- descontinuidades seg_via_rodov
	select count(*) from {schema}.seg_via_rodov into count_all;

	CREATE SCHEMA IF NOT EXISTS errors;
	tabela := 'descontinuidades';
	tabela_erro := 'errors.' || tabela || '_pq2_4_1';
	execute format('CREATE TABLE IF NOT exists %s (like validation.%I INCLUDING ALL)', tabela_erro, tabela);

	execute format('delete from %s', tabela_erro);
	execute format(
		'with bad_rows AS (
			INSERT INTO %s
			SELECT * from validation.descontinuidades_seg_via_rodov_quadrantes()
			RETURNING 1
		)
		SELECT count(*) FROM bad_rows', tabela_erro) into count_bad;

	-- intersecoes curva_de_nivel
	-- select count(*) from {schema}.curva_de_nivel into all_aux;
	-- count_all := count_all + all_aux;

	-- tabela := 'intersecoes_2d';
	-- tabela_erro := 'errors.' || tabela || '_pq2_4_1';
	-- execute format('CREATE TABLE IF NOT exists %s (like validation.%I INCLUDING ALL)', tabela_erro, tabela);

	-- execute format(
	-- 	'with bad_rows AS (
	-- 		INSERT INTO %s
	-- 		SELECT a.identificador AS id1, b.identificador AS id2, ST_Intersection(st_force2d(a.geometria), st_force2d(b.geometria))
	-- 			FROM {schema}.curva_de_nivel a
	--  		JOIN {schema}.curva_de_nivel b ON a.geometria && b.geometria AND a.identificador <> b.identificador AND st_intersects(st_force2d(a.geometria), st_force2d(b.geometria))
	-- 		RETURNING 1
	-- 	)
	-- 	SELECT count(*) FROM bad_rows', tabela_erro) into bad_aux;
	-- count_bad := count_bad + bad_aux;

	-- valid geometries (is_valid && is_simple)
	rec_aux := (select validation.valid_simple());
	count_all := count_all + rec_aux.total;
	count_bad := count_bad + rec_aux.bad;

	select (count_all - count_bad) into count_good;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.pq2_4_1_validation (sect geometry) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;

	all_aux integer := 0;
	good_aux integer := 0;
	bad_aux integer := 0;

	rec_aux RECORD;

	tabela text;
	tabela_erro text;

	p1_id uuid;
	p2_id uuid;
	dist_p1_p2 numeric;
	p1_endpoint_geom geometry;
begin
	-- descontinuidades seg_via_rodov
	select count(*) from {schema}.seg_via_rodov into count_all;

	CREATE SCHEMA IF NOT EXISTS errors;
	tabela := 'descontinuidades';
	tabela_erro := 'errors.' || tabela || '_pq2_4_1';
	execute format('CREATE TABLE IF NOT exists %s (like validation.%I INCLUDING ALL)', tabela_erro, tabela);

	execute format(
		'with bad_rows AS (
			INSERT INTO %s
			SELECT * from validation.descontinuidades_seg_via_rodov_quadrantes(%L)
			RETURNING 1
		)
		SELECT count(*) FROM bad_rows', tabela_erro, sect) into count_bad;

	-- intersecoes curva_de_nivel
	-- select count(*) from {schema}.curva_de_nivel into all_aux;
	-- count_all := count_all + all_aux;

	-- tabela := 'intersecoes_2d';
	-- tabela_erro := 'errors.' || tabela || '_pq2_4_1';
	-- execute format('CREATE TABLE IF NOT exists %s (like validation.%I INCLUDING ALL)', tabela_erro, tabela);

	-- execute format(
	-- 	'with bad_rows AS (
	-- 		INSERT INTO %s
	-- 		SELECT a.identificador AS id1, b.identificador AS id2, ST_Intersection(st_force2d(a.geometria), st_force2d(b.geometria))
	-- 			FROM {schema}.curva_de_nivel a
	--  		JOIN {schema}.curva_de_nivel b ON a.geometria && b.geometria AND a.identificador <> b.identificador AND st_intersects(st_force2d(a.geometria), st_force2d(b.geometria))
	-- 		WHERE ST_Intersects(a.geometria, %L)
	-- 		RETURNING 1
	-- 	)
	-- 	SELECT count(*) FROM bad_rows', tabela_erro, sect) into bad_aux;
	-- count_bad := count_bad + bad_aux;

	-- valid geometries (is_valid && is_simple)
	rec_aux := (select validation.valid_simple());
	count_all := count_all + rec_aux.total;
	count_bad := count_bad + rec_aux.bad;

	select (count_all - count_bad) into count_good;

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
		execute format('create table if not exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
		execute format('delete from %s', tabela_erro);
		execute format('insert into %s select * from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and st_area(geometria) < %s', tabela_erro, tabela, minv);
	end if;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;


create or replace function validation.rg_min_area (rg text, tabela text, minv int, sect geometry) returns table (total int, good int, bad int) as $$
declare 
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;

	tabela_erro text;
begin
	execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON''', tabela) into count_all;
	execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and ST_Intersects(geometria, %L) and st_area(geometria) >= %s', tabela, sect, minv) into count_good;
	execute format('select count(*) from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and ST_Intersects(geometria, %L) and st_area(geometria) < %s', tabela, sect, minv) into count_bad;

	if count_bad > 0 then
		create schema if not exists errors;
		-- table without indexes
		tabela_erro := 'errors.' || tabela || '_' || rg;
		-- raise notice '%', tbl;
		execute format('create table if not exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
		execute format('delete from %s', tabela_erro);
		execute format('insert into %s select * from {schema}.%I where geometrytype(geometria) = ''POLYGON'' and ST_Intersects(geometria, %L) and st_area(geometria) < %s', tabela_erro, tabela, sect, minv);
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

	valor_equi integer := case when ndd = 1 then 2 else 5 end;
begin
	CREATE SCHEMA IF NOT EXISTS errors;
		-- table without indexes
		-- raise notice '%', tbl;
	CREATE TABLE IF NOT exists errors.curva_de_nivel_re3_2 (like {schema}.curva_de_nivel INCLUDING ALL);

	delete from errors.curva_de_nivel_re3_2;

	select count(*) from {schema}.curva_de_nivel into count_all;

	WITH pares AS (
        SELECT 
            all_cdn.identificador,
            round(abs(st_z(ST_PointN(all_cdn.geometria, 1)) - st_z(ST_PointN(closest_cdn.geometria, 1)))::numeric, 2) AS z_distance
        FROM {schema}.curva_de_nivel AS all_cdn
        CROSS JOIN LATERAL (
            SELECT geometria
            FROM {schema}.curva_de_nivel AS ports
            WHERE all_cdn.identificador != ports.identificador
              AND valor_tipo_curva IN ('1','2')
            ORDER BY ST_PointN(all_cdn.geometria, 1) <-> ports.geometria
            LIMIT 1
        ) AS closest_cdn
        WHERE all_cdn.valor_tipo_curva IN ('1','2')
    ),
    bad_rows AS (        
		INSERT INTO errors.curva_de_nivel_re3_2
	    SELECT cn.*
	    FROM {schema}.curva_de_nivel cn
	    WHERE cn.identificador IN (
			SELECT identificador
	        FROM pares
	        WHERE NOT (z_distance = 0 OR z_distance = valor_equi))
		RETURNING 1
    )
	SELECT count(*) FROM bad_rows into count_bad;

	select (count_all - count_bad) into count_good;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

-- select * from validation.re3_2_validation ();
create or replace function validation.re3_2_validation (ndd integer, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;

	valor_equi integer;
begin
	if ndd=1 then
		select coalesce(_args->>'re3_2_ndd1', '2')::int into valor_equi;
	else
		select coalesce(_args->>'re3_2_ndd2', '5')::int into valor_equi;
	end if;

	CREATE SCHEMA IF NOT EXISTS errors;
		-- table without indexes
		-- raise notice '%', tbl;
	CREATE TABLE IF NOT exists errors.curva_de_nivel_re3_2 (like {schema}.curva_de_nivel INCLUDING ALL);

	delete from errors.curva_de_nivel_re3_2;

	select count(*) from {schema}.curva_de_nivel into count_all;

	WITH pares AS (
        SELECT 
            all_cdn.identificador,
            round(abs(st_z(ST_PointN(all_cdn.geometria, 1)) - st_z(ST_PointN(closest_cdn.geometria, 1)))::numeric, 2) AS z_distance
        FROM {schema}.curva_de_nivel AS all_cdn
        CROSS JOIN LATERAL (
            SELECT geometria
            FROM {schema}.curva_de_nivel AS ports
            WHERE all_cdn.identificador != ports.identificador
              AND valor_tipo_curva IN ('1','2')
            ORDER BY ST_PointN(all_cdn.geometria, 1) <-> ports.geometria
            LIMIT 1
        ) AS closest_cdn
        WHERE all_cdn.valor_tipo_curva IN ('1','2')
    ),
    bad_rows AS (        
		INSERT INTO errors.curva_de_nivel_re3_2
	    SELECT cn.*
	    FROM {schema}.curva_de_nivel cn
	    WHERE cn.identificador IN (
			SELECT identificador
	        FROM pares
	        WHERE NOT (z_distance = 0 OR z_distance = valor_equi))
		RETURNING 1
    )
	SELECT count(*) FROM bad_rows into count_bad;

	select (count_all - count_bad) into count_good;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

CREATE OR REPLACE FUNCTION validation.re3_2_validation(ndd integer, sect geometry)
 RETURNS TABLE(total integer, good integer, bad integer)
 LANGUAGE plpgsql
AS $function$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;

	valor_equi integer := case when ndd = 1 then 2 else 5 end;
begin
	CREATE SCHEMA IF NOT EXISTS errors;
		-- table without indexes
		-- raise notice '%', tbl;
	CREATE TABLE IF NOT exists errors.curva_de_nivel_re3_2 (like public.curva_de_nivel INCLUDING ALL);

	delete from errors.curva_de_nivel_re3_2;

	execute format('select count(*) from {schema}.curva_de_nivel') into count_all;

	execute format(
		'WITH pares AS ('
			'SELECT '
				'all_cdn.identificador,'
				'round(abs(st_z(ST_PointN(all_cdn.geometria, 1)) - st_z(ST_PointN(closest_cdn.geometria, 1)))::numeric, 2) AS z_distance '
			'FROM {schema}.curva_de_nivel AS all_cdn '
			'CROSS JOIN LATERAL ('
				'SELECT geometria '
				'FROM {schema}.curva_de_nivel AS ports '
				'WHERE ST_Intersects(ports.geometria, %1$L) and all_cdn.identificador != ports.identificador '
				'AND valor_tipo_curva IN (''1'',''2'')'
				'ORDER BY ST_PointN(all_cdn.geometria, 1) <-> ports.geometria '
				'LIMIT 1 '
			') AS closest_cdn '
			'WHERE ST_Intersects(all_cdn.geometria, %1$L) and all_cdn.valor_tipo_curva IN (''1'',''2'')'
		'),'
		'bad_rows AS ('
			'INSERT INTO errors.curva_de_nivel_re3_2 '
			'SELECT cn.* '
			'FROM {schema}.curva_de_nivel cn '
			'WHERE cn.identificador IN ('
				'SELECT identificador '
				'FROM pares '
				'WHERE NOT (z_distance = 0 OR z_distance = %2$L)) '
			'ON CONFLICT (identificador) DO NOTHING '
			'RETURNING 1 '
		')'
		'SELECT count(*) FROM bad_rows;'
	, sect, valor_equi) into count_bad;

	select (count_all - count_bad) into count_good;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$function$
;

CREATE OR REPLACE FUNCTION validation.re3_2_validation(ndd integer, sect geometry, _args json)
 RETURNS TABLE(total integer, good integer, bad integer)
 LANGUAGE plpgsql
AS $function$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;

	valor_equi integer;
begin
	if ndd=1 then
		select coalesce(_args->>'re3_2_ndd1', '2')::int into valor_equi;
	else
		select coalesce(_args->>'re3_2_ndd2', '5')::int into valor_equi;
	end if;

	CREATE SCHEMA IF NOT EXISTS errors;
		-- table without indexes
		-- raise notice '%', tbl;
	CREATE TABLE IF NOT exists errors.curva_de_nivel_re3_2 (like public.curva_de_nivel INCLUDING ALL);

	delete from errors.curva_de_nivel_re3_2;

	execute format('select count(*) from {schema}.curva_de_nivel') into count_all;

	execute format(
		'WITH pares AS ('
			'SELECT '
				'all_cdn.identificador,'
				'round(abs(st_z(ST_PointN(all_cdn.geometria, 1)) - st_z(ST_PointN(closest_cdn.geometria, 1)))::numeric, 2) AS z_distance '
			'FROM {schema}.curva_de_nivel AS all_cdn '
			'CROSS JOIN LATERAL ('
				'SELECT geometria '
				'FROM {schema}.curva_de_nivel AS ports '
				'WHERE ST_Intersects(ports.geometria, %1$L) and all_cdn.identificador != ports.identificador '
				'AND valor_tipo_curva IN (''1'',''2'')'
				'ORDER BY ST_PointN(all_cdn.geometria, 1) <-> ports.geometria '
				'LIMIT 1 '
			') AS closest_cdn '
			'WHERE ST_Intersects(all_cdn.geometria, %1$L) and all_cdn.valor_tipo_curva IN (''1'',''2'')'
		'),'
		'bad_rows AS ('
			'INSERT INTO errors.curva_de_nivel_re3_2 '
			'SELECT cn.* '
			'FROM {schema}.curva_de_nivel cn '
			'WHERE cn.identificador IN ('
				'SELECT identificador '
				'FROM pares '
				'WHERE NOT (z_distance = 0 OR z_distance = %2$L)) '
			'ON CONFLICT (identificador) DO NOTHING '
			'RETURNING 1 '
		')'
		'SELECT count(*) FROM bad_rows;'
	, sect, valor_equi) into count_bad;

	select (count_all - count_bad) into count_good;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$function$
;

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
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);

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

create or replace function validation.re4_10_validation (sect geometry) returns table (total int, good int, bad int) as $$
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
		execute format('select count(*) from {schema}.%I where ST_Intersects(geometria, %L)', tabela, sect) INTO all_aux;
		RAISE NOTICE 'All is % for table %', all_aux, tabela;
		count_all := count_all + all_aux;

		if tabela='barreira' then
			tipo_no := '6';
		else
			tipo_no := '5';
		end if;

		execute format('select count(t.*) from {schema}.%I t, {schema}.no_hidrografico nh
			where ST_Intersects(t.geometria, %3$L) and St_intersects(t.geometria, nh.geometria) and nh.valor_tipo_no_hidrografico=''%2$s''', tabela, tipo_no, sect) INTO good_aux;

		RAISE NOTICE 'Good is % for table %', good_aux, tabela;
		count_good := count_good + good_aux;

		execute format('select count(t.*) from {schema}.%1$I t
			where ST_Intersects(geometria, %3$L) and (not (select ST_intersects(t.geometria, f.geometria) from 
					(select geom_col as geometria from validation.no_hidro) as f)
				or t.identificador not in (select distinct ta.identificador from {schema}.%1$I ta, {schema}.no_hidrografico nh 
					where St_intersects(ta.geometria, nh.geometria) and nh.valor_tipo_no_hidrografico=''%2$s''))', tabela, tipo_no, sect) INTO bad_aux;
	
		RAISE NOTICE 'Bad is % for table %', bad_aux, tabela;
		count_bad := count_bad + bad_aux;

		if bad_aux > 0 then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- table without indexes
			tabela_erro := 'errors.' || tabela || '_re4_10_1';
			-- raise notice '%', tbl;
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);

			execute format('delete from %1$s', tabela_erro);
			execute format('insert into %1$s select t.* from {schema}.%2$I t
				where ST_Intersects(geometria, %4$L) and (not (select ST_intersects(t.geometria, f.geometria) from 
						(select geom_col as geometria from validation.no_hidro) as f)
					or t.identificador not in (select distinct ta.identificador from {schema}.%2$I ta, {schema}.no_hidrografico nh 
						where St_intersects(ta.geometria, nh.geometria) and nh.valor_tipo_no_hidrografico=''%3$s''))', tabela_erro, tabela, tipo_no, sect);
		end if;
	end loop;
	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

--
-- supporting tables...
--

-- feedback visual do ponto_cotado à curva de nível mais próxima
/* create table validation.ponto_cotado_curva_de_nivel_proxima as
SELECT
  pc.identificador, 
  closest_cdn.identificador as identificador_mais_proximo,
  abs( st_z(pc.geometria) - st_z(ST_PointN(closest_cdn.geometria, 1))) as z_distance,
  ST_MakeLine( pc.geometria, ST_ClosestPoint(closest_cdn.geometria, pc.geometria)) as geometria
 FROM public.ponto_cotado as pc
CROSS JOIN LATERAL 
  (SELECT
      identificador, 
      geometria
      FROM public.curva_de_nivel ports
      ORDER BY pc.geometria <-> ports.geometria
     LIMIT 1
   ) AS closest_cdn; */

-- feedback visual da relação entre curvas de nível
/* create table validation.curva_de_nivel_proxima as
SELECT
  all_cdn.identificador, 
  closest_cdn.identificador as identificador_mais_proximo,
  round( abs(st_z(ST_PointN(all_cdn.geometria, 1)) - st_z(ST_PointN(closest_cdn.geometria, 1)))::numeric, 2) as z_distance,
  ST_MakeLine( ST_PointN(all_cdn.geometria, 1), ST_ClosestPoint(closest_cdn.geometria, ST_PointN(all_cdn.geometria, 1))) as geometria
 FROM public.curva_de_nivel as all_cdn
CROSS JOIN LATERAL 
  (SELECT
      identificador, 
      geometria
      FROM public.curva_de_nivel ports
      where all_cdn.identificador != ports.identificador
      ORDER BY ST_PointN(all_cdn.geometria, 1) <-> ports.geometria
     LIMIT 1
   ) AS closest_cdn; */

/* drop table if exists validation.curva_de_nivel_equidistancia;
create table validation.curva_de_nivel_equidistancia as
SELECT
  all_cdn.*,
  closest_cdn.identificador as identificador_mais_proximo,
  st_zmax(all_cdn.geometria) as z, 
  st_zmax(closest_cdn.geometria) as z_mais_proximo, 
  abs(st_zmax(all_cdn.geometria) - st_zmax(closest_cdn.geometria)) as equidistancia,
  closest_cdn.dist as distancia
 FROM {schema}.curva_de_nivel as all_cdn
CROSS JOIN LATERAL 
  (SELECT
      identificador, 
      geometria,
      ST_Distance(ports.geometria, all_cdn.geometria) as dist
      FROM {schema}.curva_de_nivel ports
      where all_cdn.identificador != identificador
      ORDER BY all_cdn.geometria <-> ports.geometria
     LIMIT 1
   ) AS closest_cdn; */

-- Compute DEM resolution parameters: /2 |  /4
--
/* with sources as (
	select st_union(geometria) as geometria
	from {schema}.curva_de_nivel
	union	
	select st_union(geometria) as geometria
	from {schema}.ponto_cotado
	union
	select st_union(geometria) as geometria
	from {schema}.area_trabalho
), envelope as (
select ST_Envelope(st_union(geometria)) as geometria
from sources
) select ' -txe ' || round(st_xmin(geometria)) || ' ' || round(st_xmax(geometria)) || 
' -tye ' || round(st_ymin(geometria)) || ' ' || round(st_ymax(geometria)) || 
' -outsize ' || round((st_xmax(geometria)-st_xmin(geometria))/4) || ' ' ||
round((st_ymax(geometria)-st_ymin(geometria))/4) 
from envelope;
 */
-- for first DEM (CDN)
-- gdal_grid -l validation.curva_de_nivel_points_interval -a_srs EPSG:3763 -a linear -ot Float32 -of GTiff -txe -48658 -38737 -tye 167016 171072 -outsize 2480 1014 "PG:host=localhost port=5433 user=geobox dbname=homologacao sslmode=disable" dem_linear_cdn.tif --config GDAL_NUM_THREADS ALL_CPUS
-- usar tiles, por questões de performance
-- /usr/lib/postgresql/12/bin/raster2pgsql -t 200x200 -s 3763 -d -C -M -I dem_linear_cdn.tif validation.dem_linear_cdn | psql -h localhost -p 5433 -U geobox homologacao
-- for DEM (CDN +PC)  
-- gdal_grid -l validation.curva_de_nivel_ponto_cotado -a_srs EPSG:3763 -a linear -ot Float32 -of GTiff -txe -48658 -38737 -tye 167016 171072 -outsize 2480 1014 "PG:host=localhost port=5433 user=geobox dbname=homologacao sslmode=disable" dem_linear_cdn_pc.tif --config GDAL_NUM_THREADS ALL_CPUS
-- /usr/lib/postgresql/12/bin/raster2pgsql -t 200x200 -s 3763 -d -C -M -I dem_linear_cdn_pc.tif validation.dem_linear_cdn_pc | psql -h localhost -p 5433 -U geobox homologacao
-- gdal_grid -l validation.curva_de_nivel_ponto_cotado -a_srs EPSG:3763 -a linear -ot Float32 -of GTiff -txe -24000 -22400 -tye 237000 238000 -outsize 400 250 "PG:service=ortos" dem_linear_cdn_pc.tif --config GDAL_NUM_THREADS ALL_CPUS

-- primeiro e último ponto da curva de nível
-- um ponto intercalar a cada 10 metros, para curvas de nível com mais de 10 metros
--
-- drop table if exists validation.curva_de_nivel_points_interval;
-- create table validation.curva_de_nivel_points_interval as
-- SELECT concat( identificador::text, '-', path[1]::text) as identificador, geom::geometry(POINTZ, 3763) as geometria
-- FROM (
-- SELECT cdn.identificador, (ST_DumpPoints(ST_LineInterpolatePoints(geometria, 10.0/st_length(geometria)))).*
-- from (select identificador, (ST_Dump(geometria)).geom as geometria from {schema}.curva_de_nivel) as cdn
-- where st_length(geometria) > 10.0
-- ) as pontos
-- union SELECT concat( identificador::text, '-0') as identificador, ST_PointN(geometria, 1) as geometria
-- from {schema}.curva_de_nivel cdn
-- union SELECT concat( identificador::text, '-', ST_NPoints(geometria)) as identificador, ST_PointN(geometria, -1) as geometria
-- from {schema}.curva_de_nivel cdn;


-- drop table if exists validation.curva_de_nivel_ponto_cotado;
-- create table validation.curva_de_nivel_ponto_cotado as
-- SELECT pc.identificador::text, pc.geometria
-- from {schema}.ponto_cotado pc, {schema}.valor_classifica_las vc 
-- where pc.valor_classifica_las = vc.identificador and vc.descricao = 'Terreno'
-- union
-- select * 
-- from validation.curva_de_nivel_points_interval;

-- CREATE TABLE IF NOT EXISTS validation.tin (
--     id integer generated by default as identity NOT NULL PRIMARY KEY,
--     geometria geometry(POLYGONZ, 3763) not null
-- );

-- insert into validation.tin ( geometria)
-- with tin as (SELECT ST_DelaunayTriangles(st_union(geometria)) as geom
-- from validation.curva_de_nivel_ponto_cotado cnpc)
-- select (ST_Dump(geom)).geom As geometria from tin;

create or replace function validation.create_tin() returns void as $$
begin
	-- test if table exists and has rows
	if (select count(*) from information_schema.tables where table_schema='validation' and table_name='curva_nivel_tin') = 0 then

		drop table if exists validation.curva_nivel_tin;
		create table validation.curva_nivel_tin (
			id int4 GENERATED BY DEFAULT AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 NO CYCLE) NOT null,
			geometria public.geometry(polygonz, 3763) NOT null
		);

		drop table if exists validation.curva_de_nivel_points_interval_v2;
		create table validation.curva_de_nivel_points_interval_v2 as
			SELECT concat( identificador::text, '-', path[1]::text) as identificador, geom::geometry(POINTZ, 3763) as geometria
			FROM (
				SELECT cdn.identificador, (ST_DumpPoints(ST_LineInterpolatePoints(geometria, least(8.0/st_length(geometria), 1.0)))).*
					from (select identificador, (ST_Dump(geometria)).geom as geometria from public.curva_de_nivel) as cdn
			) as pontos
			union SELECT concat( identificador::text, '-0') as identificador, ST_PointN(geometria, 1) as geometria
				from public.curva_de_nivel cdn
			union SELECT concat( identificador::text, '-', ST_NPoints(geometria)) as identificador, ST_PointN(geometria, -1) as geometria
				from public.curva_de_nivel cdn;

		insert into validation.curva_nivel_tin (geometria)
		with tin as (
			SELECT ST_DelaunayTriangles(st_union(geometria)) as geom
			from validation.curva_de_nivel_points_interval_v2
		) select (ST_Dump(geom)).geom As geometria from tin;

		CREATE INDEX curva_nivel_tin_geom_idx ON validation.curva_nivel_tin USING gist (geometria);
	end if;
end;
$$ language plpgsql;

select validation.create_tin();

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

CREATE INDEX IF NOT EXISTS idx_val_curso_de_agua_eixo_geometria ON {schema}.curso_de_agua_eixo USING GIST (geometria);
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
CREATE INDEX IF NOT EXISTS idx_val_juncao_fluxo_dattr_geom ON validation.juncao_fluxo_dattr USING GIST (geom_col);

-- drop index IF EXISTS validation.tin_geom_idx;
-- create index tin_geom_idx ON validation.tin using gist(geometria);

-- tabela para acumular os possíveis erros de consistência 3D
-- id_1, id_2 - ids dos elementos que se intersetam em 2D, mas não em 3D
-- tabela_1, tabela_2 - tabelas dos elementos que estão inconsistentes
-- geom_1, geom_2 - geometria dos elementos que estão inconsistentes
-- p_intersecao - ponto de interseção entre as duas geometrias (resulta de ST_Intersection)
-- p1_intersecao - ponto da geom_1 mais próximo do ponto de interseção
-- p2_intersecao - ponto da geom_2 mais próximo do ponto de interseção
-- delta_z - diferença de cota entre os pontos de interseção
-- regra - regra que foi violada
CREATE TABLE IF NOT EXISTS validation.intersecoes_3d (
	id_1 uuid NULL,
	id_2 uuid NULL,
	tabela_1 text NULL,
	tabela_2 text NULL,
	geom_1 public.geometry(linestringz, 3763) NULL,
	geom_2 public.geometry(linestringz, 3763) NULL,
	geometria public.geometry(pointz, 3763) NOT NULL,
	p1_intersecao public.geometry(pointz, 3763) NULL,
	p2_intersecao public.geometry(pointz, 3763) NULL,
	delta_z float8 null,
	regra text NULL
);

-- As copias desta tabela terão primary keys com o nome deste genero: intersecoes_3d_rg_4_3_2_pkey
-- quando se cria a tabela com um LIKE INCLUDING ALL os nomes das restrições são gerados automaticamente
ALTER TABLE validation.intersecoes_3d DROP CONSTRAINT IF EXISTS ponto_unico;
ALTER TABLE validation.intersecoes_3d ADD CONSTRAINT ponto_unico PRIMARY KEY (geometria);

CREATE TABLE IF NOT EXISTS validation.descontinuidades (
	p1_id uuid NULL,
	p2_id uuid NULL,
	dist_p1_p2 double precision,
	geometria geometry(pointz, 3763) NULL
);


CREATE TABLE IF NOT EXISTS validation.intersecoes_2d (
    p1_id uuid NULL,
	p2_id uuid NULL,
	geometria geometry(pointz, 3763) NULL
);

ALTER TABLE validation.intersecoes_2d DROP CONSTRAINT IF EXISTS intersecoes_2d_pk;
ALTER TABLE validation.intersecoes_2d ADD CONSTRAINT intersecoes_2d_pk PRIMARY KEY (p1_id, p2_id);
