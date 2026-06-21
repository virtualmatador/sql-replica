
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

set @all_procedures = concat(@all_procedures, '{set_value}');

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

set @procedure_delimiter = concat('d', left(replace(uuid(), '-', ''), 13));

set @old_body = null;
set @old_data_access = null;
set @old_deterministic = null;
set @old_security = null;
set @old_params = null;
select `ROUTINE_DEFINITION`, `SQL_DATA_ACCESS`, `IS_DETERMINISTIC`,
        `SECURITY_TYPE`
    into @old_body, @old_data_access, @old_deterministic, @old_security
    from `INFORMATION_SCHEMA`.`ROUTINES`
    where `ROUTINE_SCHEMA` = 'demo' and
        `ROUTINE_TYPE` = 'PROCEDURE' and
        `ROUTINE_NAME` = 'set_value';
set @old_body = trim(@old_body);
set @old_body = if (
    upper(left(@old_body, 5)) = 'BEGIN' and upper(right(@old_body, 3)) = 'END',
    trim(substr(@old_body, 6, length(@old_body) - 8)),
    @old_body
);
select group_concat(concat(`PARAMETER_MODE`, ' `', `PARAMETER_NAME`, '` ',
        `DTD_IDENTIFIER`) ORDER BY `ORDINAL_POSITION` SEPARATOR ', ')
    into @old_params
    from `INFORMATION_SCHEMA`.`PARAMETERS`
    where `SPECIFIC_SCHEMA` = 'demo' and
        `ROUTINE_TYPE` = 'PROCEDURE' and
        `SPECIFIC_NAME` = 'set_value' and
        `PARAMETER_NAME` is not null;
set @procedure_changed =
    isnull(@old_body) or
    @old_body != 'SET output_value = input_value;' or
    ifnull(@old_data_access, '') != 'MODIFIES SQL DATA' or
    ifnull(@old_security, '') != 'INVOKER' or

    ifnull(@old_params, '') != 'IN `input_value` int, OUT `output_value` int';
set @qry = if (@procedure_changed,
    'DROP PROCEDURE IF EXISTS `demo`.`set_value`;'
,
    'SET @r = \'Procedure set_value is ok.\';'
);

select @qry as '';

set @qry = if (@procedure_changed,
    concat('DELIMITER ', @procedure_delimiter, '\n', 'CREATE PROCEDURE `demo`.`set_value`(IN `input_value` int, OUT `output_value` int) MODIFIES SQL DATA SQL SECURITY INVOKER BEGIN SET output_value = input_value; END ', @procedure_delimiter, '\n', 'DELIMITER ;')
,
    'SET @r = \'Procedure set_value is ok.\';'
);

select @qry as '';

