
set @old_db = null;
select `SCHEMA_NAME` into @old_db from `INFORMATION_SCHEMA`.`SCHEMATA`
where `SCHEMA_NAME` = 'demo';
set @qry = if (isnull(@old_db),
    'CREATE DATABASE `demo`;'
,
    'SET @r = \'Database "demo" exists.\';'
);

select @qry as '';

prepare stmt from @qry;
execute stmt;
deallocate prepare stmt;

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

prepare stmt from @qry;
execute stmt;
deallocate prepare stmt;

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

prepare stmt from @qry;
execute stmt;
deallocate prepare stmt;

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

prepare stmt from @qry;
execute stmt;
deallocate prepare stmt;

set @qry = if (@ren_tables_final != '', concat ('RENAME TABLE ',
    substr(@ren_tables_final, 1, length(@ren_tables_final) - 2), ';')
,
    'SET @r = \'No table rename needed.\';');

select @qry as '';

prepare stmt from @qry;
execute stmt;
deallocate prepare stmt;

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

prepare stmt from @qry;
execute stmt;
deallocate prepare stmt;

set @all_functions = '';

set @all_functions = concat(@all_functions, '{double_value}');

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

prepare stmt from @qry;
execute stmt;
deallocate prepare stmt;

set @function_delimiter = concat('d', left(replace(uuid(), '-', ''), 13));

set @old_body = null;
set @old_returns = null;
set @old_data_access = null;
set @old_deterministic = null;
set @old_security = null;
set @old_params = null;
select `ROUTINE_DEFINITION`, `DTD_IDENTIFIER`, `SQL_DATA_ACCESS`,
        `IS_DETERMINISTIC`, `SECURITY_TYPE`
    into @old_body, @old_returns, @old_data_access, @old_deterministic,
        @old_security
    from `INFORMATION_SCHEMA`.`ROUTINES`
    where `ROUTINE_SCHEMA` = 'demo' and
        `ROUTINE_TYPE` = 'FUNCTION' and
        `ROUTINE_NAME` = 'double_value';
set @old_body = trim(@old_body);
set @old_body = if (
    upper(left(@old_body, 5)) = 'BEGIN' and upper(right(@old_body, 3)) = 'END',
    trim(substr(@old_body, 6, length(@old_body) - 8)),
    @old_body
);
select group_concat(concat('`', `PARAMETER_NAME`, '` ', `DTD_IDENTIFIER`)
        ORDER BY `ORDINAL_POSITION` SEPARATOR ', ')
    into @old_params
    from `INFORMATION_SCHEMA`.`PARAMETERS`
    where `SPECIFIC_SCHEMA` = 'demo' and
        `ROUTINE_TYPE` = 'FUNCTION' and
        `SPECIFIC_NAME` = 'double_value' and
        `PARAMETER_NAME` is not null;
set @function_changed =
    isnull(@old_body) or
    @old_body != 'RETURN input_value * 2;' or
    ifnull(@old_returns, '') != 'int' or
    ifnull(@old_data_access, '') != 'READS SQL DATA' or
    ifnull(@old_deterministic, '') != 'YES' or

    ifnull(@old_params, '') != '`input_value` int';
set @qry = if (@function_changed,
    'DROP FUNCTION IF EXISTS `demo`.`double_value`;'
,
    'SET @r = \'Function Drop double_value is ok.\';'
);

select @qry as '';

prepare stmt from @qry;
execute stmt;
deallocate prepare stmt;

set @qry = if (@function_changed,
    concat('DELIMITER ', @function_delimiter, '\n', 'CREATE FUNCTION `demo`.`double_value`(`input_value` int) RETURNS int DETERMINISTIC READS SQL DATA BEGIN RETURN input_value * 2; END ', @function_delimiter, '\n', 'DELIMITER ;')
,
    'SET @r = \'Function Create double_value is ok.\';'
);

select @qry as '';

prepare stmt from @qry;
execute stmt;
deallocate prepare stmt;

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

prepare stmt from @qry;
execute stmt;
deallocate prepare stmt;

