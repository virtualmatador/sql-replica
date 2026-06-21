
set @old_db = null;
select `SCHEMA_NAME` into @old_db from `INFORMATION_SCHEMA`.`SCHEMATA`
where `SCHEMA_NAME` = 'demo';
set @qry = if (isnull(@old_db),
    'CREATE DATABASE `demo`;'
,
    'SET @r = \'Database "demo" exists.\';'
);

select @qry as '';

set @all_tables = '';
set @all_views = '';

set @sub_query = null;
select group_concat(concat('`demo`.`', `TABLE_NAME`, '`') SEPARATOR ', ')
    into @sub_query
    from `INFORMATION_SCHEMA`.`TABLES`
    where `TABLE_SCHEMA` = 'demo' and `TABLE_TYPE` = 'VIEW' and
        instr(@all_views, concat('{', `TABLE_NAME`, '}')) = 0;
set @qry = if (isnull(@sub_query),
    'SET @r = \'No extra view.\';'
,
    concat('DROP VIEW ', @sub_query, ';')
);

select @qry as '';

set @sub_query = null;
select group_concat(concat('`demo`.`', `TABLE_NAME`, '` to `demo`.`_sql__drop_', `TABLE_NAME`, '`') SEPARATOR ', ')
    into @sub_query
    from `INFORMATION_SCHEMA`.`TABLES`
    where `TABLE_NAME` not like '_sql__drop_%' and `TABLE_SCHEMA` = 'demo' and `TABLE_TYPE` = 'BASE TABLE' and
        instr(@all_tables, concat('{', `TABLE_COMMENT`, '}')) = 0;
set @qry = if (isnull(@sub_query),
    'SET @r = \'No extra table.\';'
,
    concat('RENAME TABLE ', @sub_query, ';')
);

select @qry as '';

set @ren_tables_prefix = '';
set @ren_tables_final = '';

set @qry = if (@ren_tables_final != '',
    if (@ren_tables_prefix != '', concat ('RENAME TABLE ',
        substr(@ren_tables_prefix, 1, length(@ren_tables_prefix) - 2), ';')
    ,
        'SET @r = \'All tables have prefix.\';'
    ),
    'SET @r = \'No table needs prefix.\';'
);

select @qry as '';

set @qry = if (@ren_tables_final != '', concat ('RENAME TABLE ',
    substr(@ren_tables_final, 1, length(@ren_tables_final) - 2), ';')
,
    'SET @r = \'No table rename needed.\';');

select @qry as '';

set @sub_query = null;
select group_concat(concat('`demo`.`', `TABLE_NAME`, '`')
    SEPARATOR ', ') into @sub_query
from `INFORMATION_SCHEMA`.`TABLES`
where
    `TABLE_SCHEMA` = 'demo' and
    `TABLE_NAME` like '_sql__drop_%';
set @qry = if (isnull(@sub_query), 'SET @r = \'No extra table.\';',
    concat('DROP TABLE ', @sub_query, ';')
);

select @qry as '';

set @all_functions = '';

set @sub_query = null;
select group_concat(concat('`demo`.`', `ROUTINE_NAME`, '`') SEPARATOR ', ')
    into @sub_query
    from `INFORMATION_SCHEMA`.`ROUTINES`
    where `ROUTINE_SCHEMA` = 'demo' and `ROUTINE_TYPE` = 'FUNCTION' and
        instr(@all_functions, concat('{', `ROUTINE_NAME`, '}')) = 0;
set @qry = if (isnull(@sub_query),
    'SET @r = \'No extra function.\';'
,
    concat('DROP FUNCTION ', @sub_query, ';')
);

select @qry as '';

set @all_procedures = '';

set @sub_query = null;
select group_concat(concat('`demo`.`', `ROUTINE_NAME`, '`') SEPARATOR ', ')
    into @sub_query
    from `INFORMATION_SCHEMA`.`ROUTINES`
    where `ROUTINE_SCHEMA` = 'demo' and `ROUTINE_TYPE` = 'PROCEDURE' and
        instr(@all_procedures, concat('{', `ROUTINE_NAME`, '}')) = 0;
set @qry = if (isnull(@sub_query),
    'SET @r = \'No extra procedure.\';'
,
    concat('DROP PROCEDURE ', @sub_query, ';')
);

select @qry as '';

