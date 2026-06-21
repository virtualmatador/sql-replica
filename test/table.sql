
set @old_db = null;
select `SCHEMA_NAME` into @old_db from `INFORMATION_SCHEMA`.`SCHEMATA`
where `SCHEMA_NAME` = 'demo';
set @qry = if (isnull(@old_db),
    'CREATE DATABASE `demo`;'
,
    'SET @r = \'Database "demo" exists.\';'
);

set @all_tables = '';
set @all_views = '';

set @all_tables = concat(@all_tables, '{ACCOUNT_TABLE}');
set @old_table = null;
select `TABLE_NAME` into @old_table
    from `INFORMATION_SCHEMA`.`TABLES`
    where `TABLE_COMMENT` = 'ACCOUNT_TABLE' and
        `TABLE_SCHEMA` = 'demo';
set @qry = if (isnull(@old_table),
    'CREATE TABLE `demo`.`_sql_account` (`_sql_` int UNSIGNED NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT \'ACCOUNT_TABLE\';'
,
    'SET @r = \'Table "account" exist.\';'
);

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

set @ren_tables_prefix = '';
set @ren_tables_final = '';

set @old_table = null;
select `TABLE_NAME` into @old_table
    from `INFORMATION_SCHEMA`.`TABLES`
    where `TABLE_COMMENT` = 'ACCOUNT_TABLE' and
        `TABLE_SCHEMA` = 'demo';
set @ren_tables_prefix = if (@old_table != 'account' && instr(@old_table, '_sql_') != 1,
    concat(@ren_tables_prefix, '`demo`.`', @old_table, '` to `demo`.`_sql_account`, ')
,
    @ren_tables_prefix
);
set @ren_tables_final = if (@old_table != 'account',
    concat(@ren_tables_final, '`demo`.`_sql_account` to `demo`.`account`, ')
,
    @ren_tables_final
);

set @qry = if (@ren_tables_final != '',
    if (@ren_tables_prefix != '', concat ('RENAME TABLE ',
        substr(@ren_tables_prefix, 1, length(@ren_tables_prefix) - 2), ';')
    ,
        'SET @r = \'All tables have prefix.\';'
    ),
    'SET @r = \'No table needs prefix.\';'
);

set @qry = if (@ren_tables_final != '', concat ('RENAME TABLE ',
    substr(@ren_tables_final, 1, length(@ren_tables_final) - 2), ';')
,
    'SET @r = \'No table rename needed.\';');

set @old_engine = null;
select `ENGINE` into @old_engine
    from `INFORMATION_SCHEMA`.`TABLES`
    where `TABLE_NAME` = 'account' and
        `TABLE_SCHEMA` = 'demo';
set @qry = if (@old_engine != 'InnoDB',
    'ALTER TABLE `demo`.`account` ENGINE=InnoDB;'
,
    'SET @r = \'Engine of "account" is ok.\';'
);

set @all_columns = '';
set @sub_query = '';

set @all_columns = concat(@all_columns, '{ACCOUNT_ID}');
set @old_column = null;
select `COLUMN_NAME` into @old_column
    from `INFORMATION_SCHEMA`.`COLUMNS`
    where `COLUMN_COMMENT` = 'ACCOUNT_ID' and
        `COLUMNS`.`TABLE_NAME` = 'account' and
        `COLUMNS`.`TABLE_SCHEMA` = 'demo';
set @sub_query = if (isnull(@old_column),
    concat(@sub_query, 'ADD `_sql_id` int unsigned COMMENT \'ACCOUNT_ID\', ')
,
    @sub_query
);

set @qry = if (@sub_query != '',
    concat('ALTER TABLE `demo`.`account` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
    'SET @r = \'No new column in "account" is needed.\';'
);

set @sub_query = null;
select group_concat(concat('RENAME COLUMN `', `COLUMN_NAME`, '` to `_sql__drop_', `COLUMN_NAME`, '`') SEPARATOR ', ')
    into @sub_query
    from `INFORMATION_SCHEMA`.`COLUMNS`
    where `COLUMN_NAME` not like '_sql__drop_%' and `TABLE_SCHEMA` = 'demo' and `TABLE_NAME` = 'account' and
        instr(@all_columns, concat('{', `COLUMN_COMMENT`, '}')) = 0;
set @qry = if (isnull(@sub_query),
    'SET @r = \'No extra column in "account".\';'
,
    concat('ALTER TABLE `demo`.`account` ', @sub_query, ';')
);

set @ren_columns_prefix = '';
set @ren_columns_final = '';

set @old_column = null;
select `COLUMN_NAME` into @old_column
    from `INFORMATION_SCHEMA`.`COLUMNS`
    where `COLUMN_COMMENT` = 'ACCOUNT_ID' and
        `COLUMNS`.`TABLE_NAME` = 'account' and
        `COLUMNS`.`TABLE_SCHEMA` = 'demo';
set @ren_columns_prefix = if (@old_column != 'id' && instr(@old_column, '_sql_') != 1,
    concat(@ren_columns_prefix, 'RENAME COLUMN `', @old_column, '` to `_sql_id`, ')
,
    @ren_columns_prefix
);
set @ren_columns_final = if (@old_column != 'id',
    concat(@ren_columns_final, 'RENAME COLUMN `_sql_id` to `id`, ')
,
    @ren_columns_final
);

set @qry = if (@ren_columns_final != '',
    if (@ren_columns_prefix != '',
        concat ('ALTER TABLE `demo`.`account` ', substr(@ren_columns_prefix, 1,
        length(@ren_columns_prefix) - 2), ';')
    ,
        'SET @r = \'All columns in "account" have prefix.\';'
    ),
    'SET @r = \'No column in "account" needs prefix.\';'
);

set @qry = if (@ren_columns_final != '', concat ('ALTER TABLE `demo`.`account` ',
    substr(@ren_columns_final, 1, length(@ren_columns_final) - 2), ';')
,
    'SET @r = \'No column in "account" needs rename.\';');

set @all_foreign_keys = '';

set @sub_query = null;
select group_concat(distinct
    concat('DROP FOREIGN KEY `', `CONSTRAINT_NAME`, '`') SEPARATOR ', ')
into @sub_query
from `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`
where
    `REFERENCED_TABLE_NAME` is not null and
    `TABLE_SCHEMA` = 'demo' and
    `TABLE_NAME` = 'account' and
    instr(@all_foreign_keys, concat('{', `CONSTRAINT_NAME`, '}')) = 0;
set @qry = if (isnull(@sub_query),
    'SET @r = \'No extra foreign keys in "account".\';'
,
    concat('ALTER TABLE `demo`.`account` ', @sub_query, ';')
);

set @sub_query = '';
set @ordinal_change = false;

set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `COLUMN_TYPE`, `COLUMN_DEFAULT`, `IS_NULLABLE`,
    `EXTRA` like '%auto_increment%' as AUTO, `ORDINAL_POSITION`
    into @old_type, @old_default, @old_null, @old_auto, @old_position
    from `INFORMATION_SCHEMA`.`COLUMNS`
    where `COLUMN_NAME` = 'id' and
        `COLUMNS`.`TABLE_NAME` = 'account' and
        `COLUMNS`.`TABLE_SCHEMA` = 'demo';
set @ordinal_change = if (@old_position != 1, true, @ordinal_change);
set @sub_query = if (@ordinal_change or
    @old_type != 'int unsigned' or
    @old_null != 'NO' or
    @old_auto != true,
    concat(@sub_query, 'MODIFY `id` int unsigned not null auto_increment COMMENT \'ACCOUNT_ID\' FIRST, ')
,
    @sub_query
);

set @all_keys = '';

set @drop_query = null;
select group_concat(distinct
    concat('DROP INDEX `', `INDEX_NAME`, '`') SEPARATOR ', ')
into @drop_query
from `INFORMATION_SCHEMA`.`STATISTICS`
join `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`
on
    `INFORMATION_SCHEMA`.`STATISTICS`.`INDEX_SCHEMA` =
    `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`.`CONSTRAINT_SCHEMA` and
    `INFORMATION_SCHEMA`.`STATISTICS`.`TABLE_NAME` =
    `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`.`TABLE_NAME` and
    `INFORMATION_SCHEMA`.`STATISTICS`.`INDEX_NAME` =
    `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`.`CONSTRAINT_NAME`
where
    `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`.`REFERENCED_TABLE_NAME` is null and
    `INFORMATION_SCHEMA`.`STATISTICS`.`INDEX_SCHEMA` = 'demo' and
    `INFORMATION_SCHEMA`.`STATISTICS`.`TABLE_NAME` = 'account' and
    instr(@all_keys, concat('{', `INDEX_NAME`, '}')) = 0;
set @sub_query = if (isnull(@drop_query), @sub_query,
    concat(@sub_query, @drop_query, ', ')
);

set @drop_query = null;
select group_concat(concat('DROP COLUMN `', `COLUMN_NAME`, '`')
    SEPARATOR ', ') into @drop_query
    from `INFORMATION_SCHEMA`.`COLUMNS`
    where
        `COLUMNS`.`TABLE_NAME` = 'account' and
        `COLUMNS`.`TABLE_SCHEMA` = 'demo' and
        `COLUMN_NAME` like '_sql__drop_%';
set @sub_query = if (isnull(@drop_query), @sub_query,
    concat(@sub_query, @drop_query, ', ')
);

set @qry = if (@sub_query != '',
    concat ('ALTER TABLE `demo`.`account` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
    'SET @r = \'Table "account" is ok.\';'
);

set @sub_query = '';

set @old_default = null;
select `COLUMN_DEFAULT`
    into @old_default
    from `INFORMATION_SCHEMA`.`COLUMNS`
    where `COLUMN_NAME` = 'id' and
        `COLUMNS`.`TABLE_NAME` = 'account' and
        `COLUMNS`.`TABLE_SCHEMA` = 'demo';
set @sub_query = if (@old_default IS NOT NULL,
    concat(@sub_query, 'ALTER COLUMN `id` DROP DEFAULT, ')
,
    @sub_query
);

set @qry = if (@sub_query != '',
    concat ('ALTER TABLE `demo`.`account` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
    'SET @r = \'Table "account" is ok.\';'
);

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
