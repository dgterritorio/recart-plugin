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
		execute format('insert into %s %s on conflict ON constraint %s_pkey do nothing', tbl, format(_report, _args), tblname || '_' || _code);
	end if;
end; $$;


create or replace function validation.validate_schema_constraints(expected_constraints jsonb)
returns jsonb
language plpgsql
as $function$
declare
	tables_json jsonb;
	rec record;
	expected_nn jsonb;
	col text;
	expected_pk text;
	fk_elem jsonb;
	fk_cols text;
	fk_ref_table text;
	fk_ref_cols text;
	uq_elem jsonb;
	expected_uq_cols text;
	errors jsonb := '[]'::jsonb;
	system_tables text[] := array[
		'geography_columns', 'geometry_columns', 'spatial_ref_sys',
		'raster_columns', 'raster_overviews'
	];
begin
	tables_json := coalesce(expected_constraints -> 'tables', expected_constraints);

	create temp table _vsc_tables on commit drop as
		select tablename as table_name
		from pg_tables
		where schemaname = '{schema}';

	create temp table _vsc_not_null on commit drop as
		select c.relname as table_name, a.attname as column_name
		from pg_class c
		join pg_namespace n on n.oid = c.relnamespace
		join pg_attribute a on a.attrelid = c.oid
		where n.nspname = '{schema}'
			and c.relkind = 'r'
			and a.attnum > 0
			and not a.attisdropped
			and a.attnotnull;

	create temp table _vsc_pk on commit drop as
		select
			src.relname as table_name,
			string_agg(sa.attname, ',' order by src_u.ord) as pk_cols
		from pg_constraint con
		join pg_class src on src.oid = con.conrelid
		join pg_namespace n on n.oid = src.relnamespace
		join lateral unnest(con.conkey) with ordinality as src_u(attnum, ord) on true
		join pg_attribute sa on sa.attrelid = src.oid and sa.attnum = src_u.attnum
		where n.nspname = '{schema}'
			and con.contype = 'p'
		group by src.relname, con.conname;

	create temp table _vsc_unique on commit drop as
		select
			src.relname as table_name,
			string_agg(sa.attname, ',' order by src_u.ord) as uq_cols
		from pg_constraint con
		join pg_class src on src.oid = con.conrelid
		join pg_namespace n on n.oid = src.relnamespace
		join lateral unnest(con.conkey) with ordinality as src_u(attnum, ord) on true
		join pg_attribute sa on sa.attrelid = src.oid and sa.attnum = src_u.attnum
		where n.nspname = '{schema}'
			and con.contype = 'u'
		group by src.relname, con.conname;

	create temp table _vsc_fk on commit drop as
		select
			src.relname as table_name,
			string_agg(sa.attname, ',' order by src_u.ord) as src_cols,
			tgt.relname as ref_table,
			string_agg(ta.attname, ',' order by tgt_u.ord) as ref_cols
		from pg_constraint con
		join pg_class src on src.oid = con.conrelid
		join pg_class tgt on tgt.oid = con.confrelid
		join pg_namespace n on n.oid = src.relnamespace
		join lateral unnest(con.conkey) with ordinality as src_u(attnum, ord) on true
		join pg_attribute sa on sa.attrelid = src.oid and sa.attnum = src_u.attnum
		join lateral unnest(con.confkey) with ordinality as tgt_u(attnum, ord)
			on tgt_u.ord = src_u.ord
		join pg_attribute ta on ta.attrelid = tgt.oid and ta.attnum = tgt_u.attnum
		where n.nspname = '{schema}'
			and con.contype = 'f'
		group by src.relname, con.conname, tgt.relname;

	for rec in
		select key as table_name, value as table_spec
		from jsonb_each(tables_json)
		order by key
	loop
		if rec.table_name = any(system_tables) then
			continue;
		end if;

		if not exists (select 1 from _vsc_tables t where t.table_name = rec.table_name) then
			errors := errors || jsonb_build_array(jsonb_build_object(
				'tabela', rec.table_name,
				'tipo', 'tabela',
				'detalhe', rec.table_name,
				'estado', 'em falta'
			));
			continue;
		end if;

		expected_nn := coalesce(rec.table_spec -> 'not_null', '[]'::jsonb);
		for col in
			select jsonb_array_elements_text(expected_nn)
		loop
			if not exists (
				select 1
				from _vsc_not_null nn
				where nn.table_name = rec.table_name
					and nn.column_name = col
			) then
				errors := errors || jsonb_build_array(jsonb_build_object(
					'tabela', rec.table_name,
					'tipo', 'not_null',
					'detalhe', col,
					'estado', 'em falta'
				));
			end if;
		end loop;

		expected_pk := (
			select string_agg(elem, ',' order by ord)
			from (
				select elem, ord
				from jsonb_array_elements_text(coalesce(rec.table_spec -> 'primary_key', '[]'::jsonb))
					with ordinality as t(elem, ord)
			) s
		);
		if expected_pk is not null and expected_pk <> '' then
			if not exists (
				select 1
				from _vsc_pk pk
				where pk.table_name = rec.table_name
					and pk.pk_cols = expected_pk
			) then
				errors := errors || jsonb_build_array(jsonb_build_object(
					'tabela', rec.table_name,
					'tipo', 'primary_key',
					'detalhe', expected_pk,
					'estado', 'em falta'
				));
			end if;
		end if;

		for fk_elem in
			select value
			from jsonb_array_elements(coalesce(rec.table_spec -> 'foreign_keys', '[]'::jsonb))
		loop
			fk_cols := (
				select string_agg(elem, ',' order by ord)
				from (
					select elem, ord
					from jsonb_array_elements_text(fk_elem -> 'columns')
						with ordinality as t(elem, ord)
				) s
			);
			fk_ref_table := fk_elem -> 'references' ->> 'table';
			fk_ref_cols := (
				select string_agg(elem, ',' order by ord)
				from (
					select elem, ord
					from jsonb_array_elements_text(fk_elem -> 'references' -> 'columns')
						with ordinality as t(elem, ord)
				) s
			);
			if not exists (
				select 1
				from _vsc_fk fk
				where fk.table_name = rec.table_name
					and fk.src_cols = fk_cols
					and fk.ref_table = fk_ref_table
					and fk.ref_cols = fk_ref_cols
			) then
				errors := errors || jsonb_build_array(jsonb_build_object(
					'tabela', rec.table_name,
					'tipo', 'foreign_key',
					'detalhe', fk_cols || ' -> ' || fk_ref_table || '(' || fk_ref_cols || ')',
					'estado', 'em falta'
				));
			end if;
		end loop;

		for uq_elem in
			select value
			from jsonb_array_elements(coalesce(rec.table_spec -> 'unique', '[]'::jsonb))
		loop
			expected_uq_cols := (
				select string_agg(elem, ',' order by ord)
				from (
					select elem, ord
					from jsonb_array_elements_text(uq_elem -> 'columns')
						with ordinality as t(elem, ord)
				) s
			);
			if not exists (
				select 1
				from _vsc_unique uq
				where uq.table_name = rec.table_name
					and uq.uq_cols = expected_uq_cols
			) then
				errors := errors || jsonb_build_array(jsonb_build_object(
					'tabela', rec.table_name,
					'tipo', 'unique',
					'detalhe', expected_uq_cols,
					'estado', 'em falta'
				));
			end if;
		end loop;
	end loop;

	return errors;
end;
$function$;


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
	ini bool;
begin
	res = true;
	ini = true;
	select coalesce(regexp_split_to_array(nome, '[\sºª]+'), '{}') into parts;

	foreach word in array parts
	loop
		select word into aux;
		if upper(word) <> word then
			select upper(left(word, 1)) || right(word, -1) into aux;
			if ini is not true then
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
			end if;
			select REGEXP_REPLACE(aux, 'Eb([123])$', 'EB\1', 'g') into aux;
			select REGEXP_REPLACE(aux, 'Ji$', 'JI', 'g') into aux;
			select REGEXP_REPLACE(aux, 'Sa$', 'SA', 'g') into aux;
		
			if word <> aux then
				raise notice '% - %', word, aux;
				res = false;
				exit;
			end if;
		end if;
		ini = false;
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

	select count(*) from {schema}.ponto_cotado pc, {schema}.area_trabalho adt where St_Contains(adt.geometria, pc.geometria) into count_all;

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
	    FROM {schema}.ponto_cotado pc, {schema}.area_trabalho adt
	    WHERE St_Contains(adt.geometria, pc.geometria) and pc.identificador IN (
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

	select count(*) from {schema}.ponto_cotado pc, {schema}.area_trabalho adt where St_Contains(adt.geometria, pc.geometria) into count_all;

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
	    FROM {schema}.ponto_cotado pc, {schema}.area_trabalho adt
	    WHERE St_Contains(adt.geometria, pc.geometria) and pc.identificador IN (
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

create or replace function validation.re3_1_1_validation (ndd integer, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
	count_bad_points integer := 0;
begin
	delete from errors.erros_3d where rule_code = 're3_1_1'
		or (rule_code is null and entidade = 'curva_de_nivel' and motivo = 'Ponto fora da linha da área de trabalho');

	with 
		total as (select count(*) from {schema}.curva_de_nivel),
		good as (select count(cdn.identificador)
			from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
			where ST_IsClosed(cdn.geometria) or (not ST_IsClosed(cdn.geometria)
				and ( ST_Covers(ST_Boundary(adt.geometria), ST_StartPoint(cdn.geometria)) and
					ST_Covers(ST_Boundary(adt.geometria), ST_EndPoint(cdn.geometria)) ) ) 
		),
		bad as (select count(cdn.identificador) 
			from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
			where not ST_IsClosed(cdn.geometria)
				and (not ST_Covers(ST_Boundary(adt.geometria), ST_StartPoint(cdn.geometria)) or
					not ST_Covers(ST_Boundary(adt.geometria), ST_EndPoint(cdn.geometria)) )
		)
	select total.count as total, good.count as good, bad.count as bad 
	from total, good, bad 
	into count_all, count_good, count_bad;

	WITH bad_points AS (
		insert into errors.erros_3d (identificador, entidade, indice, motivo, rule_code, geometria)
		select cdn.identificador, 'curva_de_nivel', 0, 'Ponto fora da linha da área de trabalho', 're3_1_1', ST_StartPoint(cdn.geometria) as geometria
		from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
		where not ST_IsClosed(cdn.geometria) and not ST_Covers(ST_Boundary(adt.geometria), ST_StartPoint(cdn.geometria))
		union
		select cdn.identificador, 'curva_de_nivel', -1, 'Ponto fora da linha da área de trabalho', 're3_1_1', ST_EndPoint(cdn.geometria) as geometria
		from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
		where not ST_IsClosed(cdn.geometria) and not ST_Covers(ST_Boundary(adt.geometria), ST_EndPoint(cdn.geometria))
		ON CONFLICT (identificador, entidade, motivo, geometria) DO UPDATE SET
			rule_code = COALESCE(errors.erros_3d.rule_code, EXCLUDED.rule_code),
			indice = EXCLUDED.indice
		RETURNING 1
	)
	SELECT count(*) FROM bad_points into count_bad_points;
	raise notice 'Existem % pontos errados', count_bad_points;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.re3_1_1_validation (ndd integer, sect geometry, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
	count_bad_points integer := 0;
begin
	with 
		total as (select count(*) from {schema}.curva_de_nivel),
		good as (select count(cdn.identificador)
			from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
			where ST_IsClosed(cdn.geometria) or (not ST_IsClosed(cdn.geometria)
				and ( ST_Covers(ST_Boundary(adt.geometria), ST_StartPoint(cdn.geometria)) and
					ST_Covers(ST_Boundary(adt.geometria), ST_EndPoint(cdn.geometria)) ) ) and ST_Intersects(cdn.geometria, sect)
		),
		bad as (select count(cdn.identificador) 
			from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
			where not ST_IsClosed(cdn.geometria)
				and (not ST_Covers(ST_Boundary(adt.geometria), ST_StartPoint(cdn.geometria)) or
					not ST_Covers(ST_Boundary(adt.geometria), ST_EndPoint(cdn.geometria)) ) and ST_Intersects(cdn.geometria, sect)
		)
	select total.count as total, good.count as good, bad.count as bad 
	from total, good, bad 
	into count_all, count_good, count_bad;

	WITH bad_points AS (
		insert into errors.erros_3d (identificador, entidade, indice, motivo, rule_code, geometria)
		select cdn.identificador, 'curva_de_nivel', 0, 'Ponto fora da linha da área de trabalho', 're3_1_1', ST_StartPoint(cdn.geometria) as geometria
		from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
		where not ST_IsClosed(cdn.geometria) and not ST_Covers(ST_Boundary(adt.geometria), ST_StartPoint(cdn.geometria)) and ST_Intersects(cdn.geometria, sect)
		union
		select cdn.identificador, 'curva_de_nivel', -1, 'Ponto fora da linha da área de trabalho', 're3_1_1', ST_EndPoint(cdn.geometria) as geometria
		from {schema}.curva_de_nivel cdn, validation.area_trabalho_multi adt
		where not ST_IsClosed(cdn.geometria) and not ST_Covers(ST_Boundary(adt.geometria), ST_EndPoint(cdn.geometria)) and ST_Intersects(cdn.geometria, sect)
		ON CONFLICT (identificador, entidade, motivo, geometria) DO UPDATE SET
			rule_code = COALESCE(errors.erros_3d.rule_code, EXCLUDED.rule_code),
			indice = EXCLUDED.indice
		RETURNING 1
	)
	SELECT count(*) FROM bad_points into count_bad_points;
	raise notice 'Existem % pontos errados', count_bad_points;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.re3_1_2_validation (ndd integer, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
	count_bad_points integer := 0;
begin
	delete from errors.erros_3d where rule_code = 're3_1_2'
		or (rule_code is null and entidade = 'curva_de_nivel' and motivo like 'discrepância no valor de z:%');

	with 
		total as (select count(*) from {schema}.curva_de_nivel),
		bad as (select count(*) from {schema}.curva_de_nivel where ST_ZMax(geometria) != ST_ZMin(geometria))
	select total.count, total.count - bad.count as good, bad.count from total, bad
	into count_all, count_good, count_bad;

	with 
	bad as (select * from {schema}.curva_de_nivel where ST_ZMax(geometria) != ST_ZMin(geometria)),
	pontos as (select
		identificador, ST_ZMax(geometria) as max, ST_ZMin(geometria) as min,
		ST_DumpPoints(geometria) as dp
		FROM bad as pc),
	media as (select identificador, percentile_disc(0.5) WITHIN GROUP (
		ORDER BY st_z((dp).geom)) as mediana
		FROM pontos 
		GROUP by identificador),
	bad_points AS (
		insert into errors.erros_3d (identificador, entidade, indice, motivo, rule_code, geometria)	
		select pontos.identificador, 'curva_de_nivel', (dp).path[1] as indice, 'discrepância no valor de z: ' || st_z((dp).geom) || ' em vez de ' || media.mediana, 're3_1_2', (dp).geom as geometria from pontos, media
		where pontos.identificador = media.identificador and st_z((dp).geom) != media.mediana
		ON CONFLICT (identificador, entidade, motivo, geometria) DO UPDATE SET
			rule_code = COALESCE(errors.erros_3d.rule_code, EXCLUDED.rule_code),
			indice = EXCLUDED.indice
		RETURNING 1
	)

	SELECT count(*) FROM bad_points into count_bad_points;
	raise notice 'Existem % pontos errados', count_bad_points;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.re3_1_2_validation (ndd integer, sect geometry, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
	count_bad_points integer := 0;
begin
	with 
		total as (select count(*) from {schema}.curva_de_nivel cdn where ST_Intersects(cdn.geometria, sect)),
		bad as (select count(*) from {schema}.curva_de_nivel cdn where ST_Intersects(cdn.geometria, sect) and ST_ZMax(geometria) != ST_ZMin(geometria))
	select total.count, total.count - bad.count as good, bad.count from total, bad
	into count_all, count_good, count_bad;

	with 
	bad as (select * from {schema}.curva_de_nivel cdn where ST_Intersects(cdn.geometria, sect) and ST_ZMax(geometria) != ST_ZMin(geometria)),
	pontos as (select
		identificador, ST_ZMax(geometria) as max, ST_ZMin(geometria) as min,
		ST_DumpPoints(geometria) as dp
		FROM bad as pc),
	media as (select identificador, percentile_disc(0.5) WITHIN GROUP (
		ORDER BY st_z((dp).geom)) as mediana
		FROM pontos 
		GROUP by identificador),
	bad_points AS (
		insert into errors.erros_3d (identificador, entidade, indice, motivo, rule_code, geometria)	
		select pontos.identificador, 'curva_de_nivel', (dp).path[1] as indice, 'discrepância no valor de z: ' || st_z((dp).geom) || ' em vez de ' || media.mediana, 're3_1_2', (dp).geom as geometria from pontos, media
		where pontos.identificador = media.identificador and st_z((dp).geom) != media.mediana
		ON CONFLICT (identificador, entidade, motivo, geometria) DO UPDATE SET
			rule_code = COALESCE(errors.erros_3d.rule_code, EXCLUDED.rule_code),
			indice = EXCLUDED.indice
		RETURNING 1
	)
	SELECT count(*) FROM bad_points into count_bad_points;
	raise notice 'Existem % pontos errados', count_bad_points;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.re4_5_2_insert (_id uuid, _arr  float[], _geo geometry) returns int as $$
declare
	var int;
	count_all integer := 0;
begin
	if _arr[1] > _arr[array_upper(_arr, 1)] then
		-- a altimetria está diminuir
		for var in 1..array_upper(_arr, 1)-1 loop
			if _arr[var] < _arr[var+1] then
				count_all := count_all + 1;
				insert into errors.erros_3d (identificador, entidade, indice, motivo, rule_code, geometria)
				values (_id, 'curso_de_agua_eixo', var, 'ponto de inflexão', 're4_5_2', ST_PointN(_geo, var))
				ON CONFLICT (identificador, entidade, motivo, geometria) DO UPDATE SET
			rule_code = COALESCE(errors.erros_3d.rule_code, EXCLUDED.rule_code),
			indice = EXCLUDED.indice;
			end if;
		end loop;
	else
		-- a altimetria está aumentar
		for var in 1..array_upper(_arr, 1)-1 loop
			if _arr[var] > _arr[var+1] then
				count_all := count_all + 1;
				insert into errors.erros_3d (identificador, entidade, indice, motivo, rule_code, geometria)
				values (_id, 'curso_de_agua_eixo', var, 'ponto de inflexão', 're4_5_2', ST_PointN(_geo, var))
				ON CONFLICT (identificador, entidade, motivo, geometria) DO UPDATE SET
			rule_code = COALESCE(errors.erros_3d.rule_code, EXCLUDED.rule_code),
			indice = EXCLUDED.indice;
			end if;
		end loop;
	end if;
	return count_all;
end;
$$ language plpgsql;

create or replace function validation.re4_5_2_validation (ndd integer, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
	count_bad_points integer := 0;
begin
	delete from errors.erros_3d where rule_code = 're4_5_2'
		or (rule_code is null and entidade = 'curso_de_agua_eixo' and motivo = 'ponto de inflexão');

	with 
		aux as (select identificador, geometria, (ST_DumpPoints(geometria)).* from {schema}.curso_de_agua_eixo group by identificador, geometria),
		pontos as (select identificador, geometria, array_agg(ST_Z(geom)) as pontos_arr from aux group by identificador, geometria),
		teste as (select identificador, geometria, pontos_arr, (pontos_arr = validation.sort_desc(pontos_arr) or pontos_arr = validation.sort_asc(pontos_arr)) as comparacao from pontos),
		total as (select count(*) from {schema}.curso_de_agua_eixo),
		good as (select count(*) from teste where comparacao),
		bad as (
			select count( validation.re4_5_2_insert (identificador, pontos_arr, geometria) )
			from teste where not comparacao)
	select total.count as total, total.count - bad.count as good, bad.count as bad from total, bad
	into count_all, count_good, count_bad;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.re4_5_2_validation (ndd integer, sect geometry, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
	count_bad_points integer := 0;
begin
	with 
		aux as (select identificador, geometria, (ST_DumpPoints(geometria)).* from {schema}.curso_de_agua_eixo 
			where ST_Intersects(geometria, sect)
			group by identificador, geometria),
		pontos as (select identificador, geometria, array_agg(ST_Z(geom)) as pontos_arr from aux group by identificador, geometria),
		teste as (select identificador, geometria, pontos_arr, (pontos_arr = validation.sort_desc(pontos_arr) or pontos_arr = validation.sort_asc(pontos_arr)) as comparacao from pontos),
		total as (select count(*) from {schema}.curso_de_agua_eixo),
		good as (select count(*) from teste where comparacao),
		bad as (
			select count( validation.re4_5_2_insert (identificador, pontos_arr, geometria) )
			from teste where not comparacao)
	select total.count as total, total.count - bad.count as good, bad.count as bad from total, bad
	into count_all, count_good, count_bad;

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
	
		execute format('select count(t.*) from {schema}.%I t, validation.area_trabalho_multi adt
			where St_Contains(adt.geometria, t.geometria)', tabela) INTO good_aux;
		RAISE NOTICE 'Good is % for table %', good_aux, tabela;
		count_good := count_good + good_aux;
	
		execute format('select count(t.*) from {schema}.%I t, validation.area_trabalho_multi adt
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
			execute format('insert into %1$s select t.* from {schema}.%2$I t, validation.area_trabalho_multi adt
				where not St_Contains(adt.geometria, t.geometria) on conflict ON constraint %3$s_pkey do nothing', tabela_erro, tabela, tabela || '_rg_5');
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
	
		execute format('select count(t.*) from {schema}.%I t, validation.area_trabalho_multi adt
			where ST_Intersects(t.geometria, %L) and St_Contains(adt.geometria, t.geometria)', tabela, sect) INTO good_aux;
		RAISE NOTICE 'Good is % for table %', good_aux, tabela;
		count_good := count_good + good_aux;
	
		execute format('select count(t.*) from {schema}.%I t, validation.area_trabalho_multi adt
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
			execute format('insert into %1$s select t.* from {schema}.%2$I t, validation.area_trabalho_multi adt
				where ST_Intersects(t.geometria, %3$L) and not St_Contains(adt.geometria, t.geometria) on conflict ON constraint %4$s_pkey do nothing', tabela_erro, tabela, sect, tabela || '_rg_5');
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
	
		execute format('select count(t.*) from {schema}.%I t, validation.area_trabalho_multi adt
			where St_Contains(adt.geometria, t.geometria)', tabela) INTO good_aux;
		RAISE NOTICE 'Good is % for table %', good_aux, tabela;
		count_good := count_good + good_aux;
	
		execute format('select count(t.*) from {schema}.%I t, validation.area_trabalho_multi adt
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
			execute format('insert into %1$s select t.* from {schema}.%2$I t, validation.area_trabalho_multi adt
				where not St_Contains(adt.geometria, t.geometria) on conflict ON constraint %3$s_pkey do nothing', tabela_erro, tabela, tabela || '_rg_5');
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
	
		execute format('select count(t.*) from {schema}.%I t, validation.area_trabalho_multi adt
			where ST_Intersects(t.geometria, %L) and St_Contains(adt.geometria, t.geometria)', tabela, sect) INTO good_aux;
		RAISE NOTICE 'Good is % for table %', good_aux, tabela;
		count_good := count_good + good_aux;
	
		execute format('select count(t.*) from {schema}.%I t, validation.area_trabalho_multi adt
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
			execute format('insert into %1$s select t.* from {schema}.%2$I t, validation.area_trabalho_multi adt
				where ST_Intersects(t.geometria, %3$L) and not St_Contains(adt.geometria, t.geometria) on conflict ON constraint %4$s_pkey do nothing', tabela_erro, tabela, sect, tabela || '_rg_5');
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
	
		execute format('select count(*) from {schema}.%I where nome is not null and validation.validcap_pt(nome)=true', tabela ) INTO good_aux;
		RAISE NOTICE 'Good is % for table %', good_aux, tabela;
		count_good := count_good + good_aux;
	
		execute format('select count(*) from {schema}.%I where nome is not null and validation.validcap_pt(nome)<>true', tabela ) INTO bad_aux;
		RAISE NOTICE 'Bad is % for table %', bad_aux, tabela;
		count_bad := count_bad + bad_aux;

		if bad_aux > 0 then
			CREATE SCHEMA IF NOT EXISTS errors;
			-- table without indexes
			tabela_erro := 'errors.' || tabela || '_rg_6';
			-- raise notice '%', tbl;
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
			execute format('delete from %s', tabela_erro);
			execute format('insert into %s select * from {schema}.%I where nome is not null and validation.validcap_pt(nome)<>true', tabela_erro, tabela);
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
	
		execute format('select count(*) from {schema}.%1$I where %2$s is not null and validation.valid_noabbr(%2$s)=true', tabela, coluna) INTO good_aux;
		RAISE NOTICE 'Good is % for table %', good_aux, tabela;
		count_good := count_good + good_aux;
	
		execute format('select count(*) from {schema}.%1$I where %2$s is not null and validation.valid_noabbr(%2$s)<>true', tabela, coluna) INTO bad_aux;
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


create or replace function validation.descontinuidades_quadrantes (entidade text) returns table (p1_id uuid, p2_id uuid, dist_p1_p2 double precision, p1_endpoint_geom geometry) as $$
begin
	return query execute format('WITH p AS (
		SELECT  {schema}.%1$I.identificador AS id, {schema}.st_startpoint(%1$I.geometria) AS geom
			FROM {schema}.%1$I
		UNION
		SELECT  {schema}.%1$I.identificador, {schema}.st_endpoint(%1$I.geometria) AS geom
			FROM {schema}.%1$I
	), q AS (
		SELECT  p.id, p.geom, trunc(ST_X(p.geom)/100)::text || '','' || trunc(ST_Y(p.geom)/100)::text AS quad
			FROM p
	)
	SELECT p1.id AS p1_id, p2.id AS p2_id, st_3ddistance(p1.geom, p2.geom) AS dist_p1_p2,
	 st_setsrid((p1.geom)::geometry(PointZ), 3763) AS p1_endpoint_geom
		FROM (q p1
			JOIN q p2 ON p1.quad = p2.quad
			 AND (((st_3ddistance(p1.geom, p2.geom) <> (0)::double precision) AND (st_3ddistance(p1.geom, p2.geom) < (0.2)::double precision)))
		);', entidade);
end;
$$ language plpgsql;

create or replace function validation.descontinuidades_quadrantes (entidade text, sect geometry) returns table (p1_id uuid, p2_id uuid, dist_p1_p2 double precision, p1_endpoint_geom geometry) as $$
begin
	return query execute format('WITH p AS (
		SELECT  {schema}.%1$I.identificador AS id, {schema}.st_startpoint(%1$I.geometria) AS geom
			FROM {schema}.%1$I
			where ST_Intersects(%1$I.geometria, %L)
		UNION
		SELECT  {schema}.%1$I.identificador, {schema}.st_endpoint(%1$I.geometria) AS geom
			FROM {schema}.%1$I
			where ST_Intersects(%1$I.geometria, %L)
	), q AS (
		SELECT  p.id, p.geom, trunc(ST_X(p.geom)/100)::text || '','' || trunc(ST_Y(p.geom)/100)::text AS quad
			FROM p
	)
	SELECT p1.id AS p1_id, p2.id AS p2_id, st_3ddistance(p1.geom, p2.geom) AS dist_p1_p2,
	 st_setsrid((p1.geom)::geometry(PointZ), 3763) AS p1_endpoint_geom
		FROM (q p1
			JOIN q p2 ON p1.quad = p2.quad
			 AND (((st_3ddistance(p1.geom, p2.geom) <> (0)::double precision) AND (st_3ddistance(p1.geom, p2.geom) < (0.2)::double precision)))
		);', entidade, sect);
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
			execute format('ALTER TABLE %s ADD COLUMN IF NOT EXISTS motivo TEXT NULL', tabela_erro);

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
			execute format('ALTER TABLE %s ADD COLUMN IF NOT EXISTS motivo TEXT NULL', tabela_erro);

			execute format('insert into %s select t.*, st_isvalidreason(geometria) from {schema}.%I t where not st_isvalid(geometria) and ST_Intersects(geometria, %L) ON CONFLICT (identificador) DO NOTHING', tabela_erro, tabela, sect);
		end if;
	end loop;

	select (count_all - count_bad) into count_good;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;


create or replace function validation.pq1_1_validation () returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;

	all_aux integer := 0;
	bad_aux integer := 0;

	tabelas_2d text[];
	tabelas_3d text[];

	tabela text;
	tabela_erro text;
begin
	tabelas_2d = array['area_agricola_florestal_mato', 'area_infra_trans_aereo', 'area_infra_trans_ferrov',
	 'area_infra_trans_rodov', 'area_infra_trans_via_navegavel', 'area_trabalho', 'areas_artificializadas',
	 'barreira', 'cabo_electrico', 'conduta_de_agua', 'constru_linear', 'constru_polig', 'designacao_local',
	 'edificio', 'elem_assoc_agua', 'elem_assoc_eletricidade', 'elem_assoc_pgq', 'elem_assoc_telecomunicacoes',
	 'fronteira', 'infra_trans_aereo', 'infra_trans_ferrov', 'infra_trans_rodov', 'infra_trans_via_navegavel',
	 'margem', 'mob_urbano_sinal', 'oleoduto_gasoduto_subtancias_quimicas', 'ponto_interesse', 'seg_via_cabo',
	 'sinal_geodesico'];

	tabelas_3d = array['agua_lentica', 'curso_de_agua_area', 'curso_de_agua_eixo', 'no_hidrografico',
	 'curva_de_nivel', 'fronteira_terra_agua', 'linha_de_quebra', 'nascente', 'no_trans_ferrov', 'obra_arte',
	 'ponto_cotado', 'queda_de_agua', 'seg_via_ferrea', 'seg_via_rodov', 'via_rodov_limite', 'zona_humida'];

	CREATE SCHEMA IF NOT EXISTS errors;
	tabela := 'comissao';
	tabela_erro := 'errors.' || tabela || '_pq1_1';
	execute format('CREATE TABLE IF NOT exists %s (like validation.%I INCLUDING ALL)', tabela_erro, tabela);

	for tabela in select unnest(tabelas_2d)
	loop
		execute format('select count(*) from {schema}.%I', tabela) into all_aux;
		execute format('SELECT COUNT(*) FROM (SELECT ST_AsText(geometria) AS geom, array_agg(identificador) AS ids, ''%1$s'' as ft
			FROM %1$I GROUP BY geometria HAVING COUNT(*) > 1) as foo', tabela) into bad_aux;

		execute format('INSERT INTO %4$s (entidade, entidade_total, entidade_duplicados, geom, ids, geometria)
		SELECT ''%1$s'', %2$s, %3$s, ST_AsText(geometria) AS geom, array_agg(identificador) AS ids, ST_Force3D(geometria)
			FROM %1$I GROUP BY geometria HAVING COUNT(*) > 1', tabela, all_aux, bad_aux, tabela_erro);

		count_all := count_all + all_aux;
		count_bad := count_bad + bad_aux;
	end loop;

	for tabela in select unnest(tabelas_3d)
	loop
		execute format('select count(*) from {schema}.%I', tabela) into all_aux;
		execute format('SELECT COUNT(*) FROM (SELECT ST_AsText(geometria) AS geom, array_agg(identificador) AS ids, ''%1$s'' as ft
			FROM {schema}.%1$I GROUP BY geometria HAVING COUNT(*) > 1) as foo', tabela) into bad_aux;

		execute format('INSERT INTO %4$s (entidade, entidade_total, entidade_duplicados, geom, ids, geometria)
		SELECT ''%1$s'', %2$s, %3$s, ST_AsText(geometria) AS geom, array_agg(identificador) AS ids, geometria
			FROM {schema}.%1$I GROUP BY geometria HAVING COUNT(*) > 1', tabela, all_aux, bad_aux, tabela_erro);

		count_all := count_all + all_aux;
		count_bad := count_bad + bad_aux;
	end loop;

	tabela := 'no_trans_rodov';
	execute format('select count(*) from {schema}.%I', tabela) into all_aux;
	execute format('SELECT COUNT(*) FROM (select geom, ids, ft from
		(SELECT ST_AsText(geometria) AS geom,
			array_agg(identificador) AS ids,
       		array_agg(valor_tipo_no_trans_rodov) AS valor,
       		''no_trans_rodov'' as ft
		FROM no_trans_rodov
		GROUP BY geom HAVING COUNT(*) > 1) sub
			where not((array_position(valor, ''4'') = 1 and array_position(valor, ''5'') = 2) or 
				(array_position(valor, ''5'') = 1 and array_position(valor, ''4'') = 2))) as foo') into bad_aux;

	execute format('INSERT INTO %4$s (entidade, entidade_total, entidade_duplicados, geom, ids, geometria)
	SELECT ''%1$s'', %2$s, %3$s, geom, ids, geometria
		FROM (SELECT ST_AsText(geometria) AS geom,
       			array_agg(identificador) AS ids,
       			array_agg(valor_tipo_no_trans_rodov) AS valor,
       			''no_trans_rodov'' as ft,
				geometria
			FROM no_trans_rodov
			GROUP BY geom, geometria
			HAVING COUNT(*) > 1) sub
				where not((array_position(valor, ''4'') = 1 and array_position(valor, ''5'') = 2) or 
					(array_position(valor, ''5'') = 1 and array_position(valor, ''4'') = 2))', tabela, all_aux, bad_aux, tabela_erro);

	count_all := count_all + all_aux;
	count_bad := count_bad + bad_aux;

	select (count_all - count_bad) into count_good;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.pq1_1_validation_v2 () returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;

	all_aux integer := 0;
	bad_aux integer := 0;

	tabelas_2d text[];
	tabelas_3d text[];

	tabela text;
	tabela_erro text;
begin
	tabelas_2d = array['area_agricola_florestal_mato', 'area_infra_trans_aereo', 'area_infra_trans_ferrov',
	 'area_infra_trans_rodov', 'area_infra_trans_via_navegavel', 'area_trabalho', 'areas_artificializadas',
	 'barreira', 'cabo_electrico', 'conduta_de_agua', 'constru_linear', 'constru_polig', 'designacao_local',
	 'edificio', 'elem_assoc_agua', 'elem_assoc_eletricidade', 'elem_assoc_pgq', 'elem_assoc_telecomunicacoes',
	 'fronteira', 'infra_trans_aereo', 'infra_trans_ferrov', 'infra_trans_rodov', 'infra_trans_via_navegavel',
	 'terreno_marginal', 'mob_urbano_sinal', 'oleoduto_gasoduto_subtancias_quimicas', 'ponto_interesse', 'seg_via_cabo',
	 'constru_na_margem', 'numero_policia', 'sinal_geodesico'];

	tabelas_3d = array['agua_lentica', 'curso_de_agua_area', 'curso_de_agua_eixo', 'no_hidrografico',
	 'curva_de_nivel', 'fronteira_terra_agua', 'linha_de_quebra', 'nascente', 'no_trans_ferrov', 'obra_arte',
	 'ponto_cotado', 'queda_de_agua', 'seg_via_ferrea', 'seg_via_rodov', 'via_rodov_limite', 'zona_humida'];

	CREATE SCHEMA IF NOT EXISTS errors;
	tabela := 'comissao';
	tabela_erro := 'errors.' || tabela || '_pq1_1';
	execute format('CREATE TABLE IF NOT exists %s (like validation.%I INCLUDING ALL)', tabela_erro, tabela);

	for tabela in select unnest(tabelas_2d)
	loop
		execute format('select count(*) from {schema}.%I', tabela) into all_aux;
		execute format('SELECT COUNT(*) FROM (SELECT ST_AsText(geometria) AS geom, array_agg(identificador) AS ids, ''%1$s'' as ft
			FROM %1$I GROUP BY geometria HAVING COUNT(*) > 1) as foo', tabela) into bad_aux;

		execute format('INSERT INTO %4$s (entidade, entidade_total, entidade_duplicados, geom, ids, geometria)
		SELECT ''%1$s'', %2$s, %3$s, ST_AsText(geometria) AS geom, array_agg(identificador) AS ids, ST_Force3D(geometria)
			FROM %1$I GROUP BY geometria HAVING COUNT(*) > 1', tabela, all_aux, bad_aux, tabela_erro);

		count_all := count_all + all_aux;
		count_bad := count_bad + bad_aux;
	end loop;

	for tabela in select unnest(tabelas_3d)
	loop
		execute format('select count(*) from {schema}.%I', tabela) into all_aux;
		execute format('SELECT COUNT(*) FROM (SELECT ST_AsText(geometria) AS geom, array_agg(identificador) AS ids, ''%1$s'' as ft
			FROM {schema}.%1$I GROUP BY geometria HAVING COUNT(*) > 1) as foo', tabela) into bad_aux;

		execute format('INSERT INTO %4$s (entidade, entidade_total, entidade_duplicados, geom, ids, geometria)
		SELECT ''%1$s'', %2$s, %3$s, ST_AsText(geometria) AS geom, array_agg(identificador) AS ids, geometria
			FROM {schema}.%1$I GROUP BY geometria HAVING COUNT(*) > 1', tabela, all_aux, bad_aux, tabela_erro);

		count_all := count_all + all_aux;
		count_bad := count_bad + bad_aux;
	end loop;

	tabela := 'no_trans_rodov';
	execute format('select count(*) from {schema}.%I', tabela) into all_aux;
	execute format('SELECT COUNT(*) FROM (select geom, ids, ft from
		(SELECT ST_AsText(geometria) AS geom,
			array_agg(identificador) AS ids,
       		array_agg(valor_tipo_no_trans_rodov) AS valor,
       		''no_trans_rodov'' as ft
		FROM no_trans_rodov
		GROUP BY geom HAVING COUNT(*) > 1) sub
			where not((array_position(valor, ''4'') = 1 and array_position(valor, ''5'') = 2) or 
				(array_position(valor, ''5'') = 1 and array_position(valor, ''4'') = 2))) as foo') into bad_aux;

	execute format('INSERT INTO %4$s (entidade, entidade_total, entidade_duplicados, geom, ids, geometria)
	SELECT ''%1$s'', %2$s, %3$s, geom, ids, geometria
		FROM (SELECT ST_AsText(geometria) AS geom,
       			array_agg(identificador) AS ids,
       			array_agg(valor_tipo_no_trans_rodov) AS valor,
       			''no_trans_rodov'' as ft,
				geometria
			FROM no_trans_rodov
			GROUP BY geom, geometria
			HAVING COUNT(*) > 1) sub
				where not((array_position(valor, ''4'') = 1 and array_position(valor, ''5'') = 2) or 
					(array_position(valor, ''5'') = 1 and array_position(valor, ''4'') = 2))', tabela, all_aux, bad_aux, tabela_erro);

	count_all := count_all + all_aux;
	count_bad := count_bad + bad_aux;

	select (count_all - count_bad) into count_good;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;


create or replace function validation.pq2_1_1_validation () returns table (total int, good int, bad int) as $$
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
	-- conformidade seg_via_rodov
	select count(*) from {schema}.seg_via_rodov into count_all;

	CREATE SCHEMA IF NOT EXISTS errors;
	tabela := 'conformidade';
	tabela_erro := 'errors.' || tabela || '_pq2_1_1';
	execute format('CREATE TABLE IF NOT exists %s (like validation.%I INCLUDING ALL)', tabela_erro, tabela);

	execute format('delete from %s', tabela_erro);
	execute format(
		'with bad_rows AS (
			INSERT INTO %s
			select identificador, ''seg_via_rodov'', ''valor_tipo_circulacao'', geometria from {schema}.seg_via_rodov where identificador not in (select seg_via_rodov_id from {schema}.lig_valor_tipo_circulacao_seg_via_rodov)
			RETURNING 1
		)
		SELECT count(*) FROM bad_rows', tabela_erro) into count_bad;

	-- conformidade equip_util_coletiva
	select count(*) from {schema}.equip_util_coletiva into all_aux;
	execute format(
		'with bad_rows AS (
			INSERT INTO %s
			select identificador, ''equip_util_coletiva'', ''valor_tipo_equipamento_coletivo'', NULL from {schema}.equip_util_coletiva where identificador not in (select equip_util_coletiva_id from {schema}.lig_valor_tipo_equipamento_coletivo_equip_util_coletiva)
			RETURNING 1
		)
		SELECT count(*) FROM bad_rows', tabela_erro) into bad_aux;

	count_all := count_all + all_aux;
	count_bad := count_bad + bad_aux;

	select (count_all - count_bad) into count_good;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.pq2_4_1_validation (nd1 boolean) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;

	all_aux integer := 0;
	good_aux integer := 0;
	bad_aux integer := 0;

	rec_aux RECORD;

	tabelas text;
	tabela text;
	tabela_erro text;

	cvalue double precision;

	p1_id uuid;
	p2_id uuid;
	dist_p1_p2 numeric;
	p1_endpoint_geom geometry;
begin
	if nd1=true then
		select 0.2 into cvalue;
	else
		select 1 into cvalue;
	end if;

	CREATE SCHEMA IF NOT EXISTS errors;
	tabela := 'descontinuidades';
	tabela_erro := 'errors.' || tabela || '_pq2_4_1';
	execute format('CREATE TABLE IF NOT exists %s (like validation.%I INCLUDING ALL)', tabela_erro, tabela);

	-- descontinuidades seg_via_rodov
	select count(*) from {schema}.seg_via_rodov into all_aux;

	execute format('delete from %s', tabela_erro);
	execute format(
		'with bad_rows AS (
			INSERT INTO %s
			SELECT * from validation.descontinuidades_quadrantes(''seg_via_rodov'')
			RETURNING 1
		)
		SELECT count(*) FROM bad_rows', tabela_erro) into bad_aux;

	count_all := count_all + all_aux;
	count_bad := count_bad + bad_aux;

	-- descontinuidades via_rodov_limite
	select count(*) from {schema}.via_rodov_limite into all_aux;

	execute format(
		'with bad_rows AS (
			INSERT INTO %s
			SELECT * from validation.descontinuidades_quadrantes(''via_rodov_limite'')
			RETURNING 1
		)
		SELECT count(*) FROM bad_rows', tabela_erro) into bad_aux;

	count_all := count_all + all_aux;
	count_bad := count_bad + bad_aux;

	-- descontinuidades seg_via_ferrea
	select count(*) from {schema}.seg_via_ferrea into all_aux;

	execute format(
		'with bad_rows AS (
			INSERT INTO %s
			SELECT * from validation.descontinuidades_quadrantes(''seg_via_ferrea'')
			RETURNING 1
		)
		SELECT count(*) FROM bad_rows', tabela_erro) into bad_aux;

	count_all := count_all + all_aux;
	count_bad := count_bad + bad_aux;

	-- descontinuidades curva_de_nivel
	select count(*) from {schema}.curva_de_nivel into all_aux;

	execute format(
		'with bad_rows AS (
			INSERT INTO %s
			SELECT * from validation.descontinuidades_quadrantes(''curva_de_nivel'')
			RETURNING 1
		)
		SELECT count(*) FROM bad_rows', tabela_erro) into bad_aux;

	count_all := count_all + all_aux;
	count_bad := count_bad + bad_aux;

		-- descontinuidades curso_de_agua_eixo
	select count(*) from {schema}.curso_de_agua_eixo into all_aux;

	execute format(
		'with bad_rows AS (
			INSERT INTO %s
			SELECT * from validation.descontinuidades_quadrantes(''curso_de_agua_eixo'')
			RETURNING 1
		)
		SELECT count(*) FROM bad_rows', tabela_erro) into bad_aux;

	count_all := count_all + all_aux;
	count_bad := count_bad + bad_aux;

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

	tabelas := 'select f_table_name, f_geometry_column from geometry_columns where f_table_schema = ''{schema}'' and f_geometry_column=''geometria'' and (type = ''LINESTRING'') and LEFT(f_table_name, 1) != ''_''';

	for tabela in execute tabelas
	loop 
		execute format('select count(*) from {schema}.%I', tabela) INTO all_aux;
		count_all := count_all + all_aux;

		execute format('select count(*) from {schema}.%I where st_3dlength(geometria) < %s', tabela, cvalue) INTO bad_aux;
		count_bad := count_bad + bad_aux;

		if bad_aux > 0 then
			tabela_erro := 'errors.' || tabela || '_pq2_4_1';
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
			execute format('ALTER TABLE %s ADD COLUMN IF NOT EXISTS motivo TEXT NULL', tabela_erro);
			execute format('insert into %s select *, ''min length'' from {schema}.%I where st_3dlength(geometria) < %s on conflict (identificador) do nothing', tabela_erro, tabela, cvalue);
		end if;
	end loop;

	select (count_all - count_bad) into count_good;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.pq2_4_1_validation (nd1 boolean, sect geometry) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;

	all_aux integer := 0;
	good_aux integer := 0;
	bad_aux integer := 0;

	rec_aux RECORD;

	tabelas text;
	tabela text;
	tabela_erro text;

	cvalue double precision;

	p1_id uuid;
	p2_id uuid;
	dist_p1_p2 numeric;
	p1_endpoint_geom geometry;
begin
	if nd1=true then
		select 0.2 into cvalue;
	else
		select 1 into cvalue;
	end if;

	CREATE SCHEMA IF NOT EXISTS errors;
	tabela := 'descontinuidades';
	tabela_erro := 'errors.' || tabela || '_pq2_4_1';
	execute format('CREATE TABLE IF NOT exists %s (like validation.%I INCLUDING ALL)', tabela_erro, tabela);

	-- descontinuidades seg_via_rodov
	select count(*) from {schema}.seg_via_rodov into all_aux;

	execute format(
		'with bad_rows AS (
			INSERT INTO %s
			SELECT * from validation.descontinuidades_quadrantes(''seg_via_rodov'', %L)
			RETURNING 1
		)
		SELECT count(*) FROM bad_rows', tabela_erro, sect) into bad_aux;

	count_all := count_all + all_aux;
	count_bad := count_bad + bad_aux;

	-- descontinuidades via_rodov_limite
	select count(*) from {schema}.via_rodov_limite into all_aux;

	execute format(
		'with bad_rows AS (
			INSERT INTO %s
			SELECT * from validation.descontinuidades_quadrantes(''via_rodov_limite'', %L)
			RETURNING 1
		)
		SELECT count(*) FROM bad_rows', tabela_erro, sect) into bad_aux;

	count_all := count_all + all_aux;
	count_bad := count_bad + bad_aux;

	-- descontinuidades seg_via_ferrea
	select count(*) from {schema}.seg_via_ferrea into all_aux;

	execute format(
		'with bad_rows AS (
			INSERT INTO %s
			SELECT * from validation.descontinuidades_quadrantes(''seg_via_ferrea'', %L)
			RETURNING 1
		)
		SELECT count(*) FROM bad_rows', tabela_erro, sect) into bad_aux;

	count_all := count_all + all_aux;
	count_bad := count_bad + bad_aux;

	-- descontinuidades curva_de_nivel
	select count(*) from {schema}.curva_de_nivel into all_aux;

	execute format(
		'with bad_rows AS (
			INSERT INTO %s
			SELECT * from validation.descontinuidades_quadrantes(''curva_de_nivel'', %L)
			RETURNING 1
		)
		SELECT count(*) FROM bad_rows', tabela_erro, sect) into bad_aux;

	count_all := count_all + all_aux;
	count_bad := count_bad + bad_aux;

		-- descontinuidades curso_de_agua_eixo
	select count(*) from {schema}.curso_de_agua_eixo into all_aux;

	execute format(
		'with bad_rows AS (
			INSERT INTO %s
			SELECT * from validation.descontinuidades_quadrantes(''curso_de_agua_eixo'', %L)
			RETURNING 1
		)
		SELECT count(*) FROM bad_rows', tabela_erro, sect) into bad_aux;

	count_all := count_all + all_aux;
	count_bad := count_bad + bad_aux;

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

	tabelas := 'select f_table_name, f_geometry_column from geometry_columns where f_table_schema = ''{schema}'' and f_geometry_column=''geometria'' and (type = ''LINESTRING'') and LEFT(f_table_name, 1) != ''_''';

	for tabela in execute tabelas
	loop 
		execute format('select count(*) from {schema}.%I', tabela) INTO all_aux;
		count_all := count_all + all_aux;

		execute format('select count(*) from {schema}.%I where st_3dlength(geometria) < %s and ST_Intersects(geometria, %L)', tabela, cvalue, sect) INTO bad_aux;
		count_bad := count_bad + bad_aux;

		if bad_aux > 0 then
			tabela_erro := 'errors.' || tabela || '_pq2_4_1';
			execute format('CREATE TABLE IF NOT exists %s (like {schema}.%I INCLUDING ALL)', tabela_erro, tabela);
			execute format('ALTER TABLE %s ADD COLUMN IF NOT EXISTS motivo TEXT NULL', tabela_erro);
			execute format('insert into %s select *, ''min length'' from {schema}.%I where st_3dlength(geometria) < %s and ST_Intersects(geometria, %L) on conflict (identificador) do nothing', tabela_erro, tabela, cvalue, sect);
		end if;
	end loop;

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

create or replace function validation.rg4_3_2_validation (ndd integer, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all int := 0;
	count_good int := 0;
	count_bad int := 0;
	res record;
	desvio_3D numeric;
	tolerancia numeric := 0.15;
begin
	if ndd=1 then
		select coalesce(_args->>'desvio_3D', '0.028')::numeric into desvio_3D;
		tolerancia = 0.018;
	else
		select coalesce(_args->>'desvio_3D', '0.141')::numeric into desvio_3D;
		tolerancia = 0.075;
	end if;

	CREATE SCHEMA IF NOT EXISTS errors;
	CREATE TABLE IF NOT exists errors.intersecoes_3d_rg_4_3_2 (like validation.intersecoes_3d INCLUDING ALL);

	delete from errors.intersecoes_3d_rg_4_3_2;

	CALL validation.create_curva_de_nivel_segmento(tolerancia, 256);

	WITH z_values AS (
		SELECT
			cn.identificador AS id_curva_de_nivel,
			ca.identificador AS id_curso_de_agua,
			ST_StartPoint(pt.geom) AS pt,
			cn.z_curva AS z_curva_de_nivel,
			ST_Z(ST_LineInterpolatePoint(
					ca.geometria,
					ST_LineLocatePoint(ST_Force2D(ca.geometria), ST_StartPoint(pt.geom))
				)) AS z_curso_de_agua
		FROM validation.curva_de_nivel_segmento cn
		JOIN {schema}.curso_de_agua_eixo ca
			ON ST_Intersects(cn.geom2d, ST_Force2D(ca.geometria))
		AND ca.valor_posicao_vertical = '0'	AND ca.delimitacao_conhecida AND NOT ca.ficticio
		CROSS JOIN LATERAL ST_Dump(ST_Intersection(cn.geom2d, ST_Force2D(ca.geometria))) AS pt
		WHERE NOT ST_IsEmpty(pt.geom)
	),
	bad_rows AS (
			INSERT INTO errors.intersecoes_3d_rg_4_3_2 
			select id_curva_de_nivel as id_1, id_curso_de_agua as id_2,
				'curva_de_nivel' as tabela_1, 'curso_de_agua_eixo' as tabela_2, 
				null as geom_1,
				null as geom_2,
				ST_Force3D(pt) AS geometria,
				null as p1_intersecao,
				null as p2_intersecao,
				abs(z_curva_de_nivel - z_curso_de_agua) AS delta_z,
				'rg_4_3_2' as regra
			from z_values where abs(z_curva_de_nivel - z_curso_de_agua) > desvio_3D	limit 100
			on conflict do nothing
			RETURNING 1
		)
	select -1 as total, -1 as good, count(*) as bad 
	from bad_rows into res;

	return query select res.total::int, res.good::int, res.bad::int;
end;
$$ language plpgsql;

create or replace function validation.rg4_3_2_validation (ndd integer, sect geometry, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all int := 0;
	count_good int := 0;
	count_bad int := 0;
	res record;
	desvio_3D numeric;
	tolerancia numeric := 0.15;
begin
	if ndd=1 then
		select coalesce(_args->>'desvio_3D', '0.028')::numeric into desvio_3D;
		tolerancia = 0.018;
	else
		select coalesce(_args->>'desvio_3D', '0.141')::numeric into desvio_3D;
		tolerancia = 0.075;
	end if;

	CREATE SCHEMA IF NOT EXISTS errors;
	CREATE TABLE IF NOT exists errors.intersecoes_3d_rg_4_3_2 (like validation.intersecoes_3d INCLUDING ALL);

	delete from errors.intersecoes_3d_rg_4_3_2;

	CALL validation.create_curva_de_nivel_segmento(tolerancia, 256);

	WITH z_values AS (
		SELECT
			cn.identificador AS id_curva_de_nivel,
			ca.identificador AS id_curso_de_agua,
			ST_StartPoint(pt.geom) AS pt,
			cn.z_curva AS z_curva_de_nivel,
			ST_Z(ST_LineInterpolatePoint(
					ca.geometria,
					ST_LineLocatePoint(ST_Force2D(ca.geometria), ST_StartPoint(pt.geom))
				)) AS z_curso_de_agua
		FROM validation.curva_de_nivel_segmento cn
		JOIN {schema}.curso_de_agua_eixo ca
			ON ST_Intersects(cn.geom2d, ST_Force2D(ca.geometria))
		AND ca.valor_posicao_vertical = '0'	AND ca.delimitacao_conhecida AND NOT ca.ficticio
		CROSS JOIN LATERAL ST_Dump(ST_Intersection(cn.geom2d, ST_Force2D(ca.geometria))) AS pt
		WHERE NOT ST_IsEmpty(pt.geom) 
			and ST_Intersects(ca.geometria, sect)
	),
	bad_rows AS (
			INSERT INTO errors.intersecoes_3d_rg_4_3_2 
			select id_curva_de_nivel as id_1, id_curso_de_agua as id_2,
				'curva_de_nivel' as tabela_1, 'curso_de_agua_eixo' as tabela_2, 
				null as geom_1,
				null as geom_2,
				ST_Force3D(pt) AS geometria,
				null as p1_intersecao,
				null as p2_intersecao,
				abs(z_curva_de_nivel - z_curso_de_agua) AS delta_z,
				'rg_4_3_2' as regra
			from z_values where abs(z_curva_de_nivel - z_curso_de_agua) > desvio_3D	limit 100
			on conflict do nothing
			RETURNING 1
		)
	select -1 as total, -1 as good, count(*) as bad 
	from bad_rows into res;

	return query select res.total::int, res.good::int, res.bad::int;
end;
$$ language plpgsql;

create or replace function validation.re4_8_1_validation (ndd integer, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
begin
	CREATE SCHEMA IF NOT EXISTS errors;
	CREATE TABLE IF NOT exists errors.curso_de_agua_eixo_re_4_8_1 (like {schema}.curso_de_agua_eixo INCLUDING ALL);

	delete from errors.curso_de_agua_eixo_re_4_8_1;

	WITH intersections AS (
		SELECT 
			a.identificador,	
			BOOL_OR(
				a.identificador != b.identificador 
				AND NOT ST_Touches(a.geometria, b.geometria)
			) AS has_bad
		FROM {schema}.curso_de_agua_eixo a
		JOIN {schema}.curso_de_agua_eixo b 
			ON ST_Intersects(a.geometria, b.geometria)
		WHERE a.identificador != b.identificador
		GROUP BY a.identificador
	),
	bad_rows AS (
		INSERT INTO errors.curso_de_agua_eixo_re_4_8_1
			select * from {schema}.curso_de_agua_eixo
				where identificador in (select identificador from intersections WHERE has_bad)
			on conflict do nothing
			RETURNING 1
	)
	SELECT 
		COUNT(*) AS total,
		COUNT(*) FILTER (WHERE NOT has_bad) AS good,
		COUNT(*) FILTER (WHERE has_bad) AS bad
	FROM intersections into count_all, count_good, count_bad;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.re4_8_1_validation (ndd integer, sect geometry, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
begin
	CREATE SCHEMA IF NOT EXISTS errors;
	CREATE TABLE IF NOT exists errors.curso_de_agua_eixo_re_4_8_1 (like {schema}.curso_de_agua_eixo INCLUDING ALL);

	WITH intersections AS (
		SELECT 
			a.identificador,	
			BOOL_OR(
				a.identificador != b.identificador 
				AND NOT ST_Touches(a.geometria, b.geometria)
			) AS has_bad
		FROM {schema}.curso_de_agua_eixo a
		JOIN {schema}.curso_de_agua_eixo b 
			ON ST_Intersects(a.geometria, b.geometria)
		WHERE ST_Intersects(a.geometria, sect) AND a.identificador != b.identificador
		GROUP BY a.identificador
	),
	bad_rows AS (
		INSERT INTO errors.curso_de_agua_eixo_re_4_8_1
			select * from {schema}.curso_de_agua_eixo
				where identificador in (select identificador from intersections WHERE has_bad)
			on conflict do nothing
			RETURNING 1
	)
	SELECT 
		COUNT(*) AS total,
		COUNT(*) FILTER (WHERE NOT has_bad) AS good,
		COUNT(*) FILTER (WHERE has_bad) AS bad
	FROM intersections into count_all, count_good, count_bad;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;


create or replace function validation.re4_11_validation (ndd integer, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
begin
	CREATE SCHEMA IF NOT EXISTS errors;
	CREATE TABLE IF NOT exists errors.no_hidrografico_re_4_11 (like {schema}.no_hidrografico INCLUDING ALL);

	delete from errors.no_hidrografico_re_4_11;

	WITH inter AS (
		SELECT 
			ST_Intersection(l1.geometria, l2.geometria) AS geom
		FROM {schema}.curso_de_agua_eixo l1
		JOIN {schema}.curso_de_agua_eixo l2 
			ON l1.identificador < l2.identificador
			AND ST_Intersects(l1.geometria, l2.geometria)
	),
	intersection_counts AS (
		SELECT geom FROM inter
		GROUP BY geom
		HAVING COUNT(*) > 2
	),
	nos_classified AS (
		SELECT 
			n.identificador,
			CASE 
				WHEN COUNT(*) OVER (PARTITION BY n.geometria) = 1 
					AND n.valor_tipo_no_hidrografico = '3' 
				THEN 'good'
				ELSE 'bad'
			END AS classification
		FROM {schema}.no_hidrografico n
		WHERE EXISTS (
			SELECT 1 FROM intersection_counts ic 
			WHERE ic.geom = n.geometria
		)
	),
	bad_rows AS (
		INSERT INTO errors.no_hidrografico_re_4_11
			select * from {schema}.no_hidrografico
				where identificador in (select identificador from nos_classified WHERE classification = 'bad')
			on conflict do nothing
			RETURNING 1
	)
	SELECT 
		COUNT(*) AS total,
		COUNT(*) FILTER (WHERE classification = 'good') AS good,
		COUNT(*) FILTER (WHERE classification = 'bad') AS bad
	FROM nos_classified into count_all, count_good, count_bad;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.re4_11_validation (ndd integer, sect geometry, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
begin
	CREATE SCHEMA IF NOT EXISTS errors;
	CREATE TABLE IF NOT exists errors.no_hidrografico_re_4_11 (like {schema}.no_hidrografico INCLUDING ALL);

	WITH inter AS (
		SELECT 
			ST_Intersection(l1.geometria, l2.geometria) AS geom
		FROM {schema}.curso_de_agua_eixo l1
		JOIN {schema}.curso_de_agua_eixo l2 
			ON l1.identificador < l2.identificador
			AND ST_Intersects(l1.geometria, l2.geometria)
		WHERE ST_Intersects(l1.geometria, sect)
	),
	intersection_counts AS (
		SELECT geom FROM inter
		GROUP BY geom
		HAVING COUNT(*) > 2
	),
	nos_classified AS (
		SELECT 
			n.identificador,
			CASE 
				WHEN COUNT(*) OVER (PARTITION BY n.geometria) = 1 
					AND n.valor_tipo_no_hidrografico = '3' 
				THEN 'good'
				ELSE 'bad'
			END AS classification
		FROM {schema}.no_hidrografico n
		WHERE EXISTS (
			SELECT 1 FROM intersection_counts ic 
			WHERE ic.geom = n.geometria
		)
	),
	bad_rows AS (
		INSERT INTO errors.no_hidrografico_re_4_11
			select * from {schema}.no_hidrografico
				where identificador in (select identificador from nos_classified WHERE classification = 'bad')
			on conflict do nothing
			RETURNING 1
	)
	SELECT 
		COUNT(*) AS total,
		COUNT(*) FILTER (WHERE classification = 'good') AS good,
		COUNT(*) FILTER (WHERE classification = 'bad') AS bad
	FROM nos_classified into count_all, count_good, count_bad;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;


create or replace function validation.re5_5_2_validation (ndd integer, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
begin
	CREATE SCHEMA IF NOT EXISTS errors;
	CREATE TABLE IF NOT exists errors.seg_via_rodov_re_5_5_2 (like {schema}.seg_via_rodov INCLUDING ALL);

	delete from errors.seg_via_rodov_re_5_5_2;

	WITH
		intersection_pairs AS (
			SELECT 
				cf1.identificador AS id1,
				cf2.identificador AS id2,
				cf1.geometria AS geom1,
				cf2.geometria AS geom2,
				st_relate(cf1.geometria, cf2.geometria) AS de9im
			FROM {schema}.seg_via_rodov cf1
			JOIN {schema}.seg_via_rodov cf2
				ON cf1.identificador < cf2.identificador
				AND cf1.valor_posicao_vertical_transportes = cf2.valor_posicao_vertical_transportes
				AND st_intersects(cf1.geometria, cf2.geometria)
		),
		classified AS (
			SELECT 
				id1, id2,
				CASE
					-- Lines share interior points (overlap/duplicate)
					WHEN st_relate(geom1, geom2, '1********') THEN 'duplicate'
					-- Lines cross (interior intersects interior at point)
					WHEN st_relate(geom1, geom2, '0********') THEN 'crossing'
					-- Lines touch at boundary only (valid connection)
					WHEN st_relate(geom1, geom2, 'FF*F*****') 
					OR st_relate(geom1, geom2, 'FF*0F****') THEN 'valid'
					ELSE 'valid'
				END AS status
			FROM intersection_pairs
		),
		bad_ids AS (
			SELECT DISTINCT id FROM (
				SELECT id1 AS id FROM classified WHERE status IN ('duplicate', 'crossing')
				UNION
				SELECT id2 FROM classified WHERE status IN ('duplicate', 'crossing')
			) x
		),
		good_ids AS (
			SELECT DISTINCT id FROM (
				SELECT id1 AS id FROM classified WHERE status = 'valid'
				UNION
				SELECT id2 FROM classified WHERE status = 'valid'
			) x
			WHERE id NOT IN (SELECT id FROM bad_ids)
		),
		bad_rows AS (
			INSERT INTO errors.seg_via_rodov_re_5_5_2
			SELECT * FROM {schema}.seg_via_rodov
			WHERE identificador IN (SELECT id FROM bad_ids)
			ON CONFLICT DO NOTHING
			RETURNING 1
		)
		SELECT
			(SELECT COUNT(*) FROM (SELECT id1 FROM classified UNION SELECT id2 FROM classified) t) AS total,
			(SELECT COUNT(*) FROM good_ids) AS good,
			(SELECT COUNT(*) FROM bad_ids) AS bad
		INTO count_all, count_good, count_bad;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.re5_5_2_validation (ndd integer, sect geometry, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
begin
	CREATE SCHEMA IF NOT EXISTS errors;
	CREATE TABLE IF NOT exists errors.seg_via_rodov_re_5_5_2 (like {schema}.seg_via_rodov INCLUDING ALL);

	WITH
		intersection_pairs AS (
			SELECT 
				cf1.identificador AS id1,
				cf2.identificador AS id2,
				cf1.geometria AS geom1,
				cf2.geometria AS geom2,
				st_relate(cf1.geometria, cf2.geometria) AS de9im
			FROM {schema}.seg_via_rodov cf1
			JOIN {schema}.seg_via_rodov cf2
				ON cf1.identificador < cf2.identificador
				AND cf1.valor_posicao_vertical_transportes = cf2.valor_posicao_vertical_transportes
				AND st_intersects(cf1.geometria, cf2.geometria)
			WHERE ST_Intersects(cf1.geometria, sect)
		),
		classified AS (
			SELECT 
				id1, id2,
				CASE
					-- Lines share interior points (overlap/duplicate)
					WHEN st_relate(geom1, geom2, '1********') THEN 'duplicate'
					-- Lines cross (interior intersects interior at point)
					WHEN st_relate(geom1, geom2, '0********') THEN 'crossing'
					-- Lines touch at boundary only (valid connection)
					WHEN st_relate(geom1, geom2, 'FF*F*****') 
					OR st_relate(geom1, geom2, 'FF*0F****') THEN 'valid'
					ELSE 'valid'
				END AS status
			FROM intersection_pairs
		),
		bad_ids AS (
			SELECT DISTINCT id FROM (
				SELECT id1 AS id FROM classified WHERE status IN ('duplicate', 'crossing')
				UNION
				SELECT id2 FROM classified WHERE status IN ('duplicate', 'crossing')
			) x
		),
		good_ids AS (
			SELECT DISTINCT id FROM (
				SELECT id1 AS id FROM classified WHERE status = 'valid'
				UNION
				SELECT id2 FROM classified WHERE status = 'valid'
			) x
			WHERE id NOT IN (SELECT id FROM bad_ids)
		),
		bad_rows AS (
			INSERT INTO errors.seg_via_rodov_re_5_5_2
			SELECT * FROM {schema}.seg_via_rodov
			WHERE identificador IN (SELECT id FROM bad_ids)
			ON CONFLICT DO NOTHING
			RETURNING 1
		)
		SELECT
			(SELECT COUNT(*) FROM (SELECT id1 FROM classified UNION SELECT id2 FROM classified) t) AS total,
			(SELECT COUNT(*) FROM good_ids) AS good,
			(SELECT COUNT(*) FROM bad_ids) AS bad
		INTO count_all, count_good, count_bad;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;


create or replace function validation.re5_5_4_validation (ndd integer, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
begin
	CREATE SCHEMA IF NOT EXISTS errors;
	CREATE TABLE IF NOT exists errors.no_trans_rodov_re_5_5_4 (like {schema}.no_trans_rodov INCLUDING ALL);

	delete from errors.no_trans_rodov_re_5_5_4;

	with inter as (
		select distinct st_intersection(l1.geometria, l2.geometria) as geom from {schema}.seg_via_rodov l1
			join {schema}.infra_trans_rodov l2
				on st_intersects(ST_StartPoint(l1.geometria), l2.geometria)
				or st_intersects(ST_EndPoint(l1.geometria), l2.geometria)
	),
	inter_with_counts AS (
		SELECT i.geom, COUNT(n.geometria) AS node_count
		FROM inter i
		LEFT JOIN {schema}.no_trans_rodov n ON n.geometria = i.geom
		GROUP BY i.geom
	),
	estat AS (
		SELECT
			COUNT(*) FILTER (WHERE node_count <> 0) AS total,
			COUNT(*) FILTER (WHERE node_count <> 0 and node_count = 2) AS good,
			COUNT(*) FILTER (WHERE node_count <> 0 and node_count <> 2) AS bad
		FROM inter_with_counts
	),
	bad_rows AS (
		INSERT INTO errors.no_trans_rodov_re_5_5_4
			SELECT n.*
			FROM {schema}.no_trans_rodov n
			WHERE n.geometria IN (SELECT geom FROM inter_with_counts WHERE node_count <> 2)
			ON CONFLICT DO NOTHING
			RETURNING 1
	)
	select s.total, s.good, s.bad from estat s into count_all, count_good, count_bad;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

create or replace function validation.re5_5_4_validation (ndd integer, sect geometry, _args json) returns table (total int, good int, bad int) as $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
begin
	CREATE SCHEMA IF NOT EXISTS errors;
	CREATE TABLE IF NOT exists errors.no_trans_rodov_re_5_5_4 (like {schema}.no_trans_rodov INCLUDING ALL);

	with inter as (
		select distinct st_intersection(l1.geometria, l2.geometria) as geom from {schema}.seg_via_rodov l1
			join {schema}.infra_trans_rodov l2
				on st_intersects(ST_StartPoint(l1.geometria), l2.geometria)
				or st_intersects(ST_EndPoint(l1.geometria), l2.geometria)
			WHERE ST_Intersects(l2.geometria, sect)
	),
	inter_with_counts AS (
		SELECT i.geom, COUNT(n.geometria) AS node_count
		FROM inter i
		LEFT JOIN {schema}.no_trans_rodov n ON n.geometria = i.geom
		GROUP BY i.geom
	),
	estat AS (
		SELECT
			COUNT(*) FILTER (WHERE node_count <> 0) AS total,
			COUNT(*) FILTER (WHERE node_count <> 0 and node_count = 2) AS good,
			COUNT(*) FILTER (WHERE node_count <> 0 and node_count <> 2) AS bad
		FROM inter_with_counts
	),
	bad_rows AS (
		INSERT INTO errors.no_trans_rodov_re_5_5_4
			SELECT n.*
			FROM {schema}.no_trans_rodov n
			WHERE n.geometria IN (SELECT geom FROM inter_with_counts WHERE node_count <> 2)
			ON CONFLICT DO NOTHING
			RETURNING 1
	)
	select s.total, s.good, s.bad from estat s into count_all, count_good, count_bad;

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

	with candidates AS (
    	SELECT identificador, geometria, ST_PointN(geometria, 1) AS first_point
    		FROM {schema}.curva_de_nivel
    	WHERE valor_tipo_curva IN ('1', '2')
	),
	pares AS (
        SELECT 
            all_cdn.identificador,
            round(abs(st_z(all_cdn.first_point) - st_z(ST_PointN(closest_cdn.geometria, 1)))::numeric, 2) AS z_distance
        FROM candidates AS all_cdn
        CROSS JOIN LATERAL (
            SELECT geometria FROM candidates AS ports
            WHERE all_cdn.identificador != ports.identificador
            ORDER BY all_cdn.first_point <-> ports.geometria
            LIMIT 1
        ) AS closest_cdn
    ),
    bad_ids AS ( 
    	SELECT identificador FROM pares WHERE z_distance NOT IN (0, valor_equi)
    ),
    bad_rows AS (        
		INSERT INTO errors.curva_de_nivel_re3_2
	    SELECT cn.*
	    FROM {schema}.curva_de_nivel cn
	    WHERE cn.identificador IN (SELECT identificador FROM bad_ids)
		RETURNING 1
    )
	SELECT count(*) FROM bad_rows into count_bad;

	select (count_all - count_bad) into count_good;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;


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
	CREATE TABLE IF NOT exists errors.curva_de_nivel_re3_2 (like {schema}.curva_de_nivel INCLUDING ALL);

	execute format('select count(*) from {schema}.curva_de_nivel') into count_all;

	execute format(
		'WITH candidates AS ('
    			'SELECT identificador, geometria, ST_PointN(geometria, 1) AS first_point '
    		'FROM {schema}.curva_de_nivel c '
    	'WHERE valor_tipo_curva IN (''1'', ''2'') and ST_Intersects(c.geometria, %1$L)'
		'),'
		'pares AS ('
			'SELECT '
				'all_cdn.identificador,'
				'round(abs(st_z(all_cdn.first_point) - st_z(ST_PointN(closest_cdn.geometria, 1)))::numeric, 2) AS z_distance '
			'FROM candidates AS all_cdn '
			'CROSS JOIN LATERAL ('
				'SELECT geometria '
				'FROM candidates AS ports '
				'WHERE all_cdn.identificador != ports.identificador '
				'ORDER BY all_cdn.first_point <-> ports.geometria '
				'LIMIT 1 '
			') AS closest_cdn'
		'),'
		'bad_ids AS ( '
    		'SELECT identificador FROM pares WHERE z_distance NOT IN (0,  %2$L)'
    	'),'
		'bad_rows AS ('
			'INSERT INTO errors.curva_de_nivel_re3_2 '
			'SELECT cn.* '
			'FROM {schema}.curva_de_nivel cn '
			'WHERE cn.identificador IN ('
				'SELECT identificador '
				'FROM bad_ids )'
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

create or replace function validation.re3_2_restantes (ndd integer, _args json) returns table (total integer, good integer, bad integer) as $$
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

	CREATE TABLE IF NOT exists errors.curva_de_nivel_re3_2 (like {schema}.curva_de_nivel INCLUDING ALL);

	select count(*) from validation.curva_de_nivel_restantes into count_all;

	with candidates AS (
    	SELECT identificador, geometria, ST_PointN(geometria, 1) AS first_point
    		FROM validation.curva_de_nivel_restantes
	),
	pares AS (
        SELECT 
            all_cdn.identificador,
            round(abs(st_z(all_cdn.first_point) - st_z(ST_PointN(closest_cdn.geometria, 1)))::numeric, 2) AS z_distance
        FROM candidates AS all_cdn
        CROSS JOIN LATERAL (
            SELECT geometria FROM {schema}.curva_de_nivel AS ports
            WHERE all_cdn.identificador != ports.identificador
            ORDER BY all_cdn.first_point <-> ports.geometria
            LIMIT 1
        ) AS closest_cdn
    ),
    bad_ids AS ( 
    	SELECT identificador FROM pares WHERE z_distance NOT IN (0, valor_equi)
    ),
    bad_rows AS (        
		INSERT INTO errors.curva_de_nivel_re3_2
	    SELECT cn.*
	    FROM validation.curva_de_nivel_restantes cn
	    WHERE cn.identificador IN (SELECT identificador FROM bad_ids)
		ON CONFLICT (identificador) DO nothing
		RETURNING 1
    )
	SELECT count(*) FROM bad_rows into count_bad;

	select (count_all - count_bad) into count_good;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

CREATE OR REPLACE FUNCTION validation.re3_2_new_validation(ndd integer, _args json)
 RETURNS TABLE(total integer, good integer, bad integer) AS $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
	count_all_restantes integer := 0;
	count_good_restantes integer := 0;
	count_bad_restantes integer := 0;
	valor_equi integer;
	res record;
begin
	if ndd=1 then
		select coalesce(_args->>'re3_2_ndd1', '2')::int into valor_equi;
	else
		select coalesce(_args->>'re3_2_ndd2', '5')::int into valor_equi;
	end if;

	CREATE SCHEMA IF NOT EXISTS errors;
	-- CREATE EXTENSION IF NOT EXISTS postgis_raster;
	CREATE TABLE IF NOT exists errors.curva_de_nivel_re3_2 (like {schema}.curva_de_nivel INCLUDING ALL);
	-- TRUNCATE errors.curva_de_nivel_re3_2;

	CREATE TABLE IF NOT exists validation.area_trabalho_grid_50 as
	WITH param as (select 50 as gridsize),
	area as (
		select ST_Envelope(geometria) as envelope from {schema}.area_trabalho t
		),
	canto as (select ceil(ST_XMin(envelope))::int as minimoX, ceil(ST_YMin(envelope))::int as minimoY, ceil(ST_XMax(envelope))::int as maximoX, ceil(ST_YMax(envelope))::int as maximoY,
		ceil(ST_XMax(envelope) - ST_XMin(envelope))::int as largura, ceil(ST_YMax(envelope) - ST_YMin(envelope))::int as altura 
		from area),
	grid AS (
	    SELECT (ST_PixelAsPolygons( ST_AddBand(
	            ST_MakeEmptyRaster(
	            ceil((maximoX - minimoX) / gridsize)::int,
	            ceil((maximoY - minimoY) / gridsize)::int,
	            minimoX, maximoY, gridsize, -1 * gridsize, 0, 0, 3763), '8BUI'), 1)).geom AS geom
	    from canto, param
	),
	lines AS (
	    SELECT DISTINCT
	        (ST_DumpSegments(ST_Boundary(geom))).geom AS line
	    FROM grid
	),
	classified AS (
	    SELECT
	        line,
	        abs(ST_YMin(line) - ST_YMax(line)) as delta_horizontal,
	        abs(ST_XMin(line) - ST_XMax(line)) as delta_vertical,
	        CASE
	            WHEN ST_YMin(line) = ST_YMax(line) THEN 'horizontal'
	            WHEN ST_XMin(line) = ST_XMax(line) THEN 'vertical'
	        END AS orientation
	    FROM lines
	),
	merged as (
		SELECT gen_random_uuid() as id, ST_LineMerge(ST_Union(line)) AS line, 'horizontal' AS orientation
		FROM classified WHERE orientation = 'horizontal'
		GROUP BY ST_YMin(line)
		UNION ALL
		SELECT gen_random_uuid() as id, ST_LineMerge(ST_Union(line)) AS line, 'vertical' AS orientation
		FROM classified WHERE orientation = 'vertical'
		GROUP BY ST_XMin(line)),
	clipped as (
		select st_intersection(line, geometria) as line, orientation
		from merged, {schema}.area_trabalho)
	select gen_random_uuid() as id, (st_dump(line)).geom as line, orientation
	from clipped;
	
	CREATE INDEX IF NOT EXISTS idx_area_trabalho_grid_50_geometria ON validation.area_trabalho_grid_50 USING gist(line);

	CREATE TABLE IF NOT exists validation.area_trabalho_pontos_50 as
	WITH intersecoes AS (
	    SELECT
	        atg.id,
	        cdn.identificador,
	        atg.orientation,
	        ST_Intersection(cdn.geometria, atg.line) AS line
	    FROM validation.area_trabalho_grid_50 atg
	    JOIN curva_de_nivel cdn
	        ON cdn.valor_tipo_curva IN ('1', '2')
	        AND ST_Intersects(cdn.geometria, atg.line)
	),
	geometrias AS (
	    SELECT
	        id,
	        identificador,
	        orientation,
	        ST_StartPoint(dumped.geom)            AS geometria,
	        ST_Z(ST_StartPoint(dumped.geom))      AS z
	    FROM intersecoes,
	    LATERAL (SELECT (ST_Dump(line)).geom) AS dumped(geom)
	)
	SELECT * FROM geometrias;
	
	CREATE INDEX IF NOT EXISTS idx_area_trabalho_pontos_50_geometria ON validation.area_trabalho_pontos_50 USING gist(geometria);
	CREATE INDEX IF NOT EXISTS idx_area_trabalho_pontos_50_identificador ON validation.area_trabalho_pontos_50(identificador);

	INSERT INTO errors.curva_de_nivel_re3_2
	with horizontal as (
		SELECT
		  identificador,
		  z,
		  LAG(z, 1) OVER ( partition by id ORDER BY st_x(geometria)) ponto_anterior,
		  LEAD(z, 1) OVER ( partition by id ORDER BY st_x(geometria)) ponto_seguinte
		FROM
		  validation.area_trabalho_pontos_50 where orientation = 'horizontal'),
	vertical as (
		SELECT
		  identificador,
		  z,
		  LAG(z, 1) OVER ( partition by id ORDER BY st_y(geometria)) ponto_anterior,
		  LEAD(z, 1) OVER ( partition by id ORDER BY st_y(geometria)) ponto_seguinte
		FROM
		  validation.area_trabalho_pontos_50 where orientation = 'vertical')	  
	select cdn.* from horizontal, {schema}.curva_de_nivel cdn
	where horizontal.identificador = cdn.identificador and not (
	(abs(z-coalesce(ponto_anterior,z)) = valor_equi or abs(z-coalesce(ponto_anterior,z)) = 0) and (abs(z-coalesce(ponto_seguinte,z)) = valor_equi or abs(z-coalesce(ponto_seguinte,z)) = 0)
	)
	union
	select cdn.* from vertical, {schema}.curva_de_nivel cdn
	where vertical.identificador = cdn.identificador and not (
	(abs(z-coalesce(ponto_anterior,z)) = valor_equi or abs(z-coalesce(ponto_anterior,z)) = 0) and (abs(z-coalesce(ponto_seguinte,z)) = valor_equi or abs(z-coalesce(ponto_seguinte,z)) = 0)
	)
	ON CONFLICT (identificador) DO nothing;

	select count(*) from {schema}.curva_de_nivel into count_all;
	select count(*) from errors.curva_de_nivel_re3_2 into count_bad;

	drop table if exists validation.curva_de_nivel_restantes;

	CREATE TABLE IF NOT exists validation.curva_de_nivel_restantes as
	select * from {schema}.curva_de_nivel cdn
	where valor_tipo_curva IN ('1', '2') and identificador not in (select identificador from validation.area_trabalho_pontos_50);

	select v.total, v.good, v.bad from validation.re3_2_restantes(ndd, _args) as v into res;
	raise notice '% % %', res.total, res.good, res.bad;

	select (count_all - count_bad - res.bad) into count_good;

	select (count_bad + res.bad) into count_bad;

	return query select count_all as total, count_good as good, count_bad as bad;
end;
$$ language plpgsql;

CREATE OR REPLACE FUNCTION validation.re3_2_new_validation(ndd integer, sect geometry, _args json)
 RETURNS TABLE(total integer, good integer, bad integer) AS $$
declare
	count_all integer := 0;
	count_good integer := 0;
	count_bad integer := 0;
	count_all_restantes integer := 0;
	count_good_restantes integer := 0;
	count_bad_restantes integer := 0;
	valor_equi integer;
	res record;
begin
	if ndd=1 then
		select coalesce(_args->>'re3_2_ndd1', '2')::int into valor_equi;
	else
		select coalesce(_args->>'re3_2_ndd2', '5')::int into valor_equi;
	end if;

	CREATE SCHEMA IF NOT EXISTS errors;
	-- CREATE EXTENSION IF NOT EXISTS postgis_raster;
	CREATE TABLE IF NOT exists errors.curva_de_nivel_re3_2 (like {schema}.curva_de_nivel INCLUDING ALL);
	-- TRUNCATE errors.curva_de_nivel_re3_2;

	CREATE TABLE IF NOT exists validation.area_trabalho_grid_50 as
	WITH param as (select 50 as gridsize),
	area as (
		select ST_Envelope(sect) as envelope
		),
	canto as (select ceil(ST_XMin(envelope))::int as minimoX, ceil(ST_YMin(envelope))::int as minimoY, ceil(ST_XMax(envelope))::int as maximoX, ceil(ST_YMax(envelope))::int as maximoY,
		ceil(ST_XMax(envelope) - ST_XMin(envelope))::int as largura, ceil(ST_YMax(envelope) - ST_YMin(envelope))::int as altura 
		from area),
	grid AS (
	    SELECT (ST_PixelAsPolygons( ST_AddBand(
	            ST_MakeEmptyRaster(
	            ceil((maximoX - minimoX) / gridsize)::int,
	            ceil((maximoY - minimoY) / gridsize)::int,
	            minimoX, maximoY, gridsize, -1 * gridsize, 0, 0, 3763), '8BUI'), 1)).geom AS geom
	    from canto, param
	),
	lines AS (
	    SELECT DISTINCT
	        (ST_DumpSegments(ST_Boundary(geom))).geom AS line
	    FROM grid
	),
	classified AS (
	    SELECT
	        line,
	        abs(ST_YMin(line) - ST_YMax(line)) as delta_horizontal,
	        abs(ST_XMin(line) - ST_XMax(line)) as delta_vertical,
	        CASE
	            WHEN ST_YMin(line) = ST_YMax(line) THEN 'horizontal'
	            WHEN ST_XMin(line) = ST_XMax(line) THEN 'vertical'
	        END AS orientation
	    FROM lines
	),
	merged as (
		SELECT gen_random_uuid() as id, ST_LineMerge(ST_Union(line)) AS line, 'horizontal' AS orientation
		FROM classified WHERE orientation = 'horizontal'
		GROUP BY ST_YMin(line)
		UNION ALL
		SELECT gen_random_uuid() as id, ST_LineMerge(ST_Union(line)) AS line, 'vertical' AS orientation
		FROM classified WHERE orientation = 'vertical'
		GROUP BY ST_XMin(line)),
	clipped as (
		select st_intersection(line, sect) as line, orientation
		from merged)
	select gen_random_uuid() as id, (st_dump(line)).geom as line, orientation
	from clipped;
	
	CREATE INDEX IF NOT EXISTS idx_area_trabalho_grid_50_geometria ON validation.area_trabalho_grid_50 USING gist(line);

	CREATE TABLE IF NOT exists validation.area_trabalho_pontos_50 as
	WITH intersecoes AS (
	    SELECT
	        atg.id,
	        cdn.identificador,
	        atg.orientation,
	        ST_Intersection(cdn.geometria, atg.line) AS line
	    FROM validation.area_trabalho_grid_50 atg
	    JOIN curva_de_nivel cdn
	        ON cdn.valor_tipo_curva IN ('1', '2')
	        AND ST_Intersects(cdn.geometria, atg.line)
	),
	geometrias AS (
	    SELECT
	        id,
	        identificador,
	        orientation,
	        ST_StartPoint(dumped.geom)            AS geometria,
	        ST_Z(ST_StartPoint(dumped.geom))      AS z
	    FROM intersecoes,
	    LATERAL (SELECT (ST_Dump(line)).geom) AS dumped(geom)
	)
	SELECT * FROM geometrias;
	
	CREATE INDEX IF NOT EXISTS idx_area_trabalho_pontos_50_geometria ON validation.area_trabalho_pontos_50 USING gist(geometria);
	CREATE INDEX IF NOT EXISTS idx_area_trabalho_pontos_50_identificador ON validation.area_trabalho_pontos_50(identificador);

	INSERT INTO errors.curva_de_nivel_re3_2
	with horizontal as (
		SELECT
		  identificador,
		  z,
		  LAG(z, 1) OVER ( partition by id ORDER BY st_x(geometria)) ponto_anterior,
		  LEAD(z, 1) OVER ( partition by id ORDER BY st_x(geometria)) ponto_seguinte
		FROM
		  validation.area_trabalho_pontos_50 where orientation = 'horizontal'),
	vertical as (
		SELECT
		  identificador,
		  z,
		  LAG(z, 1) OVER ( partition by id ORDER BY st_y(geometria)) ponto_anterior,
		  LEAD(z, 1) OVER ( partition by id ORDER BY st_y(geometria)) ponto_seguinte
		FROM
		  validation.area_trabalho_pontos_50 where orientation = 'vertical')	  
	select cdn.* from horizontal, {schema}.curva_de_nivel cdn
	where horizontal.identificador = cdn.identificador and not (
	(abs(z-coalesce(ponto_anterior,z)) = valor_equi or abs(z-coalesce(ponto_anterior,z)) = 0) and (abs(z-coalesce(ponto_seguinte,z)) = valor_equi or abs(z-coalesce(ponto_seguinte,z)) = 0)
	)
	union
	select cdn.* from vertical, {schema}.curva_de_nivel cdn
	where vertical.identificador = cdn.identificador and not (
	(abs(z-coalesce(ponto_anterior,z)) = valor_equi or abs(z-coalesce(ponto_anterior,z)) = 0) and (abs(z-coalesce(ponto_seguinte,z)) = valor_equi or abs(z-coalesce(ponto_seguinte,z)) = 0)
	)
	ON CONFLICT (identificador) DO nothing;

	select count(*) from {schema}.curva_de_nivel into count_all;
	select count(*) from errors.curva_de_nivel_re3_2 into count_bad;

	drop table if exists validation.curva_de_nivel_restantes;

	CREATE TABLE IF NOT exists validation.curva_de_nivel_restantes as
	select cdn.* from {schema}.curva_de_nivel cdn
	where cdn.valor_tipo_curva IN ('1', '2') 
		and st_intersects(cdn.geometria, sect) 
		and cdn.identificador not in (select identificador from validation.area_trabalho_pontos_50);

	select v.total, v.good, v.bad from validation.re3_2_restantes(ndd, _args) as v into res;
	raise notice '% % %', res.total, res.good, res.bad;

	select (count_all - count_bad - res.bad) into count_good;

	select (count_bad + res.bad) into count_bad;

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
	add_fltr text;
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
			add_fltr := 'valor_barreira=''1'' and';
		else
			tipo_no := '5';
			add_fltr := '';
		end if;

		execute format('select count(t.*) from {schema}.%I t, {schema}.no_hidrografico nh
			where St_intersects(t.geometria, nh.geometria) and nh.valor_tipo_no_hidrografico=''%s''', tabela, tipo_no) INTO good_aux;

		RAISE NOTICE 'Good is % for table %', good_aux, tabela;
		count_good := count_good + good_aux;

		execute format('select count(t.*) from {schema}.%1$I t
			where %3$s (not (select ST_intersects(t.geometria, f.geometria) from 
					(select geom_col as geometria from validation.no_hidro) as f)
				or t.identificador not in (select distinct ta.identificador from {schema}.%1$I ta, {schema}.no_hidrografico nh 
					where St_intersects(ta.geometria, nh.geometria) and nh.valor_tipo_no_hidrografico=''%2$s''))', tabela, tipo_no, add_fltr) INTO bad_aux;
	
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
				where %4$s (not (select ST_intersects(t.geometria, f.geometria) from 
						(select geom_col as geometria from validation.no_hidro) as f)
					or t.identificador not in (select distinct ta.identificador from {schema}.%2$I ta, {schema}.no_hidrografico nh 
						where St_intersects(ta.geometria, nh.geometria) and nh.valor_tipo_no_hidrografico=''%3$s''))', tabela_erro, tabela, tipo_no, add_fltr);
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
	add_fltr text;
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
			add_fltr := 'valor_barreira=''1'' and';
		else
			tipo_no := '5';
			add_fltr := '';
		end if;

		execute format('select count(t.*) from {schema}.%I t, {schema}.no_hidrografico nh
			where ST_Intersects(t.geometria, %3$L) and St_intersects(t.geometria, nh.geometria) and nh.valor_tipo_no_hidrografico=''%2$s''', tabela, tipo_no, sect) INTO good_aux;

		RAISE NOTICE 'Good is % for table %', good_aux, tabela;
		count_good := count_good + good_aux;

		execute format('select count(t.*) from {schema}.%1$I t
			where %4$s ST_Intersects(geometria, %3$L) and (not (select ST_intersects(t.geometria, f.geometria) from 
					(select geom_col as geometria from validation.no_hidro) as f)
				or t.identificador not in (select distinct ta.identificador from {schema}.%1$I ta, {schema}.no_hidrografico nh 
					where St_intersects(ta.geometria, nh.geometria) and nh.valor_tipo_no_hidrografico=''%2$s''))', tabela, tipo_no, sect, add_fltr) INTO bad_aux;
	
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
				where %5$s ST_Intersects(geometria, %4$L) and (not (select ST_intersects(t.geometria, f.geometria) from 
						(select geom_col as geometria from validation.no_hidro) as f)
					or t.identificador not in (select distinct ta.identificador from {schema}.%2$I ta, {schema}.no_hidrografico nh 
						where St_intersects(ta.geometria, nh.geometria) and nh.valor_tipo_no_hidrografico=''%3$s''))', tabela_erro, tabela, tipo_no, sect, add_fltr);
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
declare
	atgr RECORD;
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
				SELECT cdn.identificador, (ST_DumpPoints(ST_LineInterpolatePoints(geometria, least(4.0/st_length(geometria), 1.0)))).*
					from (select identificador, (ST_Dump(geometria)).geom as geometria from {schema}.curva_de_nivel) as cdn
			) as pontos
			union SELECT concat( identificador::text, '-0') as identificador, ST_PointN(geometria, 1) as geometria
				from {schema}.curva_de_nivel cdn
			union SELECT concat( identificador::text, '-', ST_NPoints(geometria)) as identificador, ST_PointN(geometria, -1) as geometria
				from {schema}.curva_de_nivel cdn;

		for atgr in select * from validation.area_trabalho_grid loop
			insert into validation.curva_nivel_tin (geometria)
			with tin as (
				SELECT ST_DelaunayTriangles(st_union(geometria), 0.1) as geom
				from (
					select geometria from validation.curva_de_nivel_points_interval_v2
						where ST_Intersects(geometria, atgr.geometria)
					union
					select geometria from {schema}.ponto_cotado
						where ST_Intersects(geometria, atgr.geometria)
				) as foo
			) select (ST_Dump(geom)).geom As geometria from tin;
		end loop;

		CREATE INDEX curva_nivel_tin_geom_idx ON validation.curva_nivel_tin USING gist (geometria);
	end if;
end;
$$ language plpgsql;

select validation.create_tin();

CREATE OR REPLACE PROCEDURE validation.create_curva_de_nivel_segmento(
    tolerancia    double precision,
    max_vertices  integer DEFAULT 256
)
LANGUAGE plpgsql
AS $$
DECLARE
    ultimo_id uuid := '00000000-0000-0000-0000-000000000000';
    ids_lote  int;
    max_id    uuid;
    feitas    int := 0;
BEGIN
    IF tolerancia <= 0 OR tolerancia > 5 THEN
        RAISE EXCEPTION 'Tolerância % fora do intervalo razoável (0, 5] m', tolerancia;
    END IF;
    IF max_vertices < 128 THEN
        RAISE EXCEPTION 'max_vertices % é demasiado baixo; o mínimo é 128', max_vertices;
    END IF;

    IF (SELECT count(*) FROM information_schema.tables
        WHERE table_schema = 'validation' AND table_name = 'curva_de_nivel_segmento') > 0 THEN
        RAISE NOTICE 'A tabela já existe. Nada a fazer.';
        RETURN;
    END IF;

    CREATE UNLOGGED TABLE validation.curva_de_nivel_segmento (
        identificador uuid,
        z_curva       double precision,
        geom2d        geometry
    );

	INSERT INTO validation.curva_de_nivel_segmento (identificador, z_curva, geom2d)
	SELECT cn.identificador,
	       ST_Z(ST_StartPoint(cn.geometria)),
	       ST_Subdivide(ST_SimplifyPreserveTopology(ST_Force2D(cn.geometria), tolerancia), max_vertices)
	FROM {schema}.curva_de_nivel cn;

    CREATE INDEX idx_curva_de_nivel_segmento
        ON validation.curva_de_nivel_segmento USING GIST (geom2d);
    ANALYZE validation.curva_de_nivel_segmento;
END;
$$;

-- Criar área de trabalho multi-polígono para casos com múltiplas áreas de trabalho no mesmo projecto
CREATE TABLE IF NOT EXISTS validation.area_trabalho_multi AS
(
	SELECT st_multi(st_union(geometria)) as geometria
	FROM {schema}.area_trabalho
);
CREATE INDEX ON validation.area_trabalho_multi USING gist(geometria);

CREATE TABLE IF NOT EXISTS validation.no_hidro AS (
	SELECT ST_Collect(f.geometria) AS geom_col FROM (
		SELECT geometria FROM {schema}.no_hidrografico
	) AS f
);

CREATE TABLE IF NOT EXISTS validation.consistencia_valores_def (
	entidade text NULL,
	atributo text NULL,
	versao text[] NULL,
	ndd text NULL,
	valores text[] NULL
);

DELETE FROM validation.consistencia_valores_def;
INSERT INTO validation.consistencia_valores_def (entidade, atributo, versao, ndd, valores) VALUES
('adm_publica', 'valor_tipo_adm_publica', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3,4,5}'),
('adm_publica', 'valor_tipo_adm_publica', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2,3,4,5}'),
('agua_lentica', 'valor_agua_lentica', '{v1.1.2}', '1', '{1,2,3}'),
('agua_lentica', 'valor_agua_lentica', '{v1.1.2}', '2', '{1,2}'),
('agua_lentica', 'valor_agua_lentica', '{v2.0.1,v2.0.2}', '1', '{1,2,3,4}'),
('agua_lentica', 'valor_agua_lentica', '{v2.0.1,v2.0.2}', '2', '{1,2,3,4}'),
('area_agricola_florestal_mato', 'valor_areas_agricolas_florestais_matos', '{v1.1.2}', '1', '{1,2.1,2.2,3,4.1,4.2,5}'),
('area_agricola_florestal_mato', 'valor_areas_agricolas_florestais_matos', '{v1.1.2}', '2', '{1.1,1.2,1.3,1.4,1.5,2.1,2.2,3,4.1.1,4.1.2,4.1.3,4.1.4,4.1.5,4.1.6,4.1.7,4.2.1,4.2.2,4.2.3,5}'),
('area_agricola_florestal_mato', 'valor_areas_agricolas_florestais_matos', '{v2.0.1,v2.0.2}', '1', '{1,2.1,2.2,3,4.1,4.2,4.3,5}'),
('area_agricola_florestal_mato', 'valor_areas_agricolas_florestais_matos', '{v2.0.1,v2.0.2}', '2', '{1.1,1.2,1.3,1.4,1.5,1.6,1.7,1.8,2.1,2.2,3,4.1.1,4.1.2,4.1.3,4.1.4,4.1.5,4.1.6,4.1.7,4.2.1,4.2.2,4.2.3,4.3,5}'),
('area_infra_trans_aereo', 'valor_tipo_area_infra_trans_aereo', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2}'),
('area_infra_trans_aereo', 'valor_tipo_area_infra_trans_aereo', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2}'),
('area_infra_trans_via_navegavel', 'valor_tipo_area_infra_trans_via_navegavel', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3}'),
('area_infra_trans_via_navegavel', 'valor_tipo_area_infra_trans_via_navegavel', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2,3}'),
('area_trabalho', 'valor_nivel_de_detalhe', '{v2.0.1,v2.0.2}', '1', '{1}'),
('area_trabalho', 'valor_nivel_de_detalhe', '{v2.0.1,v2.0.2}', '2', '{2}'),
('areas_artificializadas', 'valor_areas_artificializadas', '{v1.1.2}', '1', '{1,2,3,4,5,6,7,8,9}'),
('areas_artificializadas', 'valor_areas_artificializadas', '{v1.1.2}', '2', '{1,2,3,4,5,6,7,8,9}'),
('areas_artificializadas', 'valor_areas_artificializadas', '{v2.0.1,v2.0.2}', '1', '{1,2,3,4,5,6,7,8,9,10,11,12,13}'),
('areas_artificializadas', 'valor_areas_artificializadas', '{v2.0.1,v2.0.2}', '2', '{1,2,3,4,5,6,7,8,9,10,11,12,13}'),
('barreira', 'valor_barreira', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3,4,5,6}'),
('barreira', 'valor_barreira', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2,3,4,5,6}'),
('cabo_electrico', 'valor_designacao_tensao', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3,4}'),
('cabo_electrico', 'valor_designacao_tensao', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2}'),
('cabo_electrico', 'valor_posicao_vertical', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,0,-1}'),
('cabo_electrico', 'valor_posicao_vertical', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,0,-1}'),
('conduta_de_agua', 'valor_conduta_agua', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2}'),
('conduta_de_agua', 'valor_conduta_agua', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2}'),
('conduta_de_agua', 'valor_posicao_vertical', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,0,-1}'),
('conduta_de_agua', 'valor_posicao_vertical', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,0,-1}'),
('constru_linear', 'valor_construcao_linear', '{v1.1.2}', '1', '{1,2,3,4,5,6,7,8}'),
('constru_linear', 'valor_construcao_linear', '{v1.1.2}', '2', '{1,2,3,4,5,8}'),
('constru_linear', 'valor_construcao_linear', '{v2.0.1}', '1', '{1,2,3,4,5,6,7,8,11}'),
('constru_linear', 'valor_construcao_linear', '{v2.0.1}', '2', '{1,2,3,4,5,8,11}'),
('constru_linear', 'valor_construcao_linear', '{v2.0.2}', '1', '{5,6,7,8,11,12,13,14}'),
('constru_linear', 'valor_construcao_linear', '{v2.0.2}', '2', '{5,8,11,12,13,14}'),
('constru_na_margem', 'valor_tipo_const_margem', '{v2.0.1,v2.0.2}', '1', '{1,2,3,4,5,6}'),
('constru_na_margem', 'valor_tipo_const_margem', '{v2.0.1,v2.0.2}', '2', '{1,2,3,4,5,6}'),
('constru_polig', 'valor_tipo_construcao', '{v1.1.2}', '1', '{1,2,3,4,5,6,7,8,10,11}'),
('constru_polig', 'valor_tipo_construcao', '{v1.1.2}', '2', '{1,2,3,4,5,6,7,8,10,11}'),
('constru_polig', 'valor_tipo_construcao', '{v2.0.1}', '1', '{3,4,5,6,7,8,10,11,12}'),
('constru_polig', 'valor_tipo_construcao', '{v2.0.1}', '2', '{3,4,5,6,7,8,10,11,12}'),
('constru_polig', 'valor_tipo_construcao', '{v2.0.2}', '1', '{3,4,5,6,7,8,10,11,12,13}'),
('constru_polig', 'valor_tipo_construcao', '{v2.0.2}', '2', '{3,4,5,6,7,8,10,11,12,13}'),
('curso_de_agua_eixo', 'valor_curso_de_agua', '{v1.1.2}', '1', '{1,2,3,4,5,6}'),
('curso_de_agua_eixo', 'valor_curso_de_agua', '{v1.1.2}', '2', '{1,2,3,4,5,6}'),
('curso_de_agua_eixo', 'valor_curso_de_agua', '{v2.0.1,v2.0.2}', '1', '{3,4,5,6,7}'),
('curso_de_agua_eixo', 'valor_curso_de_agua', '{v2.0.1,v2.0.2}', '2', '{3,4,5,6,7}'),
('curso_de_agua_eixo', 'valor_natureza', '{v2.0.1,v2.0.2}', '1', '{1,2,3}'),
('curso_de_agua_eixo', 'valor_natureza', '{v2.0.1,v2.0.2}', '2', '{1,2,3}'),
('curso_de_agua_eixo', 'valor_posicao_vertical', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,0,-1}'),
('curso_de_agua_eixo', 'valor_posicao_vertical', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,0,-1}'),
('curva_de_nivel', 'valor_tipo_curva', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2}'),
('curva_de_nivel', 'valor_tipo_curva', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2}'),
('designacao_local', 'valor_local_nomeado', '{v1.1.2}', '1', '{3,4,5,6.2,6.3,6.4,6.5,6.6,6.7,6.8,6.9,6.10,7.1,7.2,7.3,8,9,10,11,12,13,14,15}'),
('designacao_local', 'valor_local_nomeado', '{v1.1.2}', '2', '{1,2,3,4,5,6.1,6.2,6.3,6.4,6.5,6.6,6.7,6.8,6.9,6.10,7.1,7.2,7.3,8,9,10,11,12,13,14,15}'),
('designacao_local', 'valor_local_nomeado', '{v2.0.1,v2.0.2}', '1', '{3,4,5,6.1,6.2,6.3,6.4,6.5,6.6,6.7,6.8,6.9,6.10,6.11,6.12,6.13,7.1,7.2,7.3,8,9,10,11,12,13,14,15}'),
('designacao_local', 'valor_local_nomeado', '{v2.0.1,v2.0.2}', '2', '{1,2,3,4,5,6.1,6.2,6.3,6.4,6.5,6.6,6.7,6.8,6.9,6.10,6.11,6.12,6.13,7.1,7.2,7.3,8,9,10,11,12,13,14,15}'),
('edificio', 'valor_condicao_const', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{3,5}'),
('edificio', 'valor_condicao_const', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{3,5}'),
('edificio', 'valor_elemento_edificio_xy', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{4,6}'),
('edificio', 'valor_elemento_edificio_xy', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{4,6}'),
('edificio', 'valor_elemento_edificio_z', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{14}'),
('edificio', 'valor_elemento_edificio_z', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{14}'),
('edificio', 'valor_forma_edificio', '{v1.1.2}', '1', '{1,2,3,4,5,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29}'),
('edificio', 'valor_forma_edificio', '{v1.1.2}', '2', '{1,2,3,4,5,7,8,9,10,12,13,14,15,16,17,18,19,20,21,23,24,25,26,27,28,29}'),
('edificio', 'valor_forma_edificio', '{v2.0.1,v2.0.2}', '1', '{1,2,3,4,5,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35}'),
('edificio', 'valor_forma_edificio', '{v2.0.1,v2.0.2}', '2', '{1,2,3,4,5,7,8,9,10,12,13,14,15,16,17,18,19,20,21,23,24,25,26,27,28,29,30,31,32,33,34,35}'),
('elem_assoc_agua', 'valor_elemento_associado_agua', '{v1.1.2}', '1', '{2,3,4,5,7,8,9}'),
('elem_assoc_agua', 'valor_elemento_associado_agua', '{v1.1.2}', '2', '{2,3,4,5,7,8,9}'),
('elem_assoc_agua', 'valor_elemento_associado_agua', '{v2.0.1,v2.0.2}', '1', '{2.1,2.2,3,4,5,7.1,7.2,8,9}'),
('elem_assoc_agua', 'valor_elemento_associado_agua', '{v2.0.1,v2.0.2}', '2', '{2.1,2.2,3,4,5,7.1,7.2,8,9}'),
('elem_assoc_eletricidade', 'valor_elemento_associado_electricidade', '{v1.1.2}', '1', '{1.1,1.2,1.4,2,3,4,5,6.1,6.2,7.1,7.2,7.3,7.4,8}'),
('elem_assoc_eletricidade', 'valor_elemento_associado_electricidade', '{v1.1.2}', '2', '{1.1,1.2,1.4,2,3,4,7.1,7.4,8}'),
('elem_assoc_eletricidade', 'valor_elemento_associado_electricidade', '{v2.0.1}', '1', '{1.1,1.2,1.3,1.4,1.5,1.6,2,3,4,5,6.1,6.2,6.3,7.1,7.2,7.3,7.4,8,9}'),
('elem_assoc_eletricidade', 'valor_elemento_associado_electricidade', '{v2.0.1}', '2', '{1.1,1.2,1.3,1.4,1.5,1.6,2,3,4,7.1,7.4,8}'),
('elem_assoc_eletricidade', 'valor_elemento_associado_electricidade', '{v2.0.2}', '1', '{1.1,1.2,1.3,1.4,1.5,1.6,2,3,4,6.1,6.2,6.3,7.1,7.2,7.3,7.4,8,9}'),
('elem_assoc_eletricidade', 'valor_elemento_associado_electricidade', '{v2.0.2}', '2', '{1.1,1.2,1.3,1.4,1.5,1.6,2,3,4,7.1,7.4,8}'),
('elem_assoc_pgq', 'valor_elemento_associado_pgq', '{v1.1.2}', '1', '{1,2.1,2.2,2.3,2.4,3}'),
('elem_assoc_pgq', 'valor_elemento_associado_pgq', '{v1.1.2}', '2', '{1,2.1,2.2,2.3,2.4,3}'),
('elem_assoc_pgq', 'valor_elemento_associado_pgq', '{v2.0.1,v2.0.2}', '1', '{1,2.1,2.2,2.3,2.4,2.100,3}'),
('elem_assoc_pgq', 'valor_elemento_associado_pgq', '{v2.0.1,v2.0.2}', '2', '{1,2.1,2.2,2.3,2.4,2.100,3}'),
('elem_assoc_telecomunicacoes', 'valor_elemento_associado_telecomunicacoes', '{v1.1.2}', '1', '{1,3}'),
('elem_assoc_telecomunicacoes', 'valor_elemento_associado_telecomunicacoes', '{v1.1.2}', '2', '{3}'),
('elem_assoc_telecomunicacoes', 'valor_elemento_associado_telecomunicacoes', '{v2.0.1,v2.0.2}', '1', '{1,2,3}'),
('elem_assoc_telecomunicacoes', 'valor_elemento_associado_telecomunicacoes', '{v2.0.1,v2.0.2}', '2', '{3}'),
('fronteira', 'valor_estado_fronteira', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2}'),
('fronteira', 'valor_estado_fronteira', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2}'),
('fronteira_terra_agua', 'valor_tipo_fronteira_terra_agua', '{v2.0.1,v2.0.2}', '1', '{1,2,3,4}'),
('fronteira_terra_agua', 'valor_tipo_fronteira_terra_agua', '{v2.0.1,v2.0.2}', '2', '{1,2,3,4}'),
('infra_trans_aereo', 'valor_categoria_infra_trans_aereo', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3}'),
('infra_trans_aereo', 'valor_categoria_infra_trans_aereo', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2,3}'),
('infra_trans_aereo', 'valor_restricao_infra_trans_aereo', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1}'),
('infra_trans_aereo', 'valor_restricao_infra_trans_aereo', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1}'),
('infra_trans_aereo', 'valor_tipo_infra_trans_aereo', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3,4}'),
('infra_trans_aereo', 'valor_tipo_infra_trans_aereo', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2,3,4}'),
('infra_trans_ferrov', 'valor_tipo_infra_trans_ferrov', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2}'),
('infra_trans_ferrov', 'valor_tipo_infra_trans_ferrov', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2}'),
('infra_trans_rodov', 'valor_tipo_infra_trans_rodov', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3,4,5,6,7,8,9}'),
('infra_trans_rodov', 'valor_tipo_infra_trans_rodov', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{2,4,5,6,7,8}'),
('infra_trans_via_navegavel', 'valor_tipo_infra_trans_via_navegavel', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3}'),
('infra_trans_via_navegavel', 'valor_tipo_infra_trans_via_navegavel', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2,3}'),
('inst_gestao_ambiental', 'valor_instalacao_gestao_ambiental', '{v1.1.2}', '1', '{1,2,3,4}'),
('inst_gestao_ambiental', 'valor_instalacao_gestao_ambiental', '{v1.1.2}', '2', '{1,2,3,4}'),
('inst_gestao_ambiental', 'valor_instalacao_gestao_ambiental', '{v2.0.1,v2.0.2}', '1', '{1.1,1.2,2.1,2.2,5,6}'),
('inst_gestao_ambiental', 'valor_instalacao_gestao_ambiental', '{v2.0.1,v2.0.2}', '2', '{1.1,1.2,2.1,2.2,5,6}'),
('inst_producao', 'valor_instalacao_producao', '{v1.1.2}', '1', '{1.1,1.2,1.3,1.4,2,3,4.1,4.2,4.4,5,6,7.1,7.2,7.3,8,9,10,11,12}'),
('inst_producao', 'valor_instalacao_producao', '{v1.1.2}', '2', '{1,4.1,4.2,4.4,5,6,7,8,11,12}'),
('inst_producao', 'valor_instalacao_producao', '{v2.0.1,v2.0.2}', '1', '{1.1,1.2,1.3,1.100,4.1,4.2,4.4,5,6,7.1,7.2,7.3,8,11,12,13.1,13.2,13.3,13.4,13.5,13.100}'),
('inst_producao', 'valor_instalacao_producao', '{v2.0.1,v2.0.2}', '2', '{1.1,1.2,1.3,1.100,4.1,4.2,4.4,5,6,7,8,11,12,13.1,13.2,13.3,13.4,13.5,13.100}'),
('lig_valor_tipo_circulacao_seg_via_rodov', 'valor_tipo_circulacao_id', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3,4}'),
('lig_valor_tipo_circulacao_seg_via_rodov', 'valor_tipo_circulacao_id', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2,3,4}'),
('lig_valor_tipo_equipamento_coletivo_equip_util_coletiva', 'valor_tipo_equipamento_coletivo_id', '{v1.1.2}', '1', '{1.1,1.2,1.3,1.4,1.5,2.1,2.2,2.3,3,4.1,4.2,5,6.1,6.2,7.1,7.2,7.3,7.4,8}'),
('lig_valor_tipo_equipamento_coletivo_equip_util_coletiva', 'valor_tipo_equipamento_coletivo_id', '{v1.1.2}', '2', '{1.1,1.2,1.3,1.4,1.5,2.1,2.2,2.3,3,4.1,4.2,5,6.1,6.2,7.1,7.2,7.3,7.4,8}'),
('lig_valor_tipo_equipamento_coletivo_equip_util_coletiva', 'valor_tipo_equipamento_coletivo_id', '{v2.0.1,v2.0.2}', '1', '{1.1,1.2,1.3,1.4,1.5,2.1,2.2,2.100,3,4.1,4.2,5,6.1,6.2,7.1,7.2,7.3,7.4,7.5,8,9}'),
('lig_valor_tipo_equipamento_coletivo_equip_util_coletiva', 'valor_tipo_equipamento_coletivo_id', '{v2.0.1,v2.0.2}', '2', '{1.1,1.2,1.3,1.4,1.5,2.1,2.2,2.100,3,4.1,4.2,5,6.1,6.2,7.1,7.2,7.3,7.4,7.5,8,9}'),
('lig_valor_tipo_servico_infra_trans_rodov', 'valor_tipo_servico_id', '{v1.1.2}', '1', '{1,2,3,4,5,6,995}'),
('lig_valor_tipo_servico_infra_trans_rodov', 'valor_tipo_servico_id', '{v1.1.2}', '2', '{1,2,3,4,5,6,995}'),
('lig_valor_tipo_servico_infra_trans_rodov', 'valor_tipo_servico_id', '{v2.0.1,v2.0.2}', '1', '{1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,995}'),
('lig_valor_tipo_servico_infra_trans_rodov', 'valor_tipo_servico_id', '{v2.0.1,v2.0.2}', '2', '{1,2,3,4,5,6,995}'),
('lig_valor_utilizacao_atual_edificio', 'valor_utilizacao_atual_id', '{v1.1.2}', '1', '{1.1,1.2,2.1,2.2,2.3,3,4.1,4.2,4.3,4.4,5.1,5.2,5.3,6.1.1,6.1.2,6.2.1,6.2.2,6.3.1,6.3.2,6.4.1,6.4.2,6.4.3,6.5,6.6,7.1,7.2,7.3,8.1,8.2,8.3,8.4,9}'),
('lig_valor_utilizacao_atual_edificio', 'valor_utilizacao_atual_id', '{v1.1.2}', '2', '{1.1,1.2,2,3,4,5,6.1.1,6.1.2,6.2.1,6.2.2,6.3.1,6.3.2,6.4.2,6.4.3,6.5,6.6,7.1,7.2,7.3,8.1,8.2,8.3,8.4,9}'),
('lig_valor_utilizacao_atual_edificio', 'valor_utilizacao_atual_id', '{v2.0.1,v2.0.2}', '1', '{1.1,1.2,2.1,2.2,2.3,3,4.1,4.2,4.3,4.4,4.5,5.1,5.2,5.3,6.1.1,6.1.2,6.2.1,6.2.2,6.3.1,6.3.2,6.4.1,6.4.2,6.4.3,6.5,6.6,7.1,7.2,7.3,8.1,8.2,8.3,8.4,9}'),
('lig_valor_utilizacao_atual_edificio', 'valor_utilizacao_atual_id', '{v2.0.1,v2.0.2}', '2', '{1.1,1.2,2,3,4,5,6.1.1,6.1.2,6.2.1,6.2.2,6.3.1,6.3.2,6.4.2,6.4.3,6.5,6.6,7.1,7.2,7.3,8.1,8.2,8.3,8.4,9}'),
('linha_de_quebra', 'valor_classifica', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,6}'),
('linha_de_quebra', 'valor_classifica', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,6}'),
('linha_de_quebra', 'valor_natureza_linha', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3,4}'),
('linha_de_quebra', 'valor_natureza_linha', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2,3,4}'),
('margem', 'valor_tipo_margem', '{v1.1.2}', '1', '{5,6,8,995}'),
('margem', 'valor_tipo_margem', '{v1.1.2}', '2', '{5,6,8,995}'),
('mob_urbano_sinal', 'valor_tipo_de_mob_urbano_sinal', '{v1.1.2}', '1', '{5,11,17}'),
('mob_urbano_sinal', 'valor_tipo_de_mob_urbano_sinal', '{v1.1.2}', '2', '{5,11,17}'),
('no_hidrografico', 'valor_tipo_no_hidrografico', '{v1.1.2}', '1', '{1,2,3,4,5,6}'),
('no_hidrografico', 'valor_tipo_no_hidrografico', '{v1.1.2}', '2', '{1,2,3,4,5,6}'),
('no_hidrografico', 'valor_tipo_no_hidrografico', '{v2.0.1,v2.0.2}', '1', '{1,2,3,4,5,6,7,8}'),
('no_hidrografico', 'valor_tipo_no_hidrografico', '{v2.0.1,v2.0.2}', '2', '{1,2,3,4,5,6,7,8}'),
('no_trans_ferrov', 'valor_tipo_no_trans_ferrov', '{v1.1.2}', '1', '{1,2,3,4,5}'),
('no_trans_ferrov', 'valor_tipo_no_trans_ferrov', '{v1.1.2}', '2', '{1,2,3,4,5}'),
('no_trans_ferrov', 'valor_tipo_no_trans_ferrov', '{v2.0.1,v2.0.2}', '1', '{1,2,3,4,5,6,7}'),
('no_trans_ferrov', 'valor_tipo_no_trans_ferrov', '{v2.0.1,v2.0.2}', '2', '{1,2,3,4,5,6,7}'),
('no_trans_rodov', 'valor_tipo_no_trans_rodov', '{v1.1.2}', '1', '{1,2,3,4,5}'),
('no_trans_rodov', 'valor_tipo_no_trans_rodov', '{v1.1.2}', '2', '{1,2,3,4,5}'),
('no_trans_rodov', 'valor_tipo_no_trans_rodov', '{v2.0.1,v2.0.2}', '1', '{1,2,3,4,5,6,7}'),
('no_trans_rodov', 'valor_tipo_no_trans_rodov', '{v2.0.1,v2.0.2}', '2', '{1,2,3,4,5,6,7}'),
('obra_arte', 'valor_tipo_obra_arte', '{v1.1.2}', '1', '{1,2,3,4,5,6,7}'),
('obra_arte', 'valor_tipo_obra_arte', '{v1.1.2}', '2', '{1,2,3,4,5,6,7}'),
('obra_arte', 'valor_tipo_obra_arte', '{v2.0.1,v2.0.2}', '1', '{1,2,3,4,5,6,7,9}'),
('obra_arte', 'valor_tipo_obra_arte', '{v2.0.1,v2.0.2}', '2', '{1,2,3,4,5,6,7,9}'),
('oleoduto_gasoduto_subtancias_quimicas', 'valor_gasoduto_oleoduto_sub_quimicas', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3}'),
('oleoduto_gasoduto_subtancias_quimicas', 'valor_gasoduto_oleoduto_sub_quimicas', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2,3}'),
('oleoduto_gasoduto_subtancias_quimicas', 'valor_posicao_vertical', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,0,-1}'),
('oleoduto_gasoduto_subtancias_quimicas', 'valor_posicao_vertical', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,0,-1}'),
('ponto_cotado', 'valor_classifica_las', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1}'),
('ponto_cotado', 'valor_classifica_las', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1}'),
('ponto_interesse', 'valor_tipo_ponto_interesse', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3,4,5,6,7,8,9,10,11,12,13}'),
('ponto_interesse', 'valor_tipo_ponto_interesse', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{2,4,5,6,7,8,9,10,11,12,13}'),
('seg_via_ferrea', 'valor_categoria_bitola', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3,995}'),
('seg_via_ferrea', 'valor_categoria_bitola', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2,3,995}'),
('seg_via_ferrea', 'valor_estado_linha_ferrea', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3,5}'),
('seg_via_ferrea', 'valor_estado_linha_ferrea', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2,3,5}'),
('seg_via_ferrea', 'valor_posicao_vertical_transportes', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{3,2,1,0,-1,-2,-3}'),
('seg_via_ferrea', 'valor_posicao_vertical_transportes', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{3,2,1,0,-1,-2,-3}'),
('seg_via_ferrea', 'valor_tipo_linha_ferrea', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3,4,5,6,7,8}'),
('seg_via_ferrea', 'valor_tipo_linha_ferrea', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2,3,4,5,6,7,8}'),
('seg_via_ferrea', 'valor_tipo_troco_via_ferrea', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3}'),
('seg_via_ferrea', 'valor_tipo_troco_via_ferrea', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2,3}'),
('seg_via_rodov', 'valor_caract_fisica_rodov', '{v1.1.2}', '1', '{1,2,3,4,5,6}'),
('seg_via_rodov', 'valor_caract_fisica_rodov', '{v1.1.2}', '2', '{1,2,3,4,5,6}'),
('seg_via_rodov', 'valor_caract_fisica_rodov', '{v2.0.1,v2.0.2}', '1', '{1,2,3,4,5,6,7}'),
('seg_via_rodov', 'valor_caract_fisica_rodov', '{v2.0.1,v2.0.2}', '2', '{1,2,3,4,5,6,7}'),
('seg_via_rodov', 'valor_estado_via_rodov', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3,5}'),
('seg_via_rodov', 'valor_estado_via_rodov', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2,3,5}'),
('seg_via_rodov', 'valor_posicao_vertical_transportes', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{3,2,1,0,-1,-2,-3}'),
('seg_via_rodov', 'valor_posicao_vertical_transportes', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{3,2,1,0,-1,-2,-3}'),
('seg_via_rodov', 'valor_sentido', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3}'),
('seg_via_rodov', 'valor_sentido', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2,3}'),
('seg_via_rodov', 'valor_tipo_troco_rodoviario', '{v1.1.2}', '1', '{1,2,3,4,5,6,7}'),
('seg_via_rodov', 'valor_tipo_troco_rodoviario', '{v1.1.2}', '2', '{1,2,3,4,5,6,7}'),
('seg_via_rodov', 'valor_tipo_troco_rodoviario', '{v2.0.1,v2.0.2}', '1', '{1,2,3,4,5,6,7,8}'),
('seg_via_rodov', 'valor_tipo_troco_rodoviario', '{v2.0.1,v2.0.2}', '2', '{1,2,3,4,5,6,7,8}'),
('sinal_geodesico', 'valor_local_geodesico', '{v1.1.2}', '1', '{1,2,3,4,5,6,7,8,9,10,11,995}'),
('sinal_geodesico', 'valor_local_geodesico', '{v1.1.2}', '2', '{1,2,3,4,5,6,7,8,9,10,11,995}'),
('sinal_geodesico', 'valor_ordem', '{v1.1.2}', '1', '{1,2,995}'),
('sinal_geodesico', 'valor_ordem', '{v1.1.2}', '2', '{1,2,995}'),
('sinal_geodesico', 'valor_categoria', '{v2.0.1,v2.0.2}', '1', '{1,2,995}'),
('sinal_geodesico', 'valor_categoria', '{v2.0.1,v2.0.2}', '2', '{1,2,995}'),
('sinal_geodesico', 'valor_tipo_sinal_geodesico', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3,4,5}'),
('sinal_geodesico', 'valor_tipo_sinal_geodesico', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2,3,4,5}'),
('terreno_marginal', 'valor_tipo_terreno_marginal', '{v2.0.1,v2.0.2}', '1', '{1,2,3,4,5,6,7,8}'),
('terreno_marginal', 'valor_tipo_terreno_marginal', '{v2.0.1,v2.0.2}', '2', '{1,2,3,4,5,6,7,8}'),
('via_rodov_limite', 'valor_tipo_limite', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2}'),
('via_rodov_limite', 'valor_tipo_limite', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2}'),
('zona_humida', 'valor_zona_humida', '{v1.1.2,v2.0.1,v2.0.2}', '1', '{1,2,3}'),
('zona_humida', 'valor_zona_humida', '{v1.1.2,v2.0.1,v2.0.2}', '2', '{1,2,3}');


CREATE TABLE IF NOT EXISTS validation.consistencia_valores_report (
	tabela text NULL,
	atributo text NULL,
	valor text NULL,
	numero integer NULL
);

create or replace function validation.atualiza_consistencia_valores_report(_ndd text, _versao text) returns void language plpgsql as $$
declare
	tbl text;
	attr text;
	vals text[];

	tables cursor for
		select entidade, atributo, valores from validation.consistencia_valores_def
		where ndd = _ndd and versao::text like '%' || _versao || '%';
begin
	delete from validation.consistencia_valores_report;

	open tables;
	loop
		fetch tables into tbl, attr, vals;
		exit when not found;

		EXECUTE format('
			insert into validation.consistencia_valores_report (tabela, atributo, valor, numero)
			select ''%1$s'' as tabela, ''%2$s'' as atributo, %2$I as valor, count(*) as numero
				from {schema}.%1$I where %2$s<>all(''%3$s'')
				group by %2$s
		', tbl, attr, vals);
	end loop;
	close tables;
end; $$;


CREATE TABLE IF NOT EXISTS validation.geometrias_invalidas_report (
    tabela       text NOT NULL,
    identificador uuid NOT NULL,
    motivo       text NULL,
    geometria    geometry(Geometry, 3763) NULL,
    CONSTRAINT geometrias_invalidas_report_pkey PRIMARY KEY (tabela, identificador)
);

CREATE INDEX IF NOT EXISTS geometrias_invalidas_report_geom_idx
    ON validation.geometrias_invalidas_report USING GIST (geometria);


CREATE OR REPLACE FUNCTION validation.check_geometries_extensions()
RETURNS INTEGER AS $$
DECLARE
    tbl TEXT;
    uuid_ossp_available BOOLEAN;
    postgis_raster_available BOOLEAN;
    invalid_found BOOLEAN := FALSE;
    row_invalid_count BIGINT;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM pg_extension WHERE extname = 'uuid-ossp'
    ) INTO uuid_ossp_available;
    
    IF NOT uuid_ossp_available THEN
        RAISE WARNING 'Extension uuid-ossp is not installed.';
        RETURN 1;
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM pg_extension WHERE extname = 'postgis_raster'
    ) INTO postgis_raster_available;
    
    IF NOT postgis_raster_available THEN
        RAISE WARNING 'Extension postgis_raster is not installed.';
        RETURN 3;
    END IF;

	DELETE FROM validation.geometrias_invalidas_report;

    FOR tbl IN 
        SELECT c.table_name::TEXT
        FROM information_schema.columns c
        JOIN information_schema.tables t 
            ON c.table_schema = t.table_schema 
            AND c.table_name = t.table_name
        WHERE c.table_schema = '{schema}'
            AND c.column_name = 'geometria'
            AND t.table_type = 'BASE TABLE'
    LOOP
        EXECUTE format(
            'INSERT INTO validation.geometrias_invalidas_report (tabela, identificador, motivo, geometria)
			SELECT %L, identificador, ST_IsValidReason(geometria), geometria
			FROM %I
			WHERE geometria IS NOT NULL AND NOT ST_IsValid(geometria)',
			tbl, tbl
        );
        
        GET DIAGNOSTICS row_invalid_count = ROW_COUNT;
		IF row_invalid_count > 0 THEN
			invalid_found := TRUE;
		END IF;
    END LOOP;

    IF invalid_found THEN
        RETURN 2;
    END IF;

    RETURN 0;
END;
$$ LANGUAGE plpgsql;


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

CREATE TABLE IF NOT EXISTS validation.comissao (
	entidade text NULL,
	entidade_total integer NULL,
	entidade_duplicados integer NULL,
	geom text NULL,
	ids text NULL,
	geometria geometry(GEOMETRYZ, 3763) NULL
);

CREATE TABLE IF NOT EXISTS validation.conformidade (
	identificador uuid NULL,
	entidade text NULL,
	atributo text NULL,
	geometria geometry(linestringz, 3763) NULL
);

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

CREATE SCHEMA IF NOT EXISTS errors;

CREATE TABLE IF NOT EXISTS errors.erros_3d (
	identificador uuid NULL,
	entidade text NULL,
	indice integer NULL,
	motivo text NULL,
	rule_code varchar NULL,
	geometria geometry(pointz, 3763) NULL
);

ALTER TABLE errors.erros_3d ADD COLUMN IF NOT EXISTS rule_code varchar;

ALTER TABLE errors.erros_3d DROP CONSTRAINT IF EXISTS erros_3d_pk;
ALTER TABLE errors.erros_3d ADD CONSTRAINT erros_3d_pk PRIMARY KEY (identificador, entidade, motivo, geometria);

UPDATE errors.erros_3d SET rule_code = 're3_1_1'
WHERE rule_code IS NULL AND entidade = 'curva_de_nivel' AND motivo = 'Ponto fora da linha da área de trabalho';
UPDATE errors.erros_3d SET rule_code = 're3_1_2'
WHERE rule_code IS NULL AND entidade = 'curva_de_nivel' AND motivo LIKE 'discrepância no valor de z:%';
UPDATE errors.erros_3d SET rule_code = 're4_5_2'
WHERE rule_code IS NULL AND entidade = 'curso_de_agua_eixo' AND motivo = 'ponto de inflexão';

create or replace function validation.sort_asc(p_input double precision[]) 
  returns double precision[]
as
$$
  select array_agg(i order by i asc)
  from unnest(p_input) as a(i);
$$
language sql
immutable;

create or replace function validation.sort_desc(p_input double precision[]) 
  returns double precision[]
as
$$
  select array_agg(i order by i desc)
  from unnest(p_input) as a(i);
$$
language sql
immutable;

CREATE OR REPLACE FUNCTION validation.create_missing_gist_indexes()
RETURNS INTEGER AS $$
DECLARE
    rec record;
BEGIN
    FOR rec IN 
	    with tabelas as (SELECT table_name::regclass, table_name as nome, column_name, data_type, udt_name
		FROM information_schema.columns 
		WHERE table_schema = 'public' and udt_name = 'geometry'
		order by table_name, ordinal_position),
		todos as (
		SELECT i.relname as indname,
		       i.relowner as indowner,
		       idx.indrelid::regclass as table_name,
		       am.amname as tipo_indice,
		       idx.indkey,
		       ARRAY(
		       SELECT pg_get_indexdef(idx.indexrelid, k + 1, true)
		       FROM generate_subscripts(idx.indkey, 1) as k
		       ORDER BY k
		       ) as indkey_names,
		       idx.indexprs IS NOT NULL as indexprs,
		       idx.indpred IS NOT NULL as indpred
		FROM   pg_index as idx
		JOIN   pg_class as i
		ON     i.oid = idx.indexrelid
		JOIN   pg_am as am
		ON     i.relam = am.oid
		JOIN   pg_namespace as ns
		ON     ns.oid = i.relnamespace
		AND    ns.nspname = ANY(current_schemas(false)))
		select tabelas.nome, tabelas.column_name, todos.indname, todos.tipo_indice
		from tabelas
		left join todos
		on tabelas.table_name = todos.table_name and todos.tipo_indice = 'gist'
		order by tabelas.nome
    LOOP
		IF rec.indname IS NULL and rec.nome <> 'raster_columns' THEN
			RAISE NOTICE 'NÃO EXISTE para a Tabela % Índice % Tipo %', rec.nome, rec.indname, rec.tipo_indice;
			RAISE NOTICE 'CREATE INDEX ON %.% USING GIST (%)', 'public', rec.nome, rec.column_name;
			EXECUTE format( 'CREATE INDEX ON %I.%I USING GIST (%I)', 'public', rec.nome, rec.column_name );
		ELSE
			RAISE NOTICE 'Já existe para a Tabela % Índice % Tipo %', rec.nome, rec.indname, rec.tipo_indice;
		END IF;
    END LOOP;
	RETURN 0;
END;
$$
LANGUAGE plpgsql;
