
set @old_db = null;
select `SCHEMA_NAME` into @old_db from `INFORMATION_SCHEMA`.`SCHEMATA`
where `SCHEMA_NAME` = 'sales';
set @qry = if (isnull(@old_db),
    'CREATE DATABASE `sales`;'
,
    'SET @r = \'Database "sales" exists.\';'
);
  
select @qry as '';

set @_sql_tables = if(isnull(@old_db), json_array(), (
select coalesce(json_arrayagg(json_object(
    'name', `name`,
    'comment', `comment`,
    'type', `type`,
    'engine', `engine`
)), json_array())
from (
    select
        `TABLE_NAME` as `name`,
        `TABLE_COMMENT` as `comment`,
        `TABLE_TYPE` as `type`,
        `ENGINE` as `engine`
    from `INFORMATION_SCHEMA`.`TABLES`
    where `TABLE_SCHEMA` = 'sales'
    order by `TABLE_TYPE`, `TABLE_NAME`
) as `_sql_ordered_tables`
));
set @_sql_columns = if(isnull(@old_db), json_array(), (
select coalesce(json_arrayagg(json_object(
    'table', `table`,
    'name', `name`,
    'comment', `comment`,
    'type', `type`,
    'default', `default_value`,
    'nullable', `nullable`,
    'auto', `auto`,
    'ordinal', `ordinal`
)), json_array())
from (
    select
        `TABLE_NAME` as `table`,
        `COLUMN_NAME` as `name`,
        `COLUMN_COMMENT` as `comment`,
        `COLUMN_TYPE` as `type`,
        `COLUMN_DEFAULT` as `default_value`,
        `IS_NULLABLE` as `nullable`,
        `EXTRA` like '%auto_increment%' as `auto`,
        `ORDINAL_POSITION` as `ordinal`
    from `INFORMATION_SCHEMA`.`COLUMNS`
    where `TABLE_SCHEMA` = 'sales'
    order by `TABLE_NAME`, `ORDINAL_POSITION`, `COLUMN_NAME`
) as `_sql_ordered_columns`
));
set @_sql_indexes = if(isnull(@old_db), json_array(), (
select coalesce(json_arrayagg(json_object(
    'table', `table`,
    'name', `name`,
    'key_def', `key_def`,
    'foreign_key', `foreign_key`
)), json_array())
from (
    select
        `s`.`TABLE_NAME` as `table`,
        `s`.`INDEX_NAME` as `name`,
        group_concat(concat('`', `s`.`COLUMN_NAME`, '`')
            order by `s`.`SEQ_IN_INDEX` separator ', ') as `key_def`,
        exists (
            select 1
            from `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE` as `kcu`
            where
                `kcu`.`CONSTRAINT_SCHEMA` = `s`.`INDEX_SCHEMA` and
                `kcu`.`TABLE_NAME` = `s`.`TABLE_NAME` and
                `kcu`.`CONSTRAINT_NAME` = `s`.`INDEX_NAME` and
                `kcu`.`REFERENCED_TABLE_NAME` is not null
        ) as `foreign_key`
    from `INFORMATION_SCHEMA`.`STATISTICS` as `s`
    where `s`.`INDEX_SCHEMA` = 'sales'
    group by `s`.`TABLE_NAME`, `s`.`INDEX_NAME`
    order by `s`.`TABLE_NAME`, `s`.`INDEX_NAME`
) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(isnull(@old_db), json_array(), (
select coalesce(json_arrayagg(json_object(
    'table', `table`,
    'name', `name`,
    'key_def', `key_def`,
    'referenced_table', `referenced_table`,
    'f_key_def', `f_key_def`,
    'update', `update_rule`,
    'delete', `delete_rule`
)), json_array())
from (
    select
        `fk`.`TABLE_NAME` as `table`,
        `fk`.`CONSTRAINT_NAME` as `name`,
        `fk`.`key_def`,
        `fk`.`REFERENCED_TABLE_NAME` as `referenced_table`,
        `fk`.`f_key_def`,
        `rk`.`UPDATE_RULE` as `update_rule`,
        `rk`.`DELETE_RULE` as `delete_rule`
    from `INFORMATION_SCHEMA`.`REFERENTIAL_CONSTRAINTS` as `rk`
    join (
        select
            `CONSTRAINT_NAME`,
            `CONSTRAINT_SCHEMA`,
            `TABLE_NAME`,
            group_concat(concat('`', `COLUMN_NAME`, '`')
                order by `ORDINAL_POSITION` separator ', ') as `key_def`,
            `REFERENCED_TABLE_NAME`,
            group_concat(concat('`', `REFERENCED_COLUMN_NAME`, '`')
                order by `POSITION_IN_UNIQUE_CONSTRAINT` separator ', ') as `f_key_def`
        from `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`
        where
            `REFERENCED_TABLE_NAME` is not null and
            `CONSTRAINT_SCHEMA` = 'sales'
        group by `CONSTRAINT_NAME`, `CONSTRAINT_SCHEMA`, `TABLE_NAME`,
            `REFERENCED_TABLE_NAME`
    ) as `fk`
    using (
        `CONSTRAINT_SCHEMA`,
        `CONSTRAINT_NAME`,
        `TABLE_NAME`,
        `REFERENCED_TABLE_NAME`)
    order by `fk`.`TABLE_NAME`, `fk`.`CONSTRAINT_NAME`
) as `_sql_ordered_foreign_keys`
));

set @_sql_views = if(isnull(@old_db), json_array(), (
select coalesce(json_arrayagg(json_object(
    'name', `name`
)), json_array())
from (
    select `TABLE_NAME` as `name`
    from `INFORMATION_SCHEMA`.`TABLES`
    where `TABLE_SCHEMA` = 'sales' and `TABLE_TYPE` = 'VIEW'
    order by `TABLE_NAME`
) as `_sql_ordered_views`
));

set @_sql_routines = if(isnull(@old_db), json_array(), (
select coalesce(json_arrayagg(json_object(
    'name', `name`,
    'type', `type`,
    'comment', `comment`
)), json_array())
from (
    select
        `r`.`ROUTINE_NAME` as `name`,
        `r`.`ROUTINE_TYPE` as `type`,
        `r`.`ROUTINE_COMMENT` as `comment`
    from `INFORMATION_SCHEMA`.`ROUTINES` as `r`
    where
        `r`.`ROUTINE_SCHEMA` = 'sales' and
        `r`.`ROUTINE_TYPE` in ('FUNCTION', 'PROCEDURE')
    order by `r`.`ROUTINE_TYPE`, `r`.`ROUTINE_NAME`
) as `_sql_ordered_routines`
));

set @_sql_users = (
select coalesce(json_arrayagg(json_object(
    'name', `name`
)), json_array())
from (
    select `USER` as `name`
    from `mysql`.`user`
    order by `USER`
) as `_sql_ordered_users`
);
set @_sql_permissions = (
select coalesce(json_arrayagg(json_object(
    'user', `user`,
    'type', `type`,
    'subject', `subject`,
    'operations', `operations`
)), json_array())
from (
    select
        `user`,
        'TABLE' as `type`,
        `table_name` as `subject`,
        `table_priv` as `operations`
    from `mysql`.`tables_priv`
    where `Db` = 'sales'
    union all
    select
        `user`,
        `routine_type` as `type`,
        `routine_name` as `subject`,
        `proc_priv` as `operations`
    from `mysql`.`procs_priv`
    where `Db` = 'sales'
    order by `user`, `type`, `subject`
) as `_sql_ordered_permissions`
);

set @all_tables = '';

set @all_tables = concat(@all_tables, '{93B099B08D144B40BCC918FA24831669}');
set @old_table = null;
select `name` into @old_table
  from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
  where `comment` = '93B099B08D144B40BCC918FA24831669' and `type` = 'BASE TABLE';
set @qry = if (isnull(@old_table),
  'CREATE TABLE `sales`.`_sql_user` (`_sql_` int UNSIGNED NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT \'93B099B08D144B40BCC918FA24831669\';'
,
  'SET @r = \'Table "user" exist.\';'
);

select @qry as '';

set @_sql_tables = if(isnull(@old_table),
  json_array_append(@_sql_tables, '$', json_object(
      'name', '_sql_user',
      'comment', '93B099B08D144B40BCC918FA24831669',
      'type', 'BASE TABLE',
      'engine', 'InnoDB'
  )),
  @_sql_tables
);
set @_sql_columns = if(isnull(@old_table),
  json_array_append(@_sql_columns, '$', json_object(
      'table', '_sql_user',
      'name', '_sql_',
      'comment', '',
      'type', 'int unsigned',
      'default', null,
      'nullable', 'NO',
      'auto', false,
      'ordinal', 1
  )),
  @_sql_columns
);

set @all_tables = concat(@all_tables, '{3D9C2B4ED6BA4AE39D3333FC5BBCC1FF}');
set @old_table = null;
select `name` into @old_table
  from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
  where `comment` = '3D9C2B4ED6BA4AE39D3333FC5BBCC1FF' and `type` = 'BASE TABLE';
set @qry = if (isnull(@old_table),
  'CREATE TABLE `sales`.`_sql_project` (`_sql_` int UNSIGNED NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT \'3D9C2B4ED6BA4AE39D3333FC5BBCC1FF\';'
,
  'SET @r = \'Table "project" exist.\';'
);

select @qry as '';

set @_sql_tables = if(isnull(@old_table),
  json_array_append(@_sql_tables, '$', json_object(
      'name', '_sql_project',
      'comment', '3D9C2B4ED6BA4AE39D3333FC5BBCC1FF',
      'type', 'BASE TABLE',
      'engine', 'InnoDB'
  )),
  @_sql_tables
);
set @_sql_columns = if(isnull(@old_table),
  json_array_append(@_sql_columns, '$', json_object(
      'table', '_sql_project',
      'name', '_sql_',
      'comment', '',
      'type', 'int unsigned',
      'default', null,
      'nullable', 'NO',
      'auto', false,
      'ordinal', 1
  )),
  @_sql_columns
);

set @all_tables = concat(@all_tables, '{FC94A0BB4E9B422ABC399BBF79E6AC43}');
set @old_table = null;
select `name` into @old_table
  from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
  where `comment` = 'FC94A0BB4E9B422ABC399BBF79E6AC43' and `type` = 'BASE TABLE';
set @qry = if (isnull(@old_table),
  'CREATE TABLE `sales`.`_sql_member` (`_sql_` int UNSIGNED NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT \'FC94A0BB4E9B422ABC399BBF79E6AC43\';'
,
  'SET @r = \'Table "member" exist.\';'
);

select @qry as '';

set @_sql_tables = if(isnull(@old_table),
  json_array_append(@_sql_tables, '$', json_object(
      'name', '_sql_member',
      'comment', 'FC94A0BB4E9B422ABC399BBF79E6AC43',
      'type', 'BASE TABLE',
      'engine', 'InnoDB'
  )),
  @_sql_tables
);
set @_sql_columns = if(isnull(@old_table),
  json_array_append(@_sql_columns, '$', json_object(
      'table', '_sql_member',
      'name', '_sql_',
      'comment', '',
      'type', 'int unsigned',
      'default', null,
      'nullable', 'NO',
      'auto', false,
      'ordinal', 1
  )),
  @_sql_columns
);

set @sub_query = null;
select group_concat(concat('`sales`.`', `name`, '` to `sales`.`_sql__drop_', `name`, '`') SEPARATOR ', ')
  into @sub_query
  from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
  where `name` not like '_sql__drop_%' and `type` = 'BASE TABLE' and
      instr(@all_tables, concat('{', `comment`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra table.\';'
,
  concat('RENAME TABLE ', @sub_query, ';')
);

select @qry as '';

set @_sql_columns = (
  select coalesce(json_arrayagg(json_object(
      'table',
          if(exists (
              select 1
              from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
              where `planned_tables`.`name` = `_sql_ordered_columns`.`table` and
                  `planned_tables`.`name` not like '_sql__drop_%' and `planned_tables`.`type` = 'BASE TABLE' and
                  instr(@all_tables, concat('{', `planned_tables`.`comment`, '}')) = 0
          ),
              concat('_sql__drop_', `table`),
              `table`
          ),
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'default', `default_value`,
      'nullable', `nullable`,
      'auto', `auto`,
      'ordinal', `ordinal`
  )), json_array())
  from (
      select *
      from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
      order by `table`, `ordinal`, `name`
  ) as `_sql_ordered_columns`
);
set @_sql_indexes = (
  select coalesce(json_arrayagg(json_object(
      'table',
          if(exists (
              select 1
              from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
              where `planned_tables`.`name` = `_sql_ordered_indexes`.`table` and
                  `planned_tables`.`name` not like '_sql__drop_%' and `planned_tables`.`type` = 'BASE TABLE' and
                  instr(@all_tables, concat('{', `planned_tables`.`comment`, '}')) = 0
          ),
              concat('_sql__drop_', `table`),
              `table`
          ),
      'name', `name`,
      'key_def', `key_def`,
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
);
set @_sql_foreign_keys = (
  select coalesce(json_arrayagg(json_object(
      'table',
          if(exists (
              select 1
              from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
              where `planned_tables`.`name` = `_sql_ordered_foreign_keys`.`table` and
                  `planned_tables`.`name` not like '_sql__drop_%' and `planned_tables`.`type` = 'BASE TABLE' and
                  instr(@all_tables, concat('{', `planned_tables`.`comment`, '}')) = 0
          ),
              concat('_sql__drop_', `table`),
              `table`
          ),
      'name', `name`,
      'key_def', `key_def`,
      'referenced_table',
          if(exists (
              select 1
              from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
              where `planned_tables`.`name` = `_sql_ordered_foreign_keys`.`referenced_table` and
                  `planned_tables`.`name` not like '_sql__drop_%' and `planned_tables`.`type` = 'BASE TABLE' and
                  instr(@all_tables, concat('{', `planned_tables`.`comment`, '}')) = 0
          ),
              concat('_sql__drop_', `referenced_table`),
              `referenced_table`
          ),
      'f_key_def', `f_key_def`,
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
);
set @_sql_tables = (
  select coalesce(json_arrayagg(json_object(
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'engine', `engine`
  )), json_array())
  from (
      select
          if(`name` not like '_sql__drop_%' and `type` = 'BASE TABLE' and
              instr(@all_tables, concat('{', `comment`, '}')) = 0,
              concat('_sql__drop_', `name`),
              `name`
          ) as `name`,
          `comment`,
          `type`,
          `engine`
      from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
      order by `type`, `name`
  ) as `_sql_ordered_tables`
);

set @ren_tables_prefix = '';
set @ren_tables_final = '';

set @old_table = null;
select `name` into @old_table
  from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
  where `comment` = '93B099B08D144B40BCC918FA24831669' and `type` = 'BASE TABLE';
set @ren_tables_prefix = if (@old_table != 'user' && instr(@old_table, '_sql_') != 1,
  concat(@ren_tables_prefix, '`sales`.`', @old_table, '` to `sales`.`_sql_user`, ')
,
  @ren_tables_prefix
);
set @ren_tables_final = if (@old_table != 'user',
  concat(@ren_tables_final, '`sales`.`_sql_user` to `sales`.`user`, ')
,
  @ren_tables_final
);

set @old_table = null;
select `name` into @old_table
  from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
  where `comment` = '3D9C2B4ED6BA4AE39D3333FC5BBCC1FF' and `type` = 'BASE TABLE';
set @ren_tables_prefix = if (@old_table != 'project' && instr(@old_table, '_sql_') != 1,
  concat(@ren_tables_prefix, '`sales`.`', @old_table, '` to `sales`.`_sql_project`, ')
,
  @ren_tables_prefix
);
set @ren_tables_final = if (@old_table != 'project',
  concat(@ren_tables_final, '`sales`.`_sql_project` to `sales`.`project`, ')
,
  @ren_tables_final
);

set @old_table = null;
select `name` into @old_table
  from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
  where `comment` = 'FC94A0BB4E9B422ABC399BBF79E6AC43' and `type` = 'BASE TABLE';
set @ren_tables_prefix = if (@old_table != 'member' && instr(@old_table, '_sql_') != 1,
  concat(@ren_tables_prefix, '`sales`.`', @old_table, '` to `sales`.`_sql_member`, ')
,
  @ren_tables_prefix
);
set @ren_tables_final = if (@old_table != 'member',
  concat(@ren_tables_final, '`sales`.`_sql_member` to `sales`.`member`, ')
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

select @qry as '';

set @old_table = null;
select `name` into @old_table
  from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
  where `comment` = '93B099B08D144B40BCC918FA24831669' and `type` = 'BASE TABLE';
set @new_table = if(@old_table != 'user' and instr(@old_table, '_sql_') != 1, '_sql_user', @old_table);
set @table_path = json_unquote(json_search(
  @_sql_tables, 'one', '93B099B08D144B40BCC918FA24831669', null, '$[*].comment'));
set @table_object = if(@table_path is null, null, replace(@table_path, '.comment', ''));
set @_sql_tables = if(@table_object is null or @new_table = @old_table,
  @_sql_tables,
  json_set(@_sql_tables, concat(@table_object, '.name'), @new_table)
);
set @_sql_columns = if(@new_table = @old_table, @_sql_columns, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'default', `default_value`,
      'nullable', `nullable`,
      'auto', `auto`,
      'ordinal', `ordinal`
  )), json_array())
  from (
      select *
      from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
      order by `table`, `ordinal`, `name`
  ) as `_sql_ordered_columns`
));
set @_sql_indexes = if(@new_table = @old_table, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'key_def', `key_def`,
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_table = @old_table, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'key_def', `key_def`,
      'referenced_table', if(`referenced_table` = @old_table, @new_table, `referenced_table`),
      'f_key_def', `f_key_def`,
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_table = null;
select `name` into @old_table
  from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
  where `comment` = '3D9C2B4ED6BA4AE39D3333FC5BBCC1FF' and `type` = 'BASE TABLE';
set @new_table = if(@old_table != 'project' and instr(@old_table, '_sql_') != 1, '_sql_project', @old_table);
set @table_path = json_unquote(json_search(
  @_sql_tables, 'one', '3D9C2B4ED6BA4AE39D3333FC5BBCC1FF', null, '$[*].comment'));
set @table_object = if(@table_path is null, null, replace(@table_path, '.comment', ''));
set @_sql_tables = if(@table_object is null or @new_table = @old_table,
  @_sql_tables,
  json_set(@_sql_tables, concat(@table_object, '.name'), @new_table)
);
set @_sql_columns = if(@new_table = @old_table, @_sql_columns, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'default', `default_value`,
      'nullable', `nullable`,
      'auto', `auto`,
      'ordinal', `ordinal`
  )), json_array())
  from (
      select *
      from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
      order by `table`, `ordinal`, `name`
  ) as `_sql_ordered_columns`
));
set @_sql_indexes = if(@new_table = @old_table, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'key_def', `key_def`,
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_table = @old_table, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'key_def', `key_def`,
      'referenced_table', if(`referenced_table` = @old_table, @new_table, `referenced_table`),
      'f_key_def', `f_key_def`,
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_table = null;
select `name` into @old_table
  from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
  where `comment` = 'FC94A0BB4E9B422ABC399BBF79E6AC43' and `type` = 'BASE TABLE';
set @new_table = if(@old_table != 'member' and instr(@old_table, '_sql_') != 1, '_sql_member', @old_table);
set @table_path = json_unquote(json_search(
  @_sql_tables, 'one', 'FC94A0BB4E9B422ABC399BBF79E6AC43', null, '$[*].comment'));
set @table_object = if(@table_path is null, null, replace(@table_path, '.comment', ''));
set @_sql_tables = if(@table_object is null or @new_table = @old_table,
  @_sql_tables,
  json_set(@_sql_tables, concat(@table_object, '.name'), @new_table)
);
set @_sql_columns = if(@new_table = @old_table, @_sql_columns, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'default', `default_value`,
      'nullable', `nullable`,
      'auto', `auto`,
      'ordinal', `ordinal`
  )), json_array())
  from (
      select *
      from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
      order by `table`, `ordinal`, `name`
  ) as `_sql_ordered_columns`
));
set @_sql_indexes = if(@new_table = @old_table, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'key_def', `key_def`,
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_table = @old_table, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'key_def', `key_def`,
      'referenced_table', if(`referenced_table` = @old_table, @new_table, `referenced_table`),
      'f_key_def', `f_key_def`,
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @qry = if (@ren_tables_final != '', concat ('RENAME TABLE ',
  substr(@ren_tables_final, 1, length(@ren_tables_final) - 2), ';')
,
  'SET @r = \'No table rename needed.\';');

select @qry as '';

set @old_table = null;
select `name` into @old_table
  from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
  where `comment` = '93B099B08D144B40BCC918FA24831669' and `type` = 'BASE TABLE';
set @new_table = if(@old_table != 'user', 'user', @old_table);
set @table_path = json_unquote(json_search(
  @_sql_tables, 'one', '93B099B08D144B40BCC918FA24831669', null, '$[*].comment'));
set @table_object = if(@table_path is null, null, replace(@table_path, '.comment', ''));
set @_sql_tables = if(@table_object is null or @new_table = @old_table,
  @_sql_tables,
  json_set(@_sql_tables, concat(@table_object, '.name'), @new_table)
);
set @_sql_columns = if(@new_table = @old_table, @_sql_columns, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'default', `default_value`,
      'nullable', `nullable`,
      'auto', `auto`,
      'ordinal', `ordinal`
  )), json_array())
  from (
      select *
      from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
      order by `table`, `ordinal`, `name`
  ) as `_sql_ordered_columns`
));
set @_sql_indexes = if(@new_table = @old_table, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'key_def', `key_def`,
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_table = @old_table, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'key_def', `key_def`,
      'referenced_table', if(`referenced_table` = @old_table, @new_table, `referenced_table`),
      'f_key_def', `f_key_def`,
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_table = null;
select `name` into @old_table
  from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
  where `comment` = '3D9C2B4ED6BA4AE39D3333FC5BBCC1FF' and `type` = 'BASE TABLE';
set @new_table = if(@old_table != 'project', 'project', @old_table);
set @table_path = json_unquote(json_search(
  @_sql_tables, 'one', '3D9C2B4ED6BA4AE39D3333FC5BBCC1FF', null, '$[*].comment'));
set @table_object = if(@table_path is null, null, replace(@table_path, '.comment', ''));
set @_sql_tables = if(@table_object is null or @new_table = @old_table,
  @_sql_tables,
  json_set(@_sql_tables, concat(@table_object, '.name'), @new_table)
);
set @_sql_columns = if(@new_table = @old_table, @_sql_columns, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'default', `default_value`,
      'nullable', `nullable`,
      'auto', `auto`,
      'ordinal', `ordinal`
  )), json_array())
  from (
      select *
      from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
      order by `table`, `ordinal`, `name`
  ) as `_sql_ordered_columns`
));
set @_sql_indexes = if(@new_table = @old_table, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'key_def', `key_def`,
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_table = @old_table, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'key_def', `key_def`,
      'referenced_table', if(`referenced_table` = @old_table, @new_table, `referenced_table`),
      'f_key_def', `f_key_def`,
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_table = null;
select `name` into @old_table
  from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
  where `comment` = 'FC94A0BB4E9B422ABC399BBF79E6AC43' and `type` = 'BASE TABLE';
set @new_table = if(@old_table != 'member', 'member', @old_table);
set @table_path = json_unquote(json_search(
  @_sql_tables, 'one', 'FC94A0BB4E9B422ABC399BBF79E6AC43', null, '$[*].comment'));
set @table_object = if(@table_path is null, null, replace(@table_path, '.comment', ''));
set @_sql_tables = if(@table_object is null or @new_table = @old_table,
  @_sql_tables,
  json_set(@_sql_tables, concat(@table_object, '.name'), @new_table)
);
set @_sql_columns = if(@new_table = @old_table, @_sql_columns, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'default', `default_value`,
      'nullable', `nullable`,
      'auto', `auto`,
      'ordinal', `ordinal`
  )), json_array())
  from (
      select *
      from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
      order by `table`, `ordinal`, `name`
  ) as `_sql_ordered_columns`
));
set @_sql_indexes = if(@new_table = @old_table, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'key_def', `key_def`,
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_table = @old_table, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'key_def', `key_def`,
      'referenced_table', if(`referenced_table` = @old_table, @new_table, `referenced_table`),
      'f_key_def', `f_key_def`,
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_engine = null;
select `engine` into @old_engine
  from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
  where `name` = 'user' and `type` = 'BASE TABLE';
set @qry = if (@old_engine != 'InnoDB',
  'ALTER TABLE `sales`.`user` ENGINE=InnoDB;'
,
  'SET @r = \'Engine of "user" is ok.\';'
);

select @qry as '';

set @table_path = json_unquote(json_search(
  @_sql_tables, 'one', '93B099B08D144B40BCC918FA24831669', null, '$[*].comment'));
set @table_object = if(@table_path is null, null, replace(@table_path, '.comment', ''));
set @_sql_tables = if(@table_object is null or @old_engine = 'InnoDB',
  @_sql_tables,
  json_set(@_sql_tables, concat(@table_object, '.engine'), 'InnoDB')
);

set @old_engine = null;
select `engine` into @old_engine
  from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
  where `name` = 'project' and `type` = 'BASE TABLE';
set @qry = if (@old_engine != 'InnoDB',
  'ALTER TABLE `sales`.`project` ENGINE=InnoDB;'
,
  'SET @r = \'Engine of "project" is ok.\';'
);

select @qry as '';

set @table_path = json_unquote(json_search(
  @_sql_tables, 'one', '3D9C2B4ED6BA4AE39D3333FC5BBCC1FF', null, '$[*].comment'));
set @table_object = if(@table_path is null, null, replace(@table_path, '.comment', ''));
set @_sql_tables = if(@table_object is null or @old_engine = 'InnoDB',
  @_sql_tables,
  json_set(@_sql_tables, concat(@table_object, '.engine'), 'InnoDB')
);

set @old_engine = null;
select `engine` into @old_engine
  from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
  where `name` = 'member' and `type` = 'BASE TABLE';
set @qry = if (@old_engine != 'InnoDB',
  'ALTER TABLE `sales`.`member` ENGINE=InnoDB;'
,
  'SET @r = \'Engine of "member" is ok.\';'
);

select @qry as '';

set @table_path = json_unquote(json_search(
  @_sql_tables, 'one', 'FC94A0BB4E9B422ABC399BBF79E6AC43', null, '$[*].comment'));
set @table_object = if(@table_path is null, null, replace(@table_path, '.comment', ''));
set @_sql_tables = if(@table_object is null or @old_engine = 'InnoDB',
  @_sql_tables,
  json_set(@_sql_tables, concat(@table_object, '.engine'), 'InnoDB')
);

set @all_columns = '';
set @sub_query = '';

set @all_columns = concat(@all_columns, '{76AC03C95026487AB55A590C48FE4C8F}');
set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '76AC03C95026487AB55A590C48FE4C8F' and
      `table` = 'user';
set @sub_query = if (isnull(@old_column),
  concat(@sub_query, 'ADD `_sql_id` int unsigned COMMENT \'76AC03C95026487AB55A590C48FE4C8F\', ')
,
  @sub_query
);

set @all_columns = concat(@all_columns, '{9B1B7A7BC7CF49B49A45E48E55B02669}');
set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '9B1B7A7BC7CF49B49A45E48E55B02669' and
      `table` = 'user';
set @sub_query = if (isnull(@old_column),
  concat(@sub_query, 'ADD `_sql_email` varchar(255) COMMENT \'9B1B7A7BC7CF49B49A45E48E55B02669\', ')
,
  @sub_query
);

set @all_columns = concat(@all_columns, '{410FE4351CD34E61AF4DAFE2B7AB7FE4}');
set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '410FE4351CD34E61AF4DAFE2B7AB7FE4' and
      `table` = 'user';
set @sub_query = if (isnull(@old_column),
  concat(@sub_query, 'ADD `_sql_password` varchar(255) COMMENT \'410FE4351CD34E61AF4DAFE2B7AB7FE4\', ')
,
  @sub_query
);

set @qry = if (@sub_query != '',
  concat('ALTER TABLE `sales`.`user` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
  'SET @r = \'No new column in "user" is needed.\';'
);

select @qry as '';

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '76AC03C95026487AB55A590C48FE4C8F' and
      `table` = 'user';
set @next_ordinal = (
  select coalesce(max(`ordinal`), 0) + 1
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `table` = 'user'
);
set @_sql_columns = if(isnull(@old_column),
  json_array_append(@_sql_columns, '$', json_object(
      'table', 'user',
      'name', '_sql_id',
      'comment', '76AC03C95026487AB55A590C48FE4C8F',
      'type', 'int unsigned',
      'default', null,
      'nullable', 'YES',
      'auto', false,
      'ordinal', @next_ordinal
  )),
  @_sql_columns
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '9B1B7A7BC7CF49B49A45E48E55B02669' and
      `table` = 'user';
set @next_ordinal = (
  select coalesce(max(`ordinal`), 0) + 1
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `table` = 'user'
);
set @_sql_columns = if(isnull(@old_column),
  json_array_append(@_sql_columns, '$', json_object(
      'table', 'user',
      'name', '_sql_email',
      'comment', '9B1B7A7BC7CF49B49A45E48E55B02669',
      'type', 'varchar(255)',
      'default', null,
      'nullable', 'YES',
      'auto', false,
      'ordinal', @next_ordinal
  )),
  @_sql_columns
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '410FE4351CD34E61AF4DAFE2B7AB7FE4' and
      `table` = 'user';
set @next_ordinal = (
  select coalesce(max(`ordinal`), 0) + 1
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `table` = 'user'
);
set @_sql_columns = if(isnull(@old_column),
  json_array_append(@_sql_columns, '$', json_object(
      'table', 'user',
      'name', '_sql_password',
      'comment', '410FE4351CD34E61AF4DAFE2B7AB7FE4',
      'type', 'varchar(255)',
      'default', null,
      'nullable', 'YES',
      'auto', false,
      'ordinal', @next_ordinal
  )),
  @_sql_columns
);

set @sub_query = null;
select group_concat(concat('RENAME COLUMN `', `name`, '` to `_sql__drop_', `name`, '`') SEPARATOR ', ')
  into @sub_query
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` not like '_sql__drop_%' and `table` = 'user' and
      instr(@all_columns, concat('{', `comment`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra column in "user".\';'
,
  concat('ALTER TABLE `sales`.`user` ', @sub_query, ';')
);

select @qry as '';

set @_sql_indexes = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def',
          if(`table` = 'user' and exists (
              select 1
              from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
              where `table` = 'user' and
                  `name` not like '_sql__drop_%' and
                  instr(@all_columns, concat('{', `comment`, '}')) = 0 and
                  instr(`_sql_ordered_indexes`.`key_def`, concat('`', `name`, '`')) > 0
          ),
              concat('__stale__', `key_def`),
              `key_def`
          ),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
);
set @_sql_foreign_keys = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def',
          if(`table` = 'user' and exists (
              select 1
              from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
              where `table` = 'user' and
                  `name` not like '_sql__drop_%' and
                  instr(@all_columns, concat('{', `comment`, '}')) = 0 and
                  instr(`_sql_ordered_foreign_keys`.`key_def`, concat('`', `name`, '`')) > 0
          ),
              concat('__stale__', `key_def`),
              `key_def`
          ),
      'referenced_table', `referenced_table`,
      'f_key_def',
          if(`referenced_table` = 'user' and exists (
              select 1
              from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
              where `table` = 'user' and
                  `name` not like '_sql__drop_%' and
                  instr(@all_columns, concat('{', `comment`, '}')) = 0 and
                  instr(`_sql_ordered_foreign_keys`.`f_key_def`, concat('`', `name`, '`')) > 0
          ),
              concat('__stale__', `f_key_def`),
              `f_key_def`
          ),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
);
set @_sql_columns = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'default', `default_value`,
      'nullable', `nullable`,
      'auto', `auto`,
      'ordinal', `ordinal`
  )), json_array())
  from (
      select
          `table`,
          if(`name` not like '_sql__drop_%' and `table` = 'user' and instr(@all_columns, concat('{', `comment`, '}')) = 0,
              concat('_sql__drop_', `name`),
              `name`
          ) as `name`,
          `comment`,
          `type`,
          `default_value`,
          `nullable`,
          `auto`,
          `ordinal`
      from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
      order by `table`, `ordinal`, `name`
  ) as `_sql_ordered_columns`
);

set @ren_columns_prefix = '';
set @ren_columns_final = '';

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '76AC03C95026487AB55A590C48FE4C8F' and
      `table` = 'user';
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

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '9B1B7A7BC7CF49B49A45E48E55B02669' and
      `table` = 'user';
set @ren_columns_prefix = if (@old_column != 'email' && instr(@old_column, '_sql_') != 1,
  concat(@ren_columns_prefix, 'RENAME COLUMN `', @old_column, '` to `_sql_email`, ')
,
  @ren_columns_prefix
);
set @ren_columns_final = if (@old_column != 'email',
  concat(@ren_columns_final, 'RENAME COLUMN `_sql_email` to `email`, ')
,
  @ren_columns_final
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '410FE4351CD34E61AF4DAFE2B7AB7FE4' and
      `table` = 'user';
set @ren_columns_prefix = if (@old_column != 'password' && instr(@old_column, '_sql_') != 1,
  concat(@ren_columns_prefix, 'RENAME COLUMN `', @old_column, '` to `_sql_password`, ')
,
  @ren_columns_prefix
);
set @ren_columns_final = if (@old_column != 'password',
  concat(@ren_columns_final, 'RENAME COLUMN `_sql_password` to `password`, ')
,
  @ren_columns_final
);

set @qry = if (@ren_columns_final != '',
  if (@ren_columns_prefix != '',
      concat ('ALTER TABLE `sales`.`user` ', substr(@ren_columns_prefix, 1,
      length(@ren_columns_prefix) - 2), ';')
  ,
      'SET @r = \'All columns in "user" have prefix.\';'
  ),
  'SET @r = \'No column in "user" needs prefix.\';'
);

select @qry as '';

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '76AC03C95026487AB55A590C48FE4C8F' and
      `table` = 'user';
set @new_column = if(@old_column != 'id' and instr(@old_column, '_sql_') != 1, '_sql_id', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '76AC03C95026487AB55A590C48FE4C8F', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'user', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'user', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'user', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '9B1B7A7BC7CF49B49A45E48E55B02669' and
      `table` = 'user';
set @new_column = if(@old_column != 'email' and instr(@old_column, '_sql_') != 1, '_sql_email', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '9B1B7A7BC7CF49B49A45E48E55B02669', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'user', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'user', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'user', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '410FE4351CD34E61AF4DAFE2B7AB7FE4' and
      `table` = 'user';
set @new_column = if(@old_column != 'password' and instr(@old_column, '_sql_') != 1, '_sql_password', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '410FE4351CD34E61AF4DAFE2B7AB7FE4', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'user', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'user', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'user', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @qry = if (@ren_columns_final != '', concat ('ALTER TABLE `sales`.`user` ',
  substr(@ren_columns_final, 1, length(@ren_columns_final) - 2), ';')
,
  'SET @r = \'No column in "user" needs rename.\';');

select @qry as '';

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '76AC03C95026487AB55A590C48FE4C8F' and
      `table` = 'user';
set @new_column = if(@old_column != 'id', 'id', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '76AC03C95026487AB55A590C48FE4C8F', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'user', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'user', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'user', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '9B1B7A7BC7CF49B49A45E48E55B02669' and
      `table` = 'user';
set @new_column = if(@old_column != 'email', 'email', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '9B1B7A7BC7CF49B49A45E48E55B02669', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'user', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'user', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'user', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '410FE4351CD34E61AF4DAFE2B7AB7FE4' and
      `table` = 'user';
set @new_column = if(@old_column != 'password', 'password', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '410FE4351CD34E61AF4DAFE2B7AB7FE4', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'user', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'user', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'user', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @all_columns = '';
set @sub_query = '';

set @all_columns = concat(@all_columns, '{7EA682D7A35E4398A7C782C5F177F4D8}');
set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '7EA682D7A35E4398A7C782C5F177F4D8' and
      `table` = 'project';
set @sub_query = if (isnull(@old_column),
  concat(@sub_query, 'ADD `_sql_id` int unsigned COMMENT \'7EA682D7A35E4398A7C782C5F177F4D8\', ')
,
  @sub_query
);

set @all_columns = concat(@all_columns, '{C0D24606E108403D92397A3C0AEE219E}');
set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'C0D24606E108403D92397A3C0AEE219E' and
      `table` = 'project';
set @sub_query = if (isnull(@old_column),
  concat(@sub_query, 'ADD `_sql_name` varchar(255) COMMENT \'C0D24606E108403D92397A3C0AEE219E\', ')
,
  @sub_query
);

set @all_columns = concat(@all_columns, '{0899EAFFFE7A41C7A9876DDDE0E01373}');
set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '0899EAFFFE7A41C7A9876DDDE0E01373' and
      `table` = 'project';
set @sub_query = if (isnull(@old_column),
  concat(@sub_query, 'ADD `_sql_summary` varchar(255) DEFAULT "" COMMENT \'0899EAFFFE7A41C7A9876DDDE0E01373\', ')
,
  @sub_query
);

set @all_columns = concat(@all_columns, '{7E228CCA41014B51A73A444EEE34AD92}');
set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '7E228CCA41014B51A73A444EEE34AD92' and
      `table` = 'project';
set @sub_query = if (isnull(@old_column),
  concat(@sub_query, 'ADD `_sql_stage` int unsigned COMMENT \'7E228CCA41014B51A73A444EEE34AD92\', ')
,
  @sub_query
);

set @all_columns = concat(@all_columns, '{16380EA4B54B4E8BB3CF78F36BC51AA2}');
set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '16380EA4B54B4E8BB3CF78F36BC51AA2' and
      `table` = 'project';
set @sub_query = if (isnull(@old_column),
  concat(@sub_query, 'ADD `_sql_round` int unsigned COMMENT \'16380EA4B54B4E8BB3CF78F36BC51AA2\', ')
,
  @sub_query
);

set @all_columns = concat(@all_columns, '{ECF2AAA32B1A455595F7AF087089C005}');
set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'ECF2AAA32B1A455595F7AF087089C005' and
      `table` = 'project';
set @sub_query = if (isnull(@old_column),
  concat(@sub_query, 'ADD `_sql_archived` tinyint(1) COMMENT \'ECF2AAA32B1A455595F7AF087089C005\', ')
,
  @sub_query
);

set @qry = if (@sub_query != '',
  concat('ALTER TABLE `sales`.`project` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
  'SET @r = \'No new column in "project" is needed.\';'
);

select @qry as '';

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '7EA682D7A35E4398A7C782C5F177F4D8' and
      `table` = 'project';
set @next_ordinal = (
  select coalesce(max(`ordinal`), 0) + 1
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `table` = 'project'
);
set @_sql_columns = if(isnull(@old_column),
  json_array_append(@_sql_columns, '$', json_object(
      'table', 'project',
      'name', '_sql_id',
      'comment', '7EA682D7A35E4398A7C782C5F177F4D8',
      'type', 'int unsigned',
      'default', null,
      'nullable', 'YES',
      'auto', false,
      'ordinal', @next_ordinal
  )),
  @_sql_columns
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'C0D24606E108403D92397A3C0AEE219E' and
      `table` = 'project';
set @next_ordinal = (
  select coalesce(max(`ordinal`), 0) + 1
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `table` = 'project'
);
set @_sql_columns = if(isnull(@old_column),
  json_array_append(@_sql_columns, '$', json_object(
      'table', 'project',
      'name', '_sql_name',
      'comment', 'C0D24606E108403D92397A3C0AEE219E',
      'type', 'varchar(255)',
      'default', null,
      'nullable', 'YES',
      'auto', false,
      'ordinal', @next_ordinal
  )),
  @_sql_columns
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '0899EAFFFE7A41C7A9876DDDE0E01373' and
      `table` = 'project';
set @next_ordinal = (
  select coalesce(max(`ordinal`), 0) + 1
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `table` = 'project'
);
set @_sql_columns = if(isnull(@old_column),
  json_array_append(@_sql_columns, '$', json_object(
      'table', 'project',
      'name', '_sql_summary',
      'comment', '0899EAFFFE7A41C7A9876DDDE0E01373',
      'type', 'varchar(255)',
      'default', "",
      'nullable', 'YES',
      'auto', false,
      'ordinal', @next_ordinal
  )),
  @_sql_columns
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '7E228CCA41014B51A73A444EEE34AD92' and
      `table` = 'project';
set @next_ordinal = (
  select coalesce(max(`ordinal`), 0) + 1
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `table` = 'project'
);
set @_sql_columns = if(isnull(@old_column),
  json_array_append(@_sql_columns, '$', json_object(
      'table', 'project',
      'name', '_sql_stage',
      'comment', '7E228CCA41014B51A73A444EEE34AD92',
      'type', 'int unsigned',
      'default', null,
      'nullable', 'YES',
      'auto', false,
      'ordinal', @next_ordinal
  )),
  @_sql_columns
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '16380EA4B54B4E8BB3CF78F36BC51AA2' and
      `table` = 'project';
set @next_ordinal = (
  select coalesce(max(`ordinal`), 0) + 1
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `table` = 'project'
);
set @_sql_columns = if(isnull(@old_column),
  json_array_append(@_sql_columns, '$', json_object(
      'table', 'project',
      'name', '_sql_round',
      'comment', '16380EA4B54B4E8BB3CF78F36BC51AA2',
      'type', 'int unsigned',
      'default', null,
      'nullable', 'YES',
      'auto', false,
      'ordinal', @next_ordinal
  )),
  @_sql_columns
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'ECF2AAA32B1A455595F7AF087089C005' and
      `table` = 'project';
set @next_ordinal = (
  select coalesce(max(`ordinal`), 0) + 1
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `table` = 'project'
);
set @_sql_columns = if(isnull(@old_column),
  json_array_append(@_sql_columns, '$', json_object(
      'table', 'project',
      'name', '_sql_archived',
      'comment', 'ECF2AAA32B1A455595F7AF087089C005',
      'type', 'tinyint(1)',
      'default', null,
      'nullable', 'YES',
      'auto', false,
      'ordinal', @next_ordinal
  )),
  @_sql_columns
);

set @sub_query = null;
select group_concat(concat('RENAME COLUMN `', `name`, '` to `_sql__drop_', `name`, '`') SEPARATOR ', ')
  into @sub_query
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` not like '_sql__drop_%' and `table` = 'project' and
      instr(@all_columns, concat('{', `comment`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra column in "project".\';'
,
  concat('ALTER TABLE `sales`.`project` ', @sub_query, ';')
);

select @qry as '';

set @_sql_indexes = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def',
          if(`table` = 'project' and exists (
              select 1
              from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
              where `table` = 'project' and
                  `name` not like '_sql__drop_%' and
                  instr(@all_columns, concat('{', `comment`, '}')) = 0 and
                  instr(`_sql_ordered_indexes`.`key_def`, concat('`', `name`, '`')) > 0
          ),
              concat('__stale__', `key_def`),
              `key_def`
          ),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
);
set @_sql_foreign_keys = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def',
          if(`table` = 'project' and exists (
              select 1
              from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
              where `table` = 'project' and
                  `name` not like '_sql__drop_%' and
                  instr(@all_columns, concat('{', `comment`, '}')) = 0 and
                  instr(`_sql_ordered_foreign_keys`.`key_def`, concat('`', `name`, '`')) > 0
          ),
              concat('__stale__', `key_def`),
              `key_def`
          ),
      'referenced_table', `referenced_table`,
      'f_key_def',
          if(`referenced_table` = 'project' and exists (
              select 1
              from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
              where `table` = 'project' and
                  `name` not like '_sql__drop_%' and
                  instr(@all_columns, concat('{', `comment`, '}')) = 0 and
                  instr(`_sql_ordered_foreign_keys`.`f_key_def`, concat('`', `name`, '`')) > 0
          ),
              concat('__stale__', `f_key_def`),
              `f_key_def`
          ),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
);
set @_sql_columns = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'default', `default_value`,
      'nullable', `nullable`,
      'auto', `auto`,
      'ordinal', `ordinal`
  )), json_array())
  from (
      select
          `table`,
          if(`name` not like '_sql__drop_%' and `table` = 'project' and instr(@all_columns, concat('{', `comment`, '}')) = 0,
              concat('_sql__drop_', `name`),
              `name`
          ) as `name`,
          `comment`,
          `type`,
          `default_value`,
          `nullable`,
          `auto`,
          `ordinal`
      from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
      order by `table`, `ordinal`, `name`
  ) as `_sql_ordered_columns`
);

set @ren_columns_prefix = '';
set @ren_columns_final = '';

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '7EA682D7A35E4398A7C782C5F177F4D8' and
      `table` = 'project';
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

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'C0D24606E108403D92397A3C0AEE219E' and
      `table` = 'project';
set @ren_columns_prefix = if (@old_column != 'name' && instr(@old_column, '_sql_') != 1,
  concat(@ren_columns_prefix, 'RENAME COLUMN `', @old_column, '` to `_sql_name`, ')
,
  @ren_columns_prefix
);
set @ren_columns_final = if (@old_column != 'name',
  concat(@ren_columns_final, 'RENAME COLUMN `_sql_name` to `name`, ')
,
  @ren_columns_final
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '0899EAFFFE7A41C7A9876DDDE0E01373' and
      `table` = 'project';
set @ren_columns_prefix = if (@old_column != 'summary' && instr(@old_column, '_sql_') != 1,
  concat(@ren_columns_prefix, 'RENAME COLUMN `', @old_column, '` to `_sql_summary`, ')
,
  @ren_columns_prefix
);
set @ren_columns_final = if (@old_column != 'summary',
  concat(@ren_columns_final, 'RENAME COLUMN `_sql_summary` to `summary`, ')
,
  @ren_columns_final
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '7E228CCA41014B51A73A444EEE34AD92' and
      `table` = 'project';
set @ren_columns_prefix = if (@old_column != 'stage' && instr(@old_column, '_sql_') != 1,
  concat(@ren_columns_prefix, 'RENAME COLUMN `', @old_column, '` to `_sql_stage`, ')
,
  @ren_columns_prefix
);
set @ren_columns_final = if (@old_column != 'stage',
  concat(@ren_columns_final, 'RENAME COLUMN `_sql_stage` to `stage`, ')
,
  @ren_columns_final
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '16380EA4B54B4E8BB3CF78F36BC51AA2' and
      `table` = 'project';
set @ren_columns_prefix = if (@old_column != 'round' && instr(@old_column, '_sql_') != 1,
  concat(@ren_columns_prefix, 'RENAME COLUMN `', @old_column, '` to `_sql_round`, ')
,
  @ren_columns_prefix
);
set @ren_columns_final = if (@old_column != 'round',
  concat(@ren_columns_final, 'RENAME COLUMN `_sql_round` to `round`, ')
,
  @ren_columns_final
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'ECF2AAA32B1A455595F7AF087089C005' and
      `table` = 'project';
set @ren_columns_prefix = if (@old_column != 'archived' && instr(@old_column, '_sql_') != 1,
  concat(@ren_columns_prefix, 'RENAME COLUMN `', @old_column, '` to `_sql_archived`, ')
,
  @ren_columns_prefix
);
set @ren_columns_final = if (@old_column != 'archived',
  concat(@ren_columns_final, 'RENAME COLUMN `_sql_archived` to `archived`, ')
,
  @ren_columns_final
);

set @qry = if (@ren_columns_final != '',
  if (@ren_columns_prefix != '',
      concat ('ALTER TABLE `sales`.`project` ', substr(@ren_columns_prefix, 1,
      length(@ren_columns_prefix) - 2), ';')
  ,
      'SET @r = \'All columns in "project" have prefix.\';'
  ),
  'SET @r = \'No column in "project" needs prefix.\';'
);

select @qry as '';

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '7EA682D7A35E4398A7C782C5F177F4D8' and
      `table` = 'project';
set @new_column = if(@old_column != 'id' and instr(@old_column, '_sql_') != 1, '_sql_id', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '7EA682D7A35E4398A7C782C5F177F4D8', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'project', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'C0D24606E108403D92397A3C0AEE219E' and
      `table` = 'project';
set @new_column = if(@old_column != 'name' and instr(@old_column, '_sql_') != 1, '_sql_name', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'C0D24606E108403D92397A3C0AEE219E', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'project', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '0899EAFFFE7A41C7A9876DDDE0E01373' and
      `table` = 'project';
set @new_column = if(@old_column != 'summary' and instr(@old_column, '_sql_') != 1, '_sql_summary', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '0899EAFFFE7A41C7A9876DDDE0E01373', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'project', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '7E228CCA41014B51A73A444EEE34AD92' and
      `table` = 'project';
set @new_column = if(@old_column != 'stage' and instr(@old_column, '_sql_') != 1, '_sql_stage', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '7E228CCA41014B51A73A444EEE34AD92', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'project', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '16380EA4B54B4E8BB3CF78F36BC51AA2' and
      `table` = 'project';
set @new_column = if(@old_column != 'round' and instr(@old_column, '_sql_') != 1, '_sql_round', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '16380EA4B54B4E8BB3CF78F36BC51AA2', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'project', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'ECF2AAA32B1A455595F7AF087089C005' and
      `table` = 'project';
set @new_column = if(@old_column != 'archived' and instr(@old_column, '_sql_') != 1, '_sql_archived', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'ECF2AAA32B1A455595F7AF087089C005', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'project', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @qry = if (@ren_columns_final != '', concat ('ALTER TABLE `sales`.`project` ',
  substr(@ren_columns_final, 1, length(@ren_columns_final) - 2), ';')
,
  'SET @r = \'No column in "project" needs rename.\';');

select @qry as '';

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '7EA682D7A35E4398A7C782C5F177F4D8' and
      `table` = 'project';
set @new_column = if(@old_column != 'id', 'id', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '7EA682D7A35E4398A7C782C5F177F4D8', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'project', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'C0D24606E108403D92397A3C0AEE219E' and
      `table` = 'project';
set @new_column = if(@old_column != 'name', 'name', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'C0D24606E108403D92397A3C0AEE219E', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'project', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '0899EAFFFE7A41C7A9876DDDE0E01373' and
      `table` = 'project';
set @new_column = if(@old_column != 'summary', 'summary', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '0899EAFFFE7A41C7A9876DDDE0E01373', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'project', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '7E228CCA41014B51A73A444EEE34AD92' and
      `table` = 'project';
set @new_column = if(@old_column != 'stage', 'stage', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '7E228CCA41014B51A73A444EEE34AD92', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'project', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '16380EA4B54B4E8BB3CF78F36BC51AA2' and
      `table` = 'project';
set @new_column = if(@old_column != 'round', 'round', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '16380EA4B54B4E8BB3CF78F36BC51AA2', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'project', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'ECF2AAA32B1A455595F7AF087089C005' and
      `table` = 'project';
set @new_column = if(@old_column != 'archived', 'archived', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'ECF2AAA32B1A455595F7AF087089C005', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'project', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'project', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @all_columns = '';
set @sub_query = '';

set @all_columns = concat(@all_columns, '{197EF5B6132D4FC5A284EC950999BFD4}');
set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '197EF5B6132D4FC5A284EC950999BFD4' and
      `table` = 'member';
set @sub_query = if (isnull(@old_column),
  concat(@sub_query, 'ADD `_sql_id` int unsigned COMMENT \'197EF5B6132D4FC5A284EC950999BFD4\', ')
,
  @sub_query
);

set @all_columns = concat(@all_columns, '{4426A25349774BE6A296440E10CD42BB}');
set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '4426A25349774BE6A296440E10CD42BB' and
      `table` = 'member';
set @sub_query = if (isnull(@old_column),
  concat(@sub_query, 'ADD `_sql_project` int unsigned COMMENT \'4426A25349774BE6A296440E10CD42BB\', ')
,
  @sub_query
);

set @all_columns = concat(@all_columns, '{0FB8B46DDF0348FBB5459592689E71C8}');
set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '0FB8B46DDF0348FBB5459592689E71C8' and
      `table` = 'member';
set @sub_query = if (isnull(@old_column),
  concat(@sub_query, 'ADD `_sql_user` int unsigned COMMENT \'0FB8B46DDF0348FBB5459592689E71C8\', ')
,
  @sub_query
);

set @all_columns = concat(@all_columns, '{A6643F4E00B24616A21CB88193ABDAE8}');
set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'A6643F4E00B24616A21CB88193ABDAE8' and
      `table` = 'member';
set @sub_query = if (isnull(@old_column),
  concat(@sub_query, 'ADD `_sql_admin` tinyint(1) COMMENT \'A6643F4E00B24616A21CB88193ABDAE8\', ')
,
  @sub_query
);

set @all_columns = concat(@all_columns, '{F27DEAD22DBB4256BA9B0B04147411EE}');
set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'F27DEAD22DBB4256BA9B0B04147411EE' and
      `table` = 'member';
set @sub_query = if (isnull(@old_column),
  concat(@sub_query, 'ADD `_sql_nickname` varchar(50) COMMENT \'F27DEAD22DBB4256BA9B0B04147411EE\', ')
,
  @sub_query
);

set @all_columns = concat(@all_columns, '{B278231268FA4DBF8EF910285AA64776}');
set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'B278231268FA4DBF8EF910285AA64776' and
      `table` = 'member';
set @sub_query = if (isnull(@old_column),
  concat(@sub_query, 'ADD `_sql_pin` int unsigned COMMENT \'B278231268FA4DBF8EF910285AA64776\', ')
,
  @sub_query
);

set @qry = if (@sub_query != '',
  concat('ALTER TABLE `sales`.`member` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
  'SET @r = \'No new column in "member" is needed.\';'
);

select @qry as '';

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '197EF5B6132D4FC5A284EC950999BFD4' and
      `table` = 'member';
set @next_ordinal = (
  select coalesce(max(`ordinal`), 0) + 1
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `table` = 'member'
);
set @_sql_columns = if(isnull(@old_column),
  json_array_append(@_sql_columns, '$', json_object(
      'table', 'member',
      'name', '_sql_id',
      'comment', '197EF5B6132D4FC5A284EC950999BFD4',
      'type', 'int unsigned',
      'default', null,
      'nullable', 'YES',
      'auto', false,
      'ordinal', @next_ordinal
  )),
  @_sql_columns
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '4426A25349774BE6A296440E10CD42BB' and
      `table` = 'member';
set @next_ordinal = (
  select coalesce(max(`ordinal`), 0) + 1
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `table` = 'member'
);
set @_sql_columns = if(isnull(@old_column),
  json_array_append(@_sql_columns, '$', json_object(
      'table', 'member',
      'name', '_sql_project',
      'comment', '4426A25349774BE6A296440E10CD42BB',
      'type', 'int unsigned',
      'default', null,
      'nullable', 'YES',
      'auto', false,
      'ordinal', @next_ordinal
  )),
  @_sql_columns
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '0FB8B46DDF0348FBB5459592689E71C8' and
      `table` = 'member';
set @next_ordinal = (
  select coalesce(max(`ordinal`), 0) + 1
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `table` = 'member'
);
set @_sql_columns = if(isnull(@old_column),
  json_array_append(@_sql_columns, '$', json_object(
      'table', 'member',
      'name', '_sql_user',
      'comment', '0FB8B46DDF0348FBB5459592689E71C8',
      'type', 'int unsigned',
      'default', null,
      'nullable', 'YES',
      'auto', false,
      'ordinal', @next_ordinal
  )),
  @_sql_columns
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'A6643F4E00B24616A21CB88193ABDAE8' and
      `table` = 'member';
set @next_ordinal = (
  select coalesce(max(`ordinal`), 0) + 1
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `table` = 'member'
);
set @_sql_columns = if(isnull(@old_column),
  json_array_append(@_sql_columns, '$', json_object(
      'table', 'member',
      'name', '_sql_admin',
      'comment', 'A6643F4E00B24616A21CB88193ABDAE8',
      'type', 'tinyint(1)',
      'default', null,
      'nullable', 'YES',
      'auto', false,
      'ordinal', @next_ordinal
  )),
  @_sql_columns
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'F27DEAD22DBB4256BA9B0B04147411EE' and
      `table` = 'member';
set @next_ordinal = (
  select coalesce(max(`ordinal`), 0) + 1
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `table` = 'member'
);
set @_sql_columns = if(isnull(@old_column),
  json_array_append(@_sql_columns, '$', json_object(
      'table', 'member',
      'name', '_sql_nickname',
      'comment', 'F27DEAD22DBB4256BA9B0B04147411EE',
      'type', 'varchar(50)',
      'default', null,
      'nullable', 'YES',
      'auto', false,
      'ordinal', @next_ordinal
  )),
  @_sql_columns
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'B278231268FA4DBF8EF910285AA64776' and
      `table` = 'member';
set @next_ordinal = (
  select coalesce(max(`ordinal`), 0) + 1
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `table` = 'member'
);
set @_sql_columns = if(isnull(@old_column),
  json_array_append(@_sql_columns, '$', json_object(
      'table', 'member',
      'name', '_sql_pin',
      'comment', 'B278231268FA4DBF8EF910285AA64776',
      'type', 'int unsigned',
      'default', null,
      'nullable', 'YES',
      'auto', false,
      'ordinal', @next_ordinal
  )),
  @_sql_columns
);

set @sub_query = null;
select group_concat(concat('RENAME COLUMN `', `name`, '` to `_sql__drop_', `name`, '`') SEPARATOR ', ')
  into @sub_query
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` not like '_sql__drop_%' and `table` = 'member' and
      instr(@all_columns, concat('{', `comment`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra column in "member".\';'
,
  concat('ALTER TABLE `sales`.`member` ', @sub_query, ';')
);

select @qry as '';

set @_sql_indexes = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def',
          if(`table` = 'member' and exists (
              select 1
              from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
              where `table` = 'member' and
                  `name` not like '_sql__drop_%' and
                  instr(@all_columns, concat('{', `comment`, '}')) = 0 and
                  instr(`_sql_ordered_indexes`.`key_def`, concat('`', `name`, '`')) > 0
          ),
              concat('__stale__', `key_def`),
              `key_def`
          ),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
);
set @_sql_foreign_keys = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def',
          if(`table` = 'member' and exists (
              select 1
              from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
              where `table` = 'member' and
                  `name` not like '_sql__drop_%' and
                  instr(@all_columns, concat('{', `comment`, '}')) = 0 and
                  instr(`_sql_ordered_foreign_keys`.`key_def`, concat('`', `name`, '`')) > 0
          ),
              concat('__stale__', `key_def`),
              `key_def`
          ),
      'referenced_table', `referenced_table`,
      'f_key_def',
          if(`referenced_table` = 'member' and exists (
              select 1
              from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
              where `table` = 'member' and
                  `name` not like '_sql__drop_%' and
                  instr(@all_columns, concat('{', `comment`, '}')) = 0 and
                  instr(`_sql_ordered_foreign_keys`.`f_key_def`, concat('`', `name`, '`')) > 0
          ),
              concat('__stale__', `f_key_def`),
              `f_key_def`
          ),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
);
set @_sql_columns = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'default', `default_value`,
      'nullable', `nullable`,
      'auto', `auto`,
      'ordinal', `ordinal`
  )), json_array())
  from (
      select
          `table`,
          if(`name` not like '_sql__drop_%' and `table` = 'member' and instr(@all_columns, concat('{', `comment`, '}')) = 0,
              concat('_sql__drop_', `name`),
              `name`
          ) as `name`,
          `comment`,
          `type`,
          `default_value`,
          `nullable`,
          `auto`,
          `ordinal`
      from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
      order by `table`, `ordinal`, `name`
  ) as `_sql_ordered_columns`
);

set @ren_columns_prefix = '';
set @ren_columns_final = '';

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '197EF5B6132D4FC5A284EC950999BFD4' and
      `table` = 'member';
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

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '4426A25349774BE6A296440E10CD42BB' and
      `table` = 'member';
set @ren_columns_prefix = if (@old_column != 'project' && instr(@old_column, '_sql_') != 1,
  concat(@ren_columns_prefix, 'RENAME COLUMN `', @old_column, '` to `_sql_project`, ')
,
  @ren_columns_prefix
);
set @ren_columns_final = if (@old_column != 'project',
  concat(@ren_columns_final, 'RENAME COLUMN `_sql_project` to `project`, ')
,
  @ren_columns_final
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '0FB8B46DDF0348FBB5459592689E71C8' and
      `table` = 'member';
set @ren_columns_prefix = if (@old_column != 'user' && instr(@old_column, '_sql_') != 1,
  concat(@ren_columns_prefix, 'RENAME COLUMN `', @old_column, '` to `_sql_user`, ')
,
  @ren_columns_prefix
);
set @ren_columns_final = if (@old_column != 'user',
  concat(@ren_columns_final, 'RENAME COLUMN `_sql_user` to `user`, ')
,
  @ren_columns_final
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'A6643F4E00B24616A21CB88193ABDAE8' and
      `table` = 'member';
set @ren_columns_prefix = if (@old_column != 'admin' && instr(@old_column, '_sql_') != 1,
  concat(@ren_columns_prefix, 'RENAME COLUMN `', @old_column, '` to `_sql_admin`, ')
,
  @ren_columns_prefix
);
set @ren_columns_final = if (@old_column != 'admin',
  concat(@ren_columns_final, 'RENAME COLUMN `_sql_admin` to `admin`, ')
,
  @ren_columns_final
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'F27DEAD22DBB4256BA9B0B04147411EE' and
      `table` = 'member';
set @ren_columns_prefix = if (@old_column != 'nickname' && instr(@old_column, '_sql_') != 1,
  concat(@ren_columns_prefix, 'RENAME COLUMN `', @old_column, '` to `_sql_nickname`, ')
,
  @ren_columns_prefix
);
set @ren_columns_final = if (@old_column != 'nickname',
  concat(@ren_columns_final, 'RENAME COLUMN `_sql_nickname` to `nickname`, ')
,
  @ren_columns_final
);

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'B278231268FA4DBF8EF910285AA64776' and
      `table` = 'member';
set @ren_columns_prefix = if (@old_column != 'pin' && instr(@old_column, '_sql_') != 1,
  concat(@ren_columns_prefix, 'RENAME COLUMN `', @old_column, '` to `_sql_pin`, ')
,
  @ren_columns_prefix
);
set @ren_columns_final = if (@old_column != 'pin',
  concat(@ren_columns_final, 'RENAME COLUMN `_sql_pin` to `pin`, ')
,
  @ren_columns_final
);

set @qry = if (@ren_columns_final != '',
  if (@ren_columns_prefix != '',
      concat ('ALTER TABLE `sales`.`member` ', substr(@ren_columns_prefix, 1,
      length(@ren_columns_prefix) - 2), ';')
  ,
      'SET @r = \'All columns in "member" have prefix.\';'
  ),
  'SET @r = \'No column in "member" needs prefix.\';'
);

select @qry as '';

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '197EF5B6132D4FC5A284EC950999BFD4' and
      `table` = 'member';
set @new_column = if(@old_column != 'id' and instr(@old_column, '_sql_') != 1, '_sql_id', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '197EF5B6132D4FC5A284EC950999BFD4', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'member', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '4426A25349774BE6A296440E10CD42BB' and
      `table` = 'member';
set @new_column = if(@old_column != 'project' and instr(@old_column, '_sql_') != 1, '_sql_project', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '4426A25349774BE6A296440E10CD42BB', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'member', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '0FB8B46DDF0348FBB5459592689E71C8' and
      `table` = 'member';
set @new_column = if(@old_column != 'user' and instr(@old_column, '_sql_') != 1, '_sql_user', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '0FB8B46DDF0348FBB5459592689E71C8', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'member', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'A6643F4E00B24616A21CB88193ABDAE8' and
      `table` = 'member';
set @new_column = if(@old_column != 'admin' and instr(@old_column, '_sql_') != 1, '_sql_admin', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'A6643F4E00B24616A21CB88193ABDAE8', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'member', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'F27DEAD22DBB4256BA9B0B04147411EE' and
      `table` = 'member';
set @new_column = if(@old_column != 'nickname' and instr(@old_column, '_sql_') != 1, '_sql_nickname', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'F27DEAD22DBB4256BA9B0B04147411EE', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'member', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'B278231268FA4DBF8EF910285AA64776' and
      `table` = 'member';
set @new_column = if(@old_column != 'pin' and instr(@old_column, '_sql_') != 1, '_sql_pin', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'B278231268FA4DBF8EF910285AA64776', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'member', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @qry = if (@ren_columns_final != '', concat ('ALTER TABLE `sales`.`member` ',
  substr(@ren_columns_final, 1, length(@ren_columns_final) - 2), ';')
,
  'SET @r = \'No column in "member" needs rename.\';');

select @qry as '';

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '197EF5B6132D4FC5A284EC950999BFD4' and
      `table` = 'member';
set @new_column = if(@old_column != 'id', 'id', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '197EF5B6132D4FC5A284EC950999BFD4', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'member', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '4426A25349774BE6A296440E10CD42BB' and
      `table` = 'member';
set @new_column = if(@old_column != 'project', 'project', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '4426A25349774BE6A296440E10CD42BB', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'member', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = '0FB8B46DDF0348FBB5459592689E71C8' and
      `table` = 'member';
set @new_column = if(@old_column != 'user', 'user', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '0FB8B46DDF0348FBB5459592689E71C8', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'member', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'A6643F4E00B24616A21CB88193ABDAE8' and
      `table` = 'member';
set @new_column = if(@old_column != 'admin', 'admin', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'A6643F4E00B24616A21CB88193ABDAE8', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'member', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'F27DEAD22DBB4256BA9B0B04147411EE' and
      `table` = 'member';
set @new_column = if(@old_column != 'nickname', 'nickname', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'F27DEAD22DBB4256BA9B0B04147411EE', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'member', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @old_column = null;
select `name` into @old_column
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `comment` = 'B278231268FA4DBF8EF910285AA64776' and
      `table` = 'member';
set @new_column = if(@old_column != 'pin', 'pin', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'B278231268FA4DBF8EF910285AA64776', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = 'member', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = 'member', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));

set @all_foreign_keys = '';

set @sub_query = null;
select group_concat(distinct
  concat('DROP FOREIGN KEY `', `name`, '`') SEPARATOR ', ')
into @sub_query
from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
where
  `table` = 'user' and
  instr(@all_foreign_keys, concat('{', `name`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra foreign keys in "user".\';'
,
  concat('ALTER TABLE `sales`.`user` ', @sub_query, ';')
);

select @qry as '';

set @_sql_foreign_keys = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', `key_def`,
      'referenced_table', `referenced_table`,
      'f_key_def', `f_key_def`,
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      where not (`table` = 'user' and instr(@all_foreign_keys, concat('{', `name`, '}')) = 0)
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
);
set @_sql_indexes = if(isnull(@sub_query),
  @_sql_indexes,
  (
      select coalesce(json_arrayagg(json_object(
          'table', `table`,
          'name', `name`,
          'key_def', `key_def`,
          'foreign_key',
              if(`table` = 'user' and instr(@all_foreign_keys, concat('{', `name`, '}')) = 0,
                  false,
                  `foreign_key`)
      )), json_array())
      from (
          select *
          from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
          order by `table`, `name`
      ) as `_sql_ordered_indexes`
  )
);

set @all_foreign_keys = '';

set @sub_query = null;
select group_concat(distinct
  concat('DROP FOREIGN KEY `', `name`, '`') SEPARATOR ', ')
into @sub_query
from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
where
  `table` = 'project' and
  instr(@all_foreign_keys, concat('{', `name`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra foreign keys in "project".\';'
,
  concat('ALTER TABLE `sales`.`project` ', @sub_query, ';')
);

select @qry as '';

set @_sql_foreign_keys = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', `key_def`,
      'referenced_table', `referenced_table`,
      'f_key_def', `f_key_def`,
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      where not (`table` = 'project' and instr(@all_foreign_keys, concat('{', `name`, '}')) = 0)
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
);
set @_sql_indexes = if(isnull(@sub_query),
  @_sql_indexes,
  (
      select coalesce(json_arrayagg(json_object(
          'table', `table`,
          'name', `name`,
          'key_def', `key_def`,
          'foreign_key',
              if(`table` = 'project' and instr(@all_foreign_keys, concat('{', `name`, '}')) = 0,
                  false,
                  `foreign_key`)
      )), json_array())
      from (
          select *
          from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
          order by `table`, `name`
      ) as `_sql_ordered_indexes`
  )
);

set @all_foreign_keys = '';

set @all_foreign_keys = concat(@all_foreign_keys, '{fk_member_project}');
set @old_constraint = null;
set @old_table = null;
set @old_key_def = null;
set @old_referenced_table = null;
set @old_f_key_def = null;
set @old_update_rule = null;
set @old_delete_rule = null;
select
  `name`,
  `table`,
  `key_def`,
  `referenced_table`,
  `f_key_def`,
  `update_rule`,
  `delete_rule`
into
  @old_constraint,
  @old_table,
  @old_key_def,
  @old_referenced_table,
  @old_f_key_def,
  @old_update_rule,
  @old_delete_rule
from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
where `name` = 'fk_member_project';
set @old_ok = 
  @old_table = 'member' and
  @old_key_def = '`project`' and
  @old_referenced_table = 'project' and
  @old_f_key_def = '`id`' and
  @old_update_rule = 'RESTRICT' and
  @old_delete_rule = 'RESTRICT';
set @qry = if (@old_ok or isnull(@old_constraint),
  'SET @r = \'Foreign key "fk_member_project" does not exist.\';'
,
  concat('ALTER TABLE `sales`.`', @old_table, '` DROP FOREIGN KEY `fk_member_project`;'));
	
select @qry as '';

set @_sql_foreign_keys = if(@old_ok or isnull(@old_constraint),
  @_sql_foreign_keys,
  (
      select coalesce(json_arrayagg(json_object(
          'table', `table`,
          'name', `name`,
          'key_def', `key_def`,
          'referenced_table', `referenced_table`,
          'f_key_def', `f_key_def`,
          'update', `update_rule`,
          'delete', `delete_rule`
      )), json_array())
      from (
          select *
          from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
          where not (`table` = @old_table and `name` = @old_constraint)
          order by `table`, `name`
      ) as `_sql_ordered_foreign_keys`
  )
);
set @_sql_indexes = if(@old_ok or isnull(@old_constraint),
  @_sql_indexes,
  (
      select coalesce(json_arrayagg(json_object(
          'table', `table`,
          'name', `name`,
          'key_def', `key_def`,
          'foreign_key',
              if(`table` = @old_table and `name` = @old_constraint, false, `foreign_key`)
      )), json_array())
      from (
          select *
          from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
          order by `table`, `name`
      ) as `_sql_ordered_indexes`
  )
);

set @all_foreign_keys = concat(@all_foreign_keys, '{fk_member_user}');
set @old_constraint = null;
set @old_table = null;
set @old_key_def = null;
set @old_referenced_table = null;
set @old_f_key_def = null;
set @old_update_rule = null;
set @old_delete_rule = null;
select
  `name`,
  `table`,
  `key_def`,
  `referenced_table`,
  `f_key_def`,
  `update_rule`,
  `delete_rule`
into
  @old_constraint,
  @old_table,
  @old_key_def,
  @old_referenced_table,
  @old_f_key_def,
  @old_update_rule,
  @old_delete_rule
from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
where `name` = 'fk_member_user';
set @old_ok = 
  @old_table = 'member' and
  @old_key_def = '`user`' and
  @old_referenced_table = 'user' and
  @old_f_key_def = '`id`' and
  @old_update_rule = 'RESTRICT' and
  @old_delete_rule = 'RESTRICT';
set @qry = if (@old_ok or isnull(@old_constraint),
  'SET @r = \'Foreign key "fk_member_user" does not exist.\';'
,
  concat('ALTER TABLE `sales`.`', @old_table, '` DROP FOREIGN KEY `fk_member_user`;'));
	
select @qry as '';

set @_sql_foreign_keys = if(@old_ok or isnull(@old_constraint),
  @_sql_foreign_keys,
  (
      select coalesce(json_arrayagg(json_object(
          'table', `table`,
          'name', `name`,
          'key_def', `key_def`,
          'referenced_table', `referenced_table`,
          'f_key_def', `f_key_def`,
          'update', `update_rule`,
          'delete', `delete_rule`
      )), json_array())
      from (
          select *
          from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
          where not (`table` = @old_table and `name` = @old_constraint)
          order by `table`, `name`
      ) as `_sql_ordered_foreign_keys`
  )
);
set @_sql_indexes = if(@old_ok or isnull(@old_constraint),
  @_sql_indexes,
  (
      select coalesce(json_arrayagg(json_object(
          'table', `table`,
          'name', `name`,
          'key_def', `key_def`,
          'foreign_key',
              if(`table` = @old_table and `name` = @old_constraint, false, `foreign_key`)
      )), json_array())
      from (
          select *
          from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
          order by `table`, `name`
      ) as `_sql_ordered_indexes`
  )
);

set @sub_query = null;
select group_concat(distinct
  concat('DROP FOREIGN KEY `', `name`, '`') SEPARATOR ', ')
into @sub_query
from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
where
  `table` = 'member' and
  instr(@all_foreign_keys, concat('{', `name`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra foreign keys in "member".\';'
,
  concat('ALTER TABLE `sales`.`member` ', @sub_query, ';')
);

select @qry as '';

set @_sql_foreign_keys = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', `key_def`,
      'referenced_table', `referenced_table`,
      'f_key_def', `f_key_def`,
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
      where not (`table` = 'member' and instr(@all_foreign_keys, concat('{', `name`, '}')) = 0)
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
);
set @_sql_indexes = if(isnull(@sub_query),
  @_sql_indexes,
  (
      select coalesce(json_arrayagg(json_object(
          'table', `table`,
          'name', `name`,
          'key_def', `key_def`,
          'foreign_key',
              if(`table` = 'member' and instr(@all_foreign_keys, concat('{', `name`, '}')) = 0,
                  false,
                  `foreign_key`)
      )), json_array())
      from (
          select *
          from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
          order by `table`, `name`
      ) as `_sql_ordered_indexes`
  )
);

set @sub_query = '';
set @ordinal_change = false;

set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `type`, `default_value`, `nullable`, `auto`, `ordinal`
  into @old_type, @old_default, @old_null, @old_auto, @old_position
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'id' and
      `table` = 'user';
set @ordinal_change = if (@old_position != 1, true, @ordinal_change);
set @sub_query = if (@ordinal_change or
  @old_type != 'int unsigned' or
  @old_null != 'NO' or
  @old_auto != true,
  concat(@sub_query, 'MODIFY `id` int unsigned not null auto_increment COMMENT \'76AC03C95026487AB55A590C48FE4C8F\' FIRST, ')
,
  @sub_query
);

set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `type`, `default_value`, `nullable`, `auto`, `ordinal`
  into @old_type, @old_default, @old_null, @old_auto, @old_position
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'email' and
      `table` = 'user';
set @ordinal_change = if (@old_position != 2, true, @ordinal_change);
set @sub_query = if (@ordinal_change or
  @old_type != 'varchar(255)' or
  @old_null != 'YES' or
  @old_auto != false,
  concat(@sub_query, 'MODIFY `email` varchar(255) null COMMENT \'9B1B7A7BC7CF49B49A45E48E55B02669\' AFTER `id`, ')
,
  @sub_query
);

set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `type`, `default_value`, `nullable`, `auto`, `ordinal`
  into @old_type, @old_default, @old_null, @old_auto, @old_position
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'password' and
      `table` = 'user';
set @ordinal_change = if (@old_position != 3, true, @ordinal_change);
set @sub_query = if (@ordinal_change or
  @old_type != 'varchar(255)' or
  @old_null != 'NO' or
  @old_auto != false,
  concat(@sub_query, 'MODIFY `password` varchar(255) not null COMMENT \'410FE4351CD34E61AF4DAFE2B7AB7FE4\' AFTER `email`, ')
,
  @sub_query
);

set @all_keys = '';

set @all_keys = concat(@all_keys, '{PRIMARY}');
set @old_index = null;
set @old_key_def = null;
select
  `name`,
  `key_def`
into
  @old_index,
  @old_key_def
from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
where
  `table` = 'user' and
  `name` = 'PRIMARY';
set @old_ok = @old_key_def = '`id`';
set @drop_query = if (@old_ok or isnull(@old_index), '',
  'DROP PRIMARY KEY, ');
set @sub_query = concat(@sub_query, @drop_query);
set @sub_query = if (@drop_query != '' or isnull(@old_index),
  concat(@sub_query, 'ADD primary key (`id`), ')
, @sub_query);

set @all_keys = concat(@all_keys, '{unique_email}');
set @old_index = null;
set @old_key_def = null;
select
  `name`,
  `key_def`
into
  @old_index,
  @old_key_def
from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
where
  `table` = 'user' and
  `name` = 'unique_email';
set @old_ok = @old_key_def = '`email`';
set @drop_query = if (@old_ok or isnull(@old_index), '',
  'DROP INDEX `unique_email`, ');
set @sub_query = concat(@sub_query, @drop_query);
set @sub_query = if (@drop_query != '' or isnull(@old_index),
  concat(@sub_query, 'ADD unique index `unique_email` (`email`), ')
, @sub_query);

set @drop_query = null;
select group_concat(distinct
  concat('DROP INDEX `', `name`, '`') SEPARATOR ', ')
into @drop_query
from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
where
  `foreign_key` = false and
  `table` = 'user' and
  instr(@all_keys, concat('{', `name`, '}')) = 0;
set @sub_query = if (isnull(@drop_query), @sub_query,
  concat(@sub_query, @drop_query, ', ')
);

set @drop_query = null;
select group_concat(concat('DROP COLUMN `', `name`, '`')
  SEPARATOR ', ') into @drop_query
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where
      `table` = 'user' and
      `name` like '_sql__drop_%';
set @sub_query = if (isnull(@drop_query), @sub_query,
  concat(@sub_query, @drop_query, ', ')
);

set @qry = if (@sub_query != '',
  concat ('ALTER TABLE `sales`.`user` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
  'SET @r = \'Table "user" is ok.\';'
);

select @qry as '';

set @_sql_columns = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'default', `default_value`,
      'nullable', `nullable`,
      'auto', `auto`,
      'ordinal', `ordinal`
  )), json_array())
  from (
      select *
      from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
      where not (`table` = 'user' and `name` like '_sql__drop_%')
      order by `table`, `ordinal`, `name`
  ) as `_sql_ordered_columns`
);

set @_sql_indexes = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', `key_def`,
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      where `table` != 'user' or `foreign_key` = true
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
);

set @_sql_indexes = json_array_append(@_sql_indexes, '$', json_object(
  'table', 'user',
  'name', 'PRIMARY',
  'key_def', '`id`',
  'foreign_key', false
));

set @_sql_indexes = json_array_append(@_sql_indexes, '$', json_object(
  'table', 'user',
  'name', 'unique_email',
  'key_def', '`email`',
  'foreign_key', false
));

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '76AC03C95026487AB55A590C48FE4C8F', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(
      @_sql_columns,
      concat(@column_object, '.type'), 'int unsigned',
      concat(@column_object, '.default'), json_extract(@_sql_columns, concat(@column_object, '.default')),
      concat(@column_object, '.nullable'), 'NO',
      concat(@column_object, '.auto'), true,
      concat(@column_object, '.ordinal'), 1
  )
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '9B1B7A7BC7CF49B49A45E48E55B02669', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(
      @_sql_columns,
      concat(@column_object, '.type'), 'varchar(255)',
      concat(@column_object, '.default'), json_extract(@_sql_columns, concat(@column_object, '.default')),
      concat(@column_object, '.nullable'), 'YES',
      concat(@column_object, '.auto'), false,
      concat(@column_object, '.ordinal'), 2
  )
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '410FE4351CD34E61AF4DAFE2B7AB7FE4', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(
      @_sql_columns,
      concat(@column_object, '.type'), 'varchar(255)',
      concat(@column_object, '.default'), json_extract(@_sql_columns, concat(@column_object, '.default')),
      concat(@column_object, '.nullable'), 'NO',
      concat(@column_object, '.auto'), false,
      concat(@column_object, '.ordinal'), 3
  )
);

set @sub_query = '';
set @ordinal_change = false;

set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `type`, `default_value`, `nullable`, `auto`, `ordinal`
  into @old_type, @old_default, @old_null, @old_auto, @old_position
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'id' and
      `table` = 'project';
set @ordinal_change = if (@old_position != 1, true, @ordinal_change);
set @sub_query = if (@ordinal_change or
  @old_type != 'int unsigned' or
  @old_null != 'NO' or
  @old_auto != true,
  concat(@sub_query, 'MODIFY `id` int unsigned not null auto_increment COMMENT \'7EA682D7A35E4398A7C782C5F177F4D8\' FIRST, ')
,
  @sub_query
);

set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `type`, `default_value`, `nullable`, `auto`, `ordinal`
  into @old_type, @old_default, @old_null, @old_auto, @old_position
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'name' and
      `table` = 'project';
set @ordinal_change = if (@old_position != 2, true, @ordinal_change);
set @sub_query = if (@ordinal_change or
  @old_type != 'varchar(255)' or
  @old_null != 'NO' or
  @old_auto != false,
  concat(@sub_query, 'MODIFY `name` varchar(255) not null COMMENT \'C0D24606E108403D92397A3C0AEE219E\' AFTER `id`, ')
,
  @sub_query
);

set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `type`, `default_value`, `nullable`, `auto`, `ordinal`
  into @old_type, @old_default, @old_null, @old_auto, @old_position
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'summary' and
      `table` = 'project';
set @ordinal_change = if (@old_position != 3, true, @ordinal_change);
set @sub_query = if (@ordinal_change or
  @old_type != 'varchar(255)' or @old_default IS NULL or @old_default != "" or
  @old_null != 'NO' or
  @old_auto != false,
  concat(@sub_query, 'MODIFY `summary` varchar(255) DEFAULT "" not null COMMENT \'0899EAFFFE7A41C7A9876DDDE0E01373\' AFTER `name`, ')
,
  @sub_query
);

set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `type`, `default_value`, `nullable`, `auto`, `ordinal`
  into @old_type, @old_default, @old_null, @old_auto, @old_position
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'stage' and
      `table` = 'project';
set @ordinal_change = if (@old_position != 4, true, @ordinal_change);
set @sub_query = if (@ordinal_change or
  @old_type != 'int unsigned' or
  @old_null != 'NO' or
  @old_auto != false,
  concat(@sub_query, 'MODIFY `stage` int unsigned not null COMMENT \'7E228CCA41014B51A73A444EEE34AD92\' AFTER `summary`, ')
,
  @sub_query
);

set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `type`, `default_value`, `nullable`, `auto`, `ordinal`
  into @old_type, @old_default, @old_null, @old_auto, @old_position
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'round' and
      `table` = 'project';
set @ordinal_change = if (@old_position != 5, true, @ordinal_change);
set @sub_query = if (@ordinal_change or
  @old_type != 'int unsigned' or
  @old_null != 'NO' or
  @old_auto != false,
  concat(@sub_query, 'MODIFY `round` int unsigned not null COMMENT \'16380EA4B54B4E8BB3CF78F36BC51AA2\' AFTER `stage`, ')
,
  @sub_query
);

set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `type`, `default_value`, `nullable`, `auto`, `ordinal`
  into @old_type, @old_default, @old_null, @old_auto, @old_position
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'archived' and
      `table` = 'project';
set @ordinal_change = if (@old_position != 6, true, @ordinal_change);
set @sub_query = if (@ordinal_change or
  @old_type != 'tinyint(1)' or
  @old_null != 'NO' or
  @old_auto != false,
  concat(@sub_query, 'MODIFY `archived` tinyint(1) not null COMMENT \'ECF2AAA32B1A455595F7AF087089C005\' AFTER `round`, ')
,
  @sub_query
);

set @all_keys = '';

set @all_keys = concat(@all_keys, '{PRIMARY}');
set @old_index = null;
set @old_key_def = null;
select
  `name`,
  `key_def`
into
  @old_index,
  @old_key_def
from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
where
  `table` = 'project' and
  `name` = 'PRIMARY';
set @old_ok = @old_key_def = '`id`';
set @drop_query = if (@old_ok or isnull(@old_index), '',
  'DROP PRIMARY KEY, ');
set @sub_query = concat(@sub_query, @drop_query);
set @sub_query = if (@drop_query != '' or isnull(@old_index),
  concat(@sub_query, 'ADD primary key (`id`), ')
, @sub_query);

set @all_keys = concat(@all_keys, '{unique_name}');
set @old_index = null;
set @old_key_def = null;
select
  `name`,
  `key_def`
into
  @old_index,
  @old_key_def
from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
where
  `table` = 'project' and
  `name` = 'unique_name';
set @old_ok = @old_key_def = '`name`';
set @drop_query = if (@old_ok or isnull(@old_index), '',
  'DROP INDEX `unique_name`, ');
set @sub_query = concat(@sub_query, @drop_query);
set @sub_query = if (@drop_query != '' or isnull(@old_index),
  concat(@sub_query, 'ADD unique index `unique_name` (`name`), ')
, @sub_query);

set @drop_query = null;
select group_concat(distinct
  concat('DROP INDEX `', `name`, '`') SEPARATOR ', ')
into @drop_query
from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
where
  `foreign_key` = false and
  `table` = 'project' and
  instr(@all_keys, concat('{', `name`, '}')) = 0;
set @sub_query = if (isnull(@drop_query), @sub_query,
  concat(@sub_query, @drop_query, ', ')
);

set @drop_query = null;
select group_concat(concat('DROP COLUMN `', `name`, '`')
  SEPARATOR ', ') into @drop_query
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where
      `table` = 'project' and
      `name` like '_sql__drop_%';
set @sub_query = if (isnull(@drop_query), @sub_query,
  concat(@sub_query, @drop_query, ', ')
);

set @qry = if (@sub_query != '',
  concat ('ALTER TABLE `sales`.`project` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
  'SET @r = \'Table "project" is ok.\';'
);

select @qry as '';

set @_sql_columns = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'default', `default_value`,
      'nullable', `nullable`,
      'auto', `auto`,
      'ordinal', `ordinal`
  )), json_array())
  from (
      select *
      from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
      where not (`table` = 'project' and `name` like '_sql__drop_%')
      order by `table`, `ordinal`, `name`
  ) as `_sql_ordered_columns`
);

set @_sql_indexes = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', `key_def`,
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      where `table` != 'project' or `foreign_key` = true
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
);

set @_sql_indexes = json_array_append(@_sql_indexes, '$', json_object(
  'table', 'project',
  'name', 'PRIMARY',
  'key_def', '`id`',
  'foreign_key', false
));

set @_sql_indexes = json_array_append(@_sql_indexes, '$', json_object(
  'table', 'project',
  'name', 'unique_name',
  'key_def', '`name`',
  'foreign_key', false
));

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '7EA682D7A35E4398A7C782C5F177F4D8', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(
      @_sql_columns,
      concat(@column_object, '.type'), 'int unsigned',
      concat(@column_object, '.default'), json_extract(@_sql_columns, concat(@column_object, '.default')),
      concat(@column_object, '.nullable'), 'NO',
      concat(@column_object, '.auto'), true,
      concat(@column_object, '.ordinal'), 1
  )
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'C0D24606E108403D92397A3C0AEE219E', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(
      @_sql_columns,
      concat(@column_object, '.type'), 'varchar(255)',
      concat(@column_object, '.default'), json_extract(@_sql_columns, concat(@column_object, '.default')),
      concat(@column_object, '.nullable'), 'NO',
      concat(@column_object, '.auto'), false,
      concat(@column_object, '.ordinal'), 2
  )
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '0899EAFFFE7A41C7A9876DDDE0E01373', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(
      @_sql_columns,
      concat(@column_object, '.type'), 'varchar(255)',
      concat(@column_object, '.default'), "",
      concat(@column_object, '.nullable'), 'NO',
      concat(@column_object, '.auto'), false,
      concat(@column_object, '.ordinal'), 3
  )
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '7E228CCA41014B51A73A444EEE34AD92', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(
      @_sql_columns,
      concat(@column_object, '.type'), 'int unsigned',
      concat(@column_object, '.default'), json_extract(@_sql_columns, concat(@column_object, '.default')),
      concat(@column_object, '.nullable'), 'NO',
      concat(@column_object, '.auto'), false,
      concat(@column_object, '.ordinal'), 4
  )
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '16380EA4B54B4E8BB3CF78F36BC51AA2', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(
      @_sql_columns,
      concat(@column_object, '.type'), 'int unsigned',
      concat(@column_object, '.default'), json_extract(@_sql_columns, concat(@column_object, '.default')),
      concat(@column_object, '.nullable'), 'NO',
      concat(@column_object, '.auto'), false,
      concat(@column_object, '.ordinal'), 5
  )
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'ECF2AAA32B1A455595F7AF087089C005', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(
      @_sql_columns,
      concat(@column_object, '.type'), 'tinyint(1)',
      concat(@column_object, '.default'), json_extract(@_sql_columns, concat(@column_object, '.default')),
      concat(@column_object, '.nullable'), 'NO',
      concat(@column_object, '.auto'), false,
      concat(@column_object, '.ordinal'), 6
  )
);

set @sub_query = '';
set @ordinal_change = false;

set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `type`, `default_value`, `nullable`, `auto`, `ordinal`
  into @old_type, @old_default, @old_null, @old_auto, @old_position
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'id' and
      `table` = 'member';
set @ordinal_change = if (@old_position != 1, true, @ordinal_change);
set @sub_query = if (@ordinal_change or
  @old_type != 'int unsigned' or
  @old_null != 'NO' or
  @old_auto != true,
  concat(@sub_query, 'MODIFY `id` int unsigned not null auto_increment COMMENT \'197EF5B6132D4FC5A284EC950999BFD4\' FIRST, ')
,
  @sub_query
);

set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `type`, `default_value`, `nullable`, `auto`, `ordinal`
  into @old_type, @old_default, @old_null, @old_auto, @old_position
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'project' and
      `table` = 'member';
set @ordinal_change = if (@old_position != 2, true, @ordinal_change);
set @sub_query = if (@ordinal_change or
  @old_type != 'int unsigned' or
  @old_null != 'NO' or
  @old_auto != false,
  concat(@sub_query, 'MODIFY `project` int unsigned not null COMMENT \'4426A25349774BE6A296440E10CD42BB\' AFTER `id`, ')
,
  @sub_query
);

set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `type`, `default_value`, `nullable`, `auto`, `ordinal`
  into @old_type, @old_default, @old_null, @old_auto, @old_position
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'user' and
      `table` = 'member';
set @ordinal_change = if (@old_position != 3, true, @ordinal_change);
set @sub_query = if (@ordinal_change or
  @old_type != 'int unsigned' or
  @old_null != 'YES' or
  @old_auto != false,
  concat(@sub_query, 'MODIFY `user` int unsigned null COMMENT \'0FB8B46DDF0348FBB5459592689E71C8\' AFTER `project`, ')
,
  @sub_query
);

set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `type`, `default_value`, `nullable`, `auto`, `ordinal`
  into @old_type, @old_default, @old_null, @old_auto, @old_position
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'admin' and
      `table` = 'member';
set @ordinal_change = if (@old_position != 4, true, @ordinal_change);
set @sub_query = if (@ordinal_change or
  @old_type != 'tinyint(1)' or
  @old_null != 'NO' or
  @old_auto != false,
  concat(@sub_query, 'MODIFY `admin` tinyint(1) not null COMMENT \'A6643F4E00B24616A21CB88193ABDAE8\' AFTER `user`, ')
,
  @sub_query
);

set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `type`, `default_value`, `nullable`, `auto`, `ordinal`
  into @old_type, @old_default, @old_null, @old_auto, @old_position
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'nickname' and
      `table` = 'member';
set @ordinal_change = if (@old_position != 5, true, @ordinal_change);
set @sub_query = if (@ordinal_change or
  @old_type != 'varchar(50)' or
  @old_null != 'NO' or
  @old_auto != false,
  concat(@sub_query, 'MODIFY `nickname` varchar(50) not null COMMENT \'F27DEAD22DBB4256BA9B0B04147411EE\' AFTER `admin`, ')
,
  @sub_query
);

set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `type`, `default_value`, `nullable`, `auto`, `ordinal`
  into @old_type, @old_default, @old_null, @old_auto, @old_position
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'pin' and
      `table` = 'member';
set @ordinal_change = if (@old_position != 6, true, @ordinal_change);
set @sub_query = if (@ordinal_change or
  @old_type != 'int unsigned' or
  @old_null != 'NO' or
  @old_auto != false,
  concat(@sub_query, 'MODIFY `pin` int unsigned not null COMMENT \'B278231268FA4DBF8EF910285AA64776\' AFTER `nickname`, ')
,
  @sub_query
);

set @all_keys = '';

set @all_keys = concat(@all_keys, '{PRIMARY}');
set @old_index = null;
set @old_key_def = null;
select
  `name`,
  `key_def`
into
  @old_index,
  @old_key_def
from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
where
  `table` = 'member' and
  `name` = 'PRIMARY';
set @old_ok = @old_key_def = '`id`';
set @drop_query = if (@old_ok or isnull(@old_index), '',
  'DROP PRIMARY KEY, ');
set @sub_query = concat(@sub_query, @drop_query);
set @sub_query = if (@drop_query != '' or isnull(@old_index),
  concat(@sub_query, 'ADD primary key (`id`), ')
, @sub_query);

set @all_keys = concat(@all_keys, '{unique_member}');
set @old_index = null;
set @old_key_def = null;
select
  `name`,
  `key_def`
into
  @old_index,
  @old_key_def
from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
where
  `table` = 'member' and
  `name` = 'unique_member';
set @old_ok = @old_key_def = '`project`, `user`';
set @drop_query = if (@old_ok or isnull(@old_index), '',
  'DROP INDEX `unique_member`, ');
set @sub_query = concat(@sub_query, @drop_query);
set @sub_query = if (@drop_query != '' or isnull(@old_index),
  concat(@sub_query, 'ADD unique index `unique_member` (`project`, `user`), ')
, @sub_query);

set @all_keys = concat(@all_keys, '{unique_name}');
set @old_index = null;
set @old_key_def = null;
select
  `name`,
  `key_def`
into
  @old_index,
  @old_key_def
from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
where
  `table` = 'member' and
  `name` = 'unique_name';
set @old_ok = @old_key_def = '`project`, `nickname`';
set @drop_query = if (@old_ok or isnull(@old_index), '',
  'DROP INDEX `unique_name`, ');
set @sub_query = concat(@sub_query, @drop_query);
set @sub_query = if (@drop_query != '' or isnull(@old_index),
  concat(@sub_query, 'ADD unique index `unique_name` (`project`, `nickname`), ')
, @sub_query);

set @drop_query = null;
select group_concat(distinct
  concat('DROP INDEX `', `name`, '`') SEPARATOR ', ')
into @drop_query
from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
where
  `foreign_key` = false and
  `table` = 'member' and
  instr(@all_keys, concat('{', `name`, '}')) = 0;
set @sub_query = if (isnull(@drop_query), @sub_query,
  concat(@sub_query, @drop_query, ', ')
);

set @drop_query = null;
select group_concat(concat('DROP COLUMN `', `name`, '`')
  SEPARATOR ', ') into @drop_query
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where
      `table` = 'member' and
      `name` like '_sql__drop_%';
set @sub_query = if (isnull(@drop_query), @sub_query,
  concat(@sub_query, @drop_query, ', ')
);

set @qry = if (@sub_query != '',
  concat ('ALTER TABLE `sales`.`member` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
  'SET @r = \'Table "member" is ok.\';'
);

select @qry as '';

set @_sql_columns = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'default', `default_value`,
      'nullable', `nullable`,
      'auto', `auto`,
      'ordinal', `ordinal`
  )), json_array())
  from (
      select *
      from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
      where not (`table` = 'member' and `name` like '_sql__drop_%')
      order by `table`, `ordinal`, `name`
  ) as `_sql_ordered_columns`
);

set @_sql_indexes = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', `key_def`,
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from json_table(@_sql_indexes, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`
      where `table` != 'member' or `foreign_key` = true
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
);

set @_sql_indexes = json_array_append(@_sql_indexes, '$', json_object(
  'table', 'member',
  'name', 'PRIMARY',
  'key_def', '`id`',
  'foreign_key', false
));

set @_sql_indexes = json_array_append(@_sql_indexes, '$', json_object(
  'table', 'member',
  'name', 'unique_member',
  'key_def', '`project`, `user`',
  'foreign_key', false
));

set @_sql_indexes = json_array_append(@_sql_indexes, '$', json_object(
  'table', 'member',
  'name', 'unique_name',
  'key_def', '`project`, `nickname`',
  'foreign_key', false
));

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '197EF5B6132D4FC5A284EC950999BFD4', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(
      @_sql_columns,
      concat(@column_object, '.type'), 'int unsigned',
      concat(@column_object, '.default'), json_extract(@_sql_columns, concat(@column_object, '.default')),
      concat(@column_object, '.nullable'), 'NO',
      concat(@column_object, '.auto'), true,
      concat(@column_object, '.ordinal'), 1
  )
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '4426A25349774BE6A296440E10CD42BB', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(
      @_sql_columns,
      concat(@column_object, '.type'), 'int unsigned',
      concat(@column_object, '.default'), json_extract(@_sql_columns, concat(@column_object, '.default')),
      concat(@column_object, '.nullable'), 'NO',
      concat(@column_object, '.auto'), false,
      concat(@column_object, '.ordinal'), 2
  )
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '0FB8B46DDF0348FBB5459592689E71C8', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(
      @_sql_columns,
      concat(@column_object, '.type'), 'int unsigned',
      concat(@column_object, '.default'), json_extract(@_sql_columns, concat(@column_object, '.default')),
      concat(@column_object, '.nullable'), 'YES',
      concat(@column_object, '.auto'), false,
      concat(@column_object, '.ordinal'), 3
  )
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'A6643F4E00B24616A21CB88193ABDAE8', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(
      @_sql_columns,
      concat(@column_object, '.type'), 'tinyint(1)',
      concat(@column_object, '.default'), json_extract(@_sql_columns, concat(@column_object, '.default')),
      concat(@column_object, '.nullable'), 'NO',
      concat(@column_object, '.auto'), false,
      concat(@column_object, '.ordinal'), 4
  )
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'F27DEAD22DBB4256BA9B0B04147411EE', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(
      @_sql_columns,
      concat(@column_object, '.type'), 'varchar(50)',
      concat(@column_object, '.default'), json_extract(@_sql_columns, concat(@column_object, '.default')),
      concat(@column_object, '.nullable'), 'NO',
      concat(@column_object, '.auto'), false,
      concat(@column_object, '.ordinal'), 5
  )
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'B278231268FA4DBF8EF910285AA64776', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(
      @_sql_columns,
      concat(@column_object, '.type'), 'int unsigned',
      concat(@column_object, '.default'), json_extract(@_sql_columns, concat(@column_object, '.default')),
      concat(@column_object, '.nullable'), 'NO',
      concat(@column_object, '.auto'), false,
      concat(@column_object, '.ordinal'), 6
  )
);

set @sub_query = '';

set @old_default = null;
select `default_value`
  into @old_default
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'id' and
      `table` = 'user';
set @sub_query = if (@old_default IS NOT NULL,
  concat(@sub_query, 'ALTER COLUMN `id` DROP DEFAULT, ')
,
  @sub_query
);

set @old_default = null;
select `default_value`
  into @old_default
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'email' and
      `table` = 'user';
set @sub_query = if (@old_default IS NOT NULL,
  concat(@sub_query, 'ALTER COLUMN `email` DROP DEFAULT, ')
,
  @sub_query
);

set @old_default = null;
select `default_value`
  into @old_default
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'password' and
      `table` = 'user';
set @sub_query = if (@old_default IS NOT NULL,
  concat(@sub_query, 'ALTER COLUMN `password` DROP DEFAULT, ')
,
  @sub_query
);

set @qry = if (@sub_query != '',
  concat ('ALTER TABLE `sales`.`user` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
  'SET @r = \'Table "user" is ok.\';'
);

select @qry as '';

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '76AC03C95026487AB55A590C48FE4C8F', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.default'), null)
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '9B1B7A7BC7CF49B49A45E48E55B02669', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.default'), null)
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '410FE4351CD34E61AF4DAFE2B7AB7FE4', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.default'), null)
);

set @sub_query = '';

set @old_default = null;
select `default_value`
  into @old_default
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'id' and
      `table` = 'project';
set @sub_query = if (@old_default IS NOT NULL,
  concat(@sub_query, 'ALTER COLUMN `id` DROP DEFAULT, ')
,
  @sub_query
);

set @old_default = null;
select `default_value`
  into @old_default
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'name' and
      `table` = 'project';
set @sub_query = if (@old_default IS NOT NULL,
  concat(@sub_query, 'ALTER COLUMN `name` DROP DEFAULT, ')
,
  @sub_query
);

set @old_default = null;
select `default_value`
  into @old_default
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'stage' and
      `table` = 'project';
set @sub_query = if (@old_default IS NOT NULL,
  concat(@sub_query, 'ALTER COLUMN `stage` DROP DEFAULT, ')
,
  @sub_query
);

set @old_default = null;
select `default_value`
  into @old_default
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'round' and
      `table` = 'project';
set @sub_query = if (@old_default IS NOT NULL,
  concat(@sub_query, 'ALTER COLUMN `round` DROP DEFAULT, ')
,
  @sub_query
);

set @old_default = null;
select `default_value`
  into @old_default
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'archived' and
      `table` = 'project';
set @sub_query = if (@old_default IS NOT NULL,
  concat(@sub_query, 'ALTER COLUMN `archived` DROP DEFAULT, ')
,
  @sub_query
);

set @qry = if (@sub_query != '',
  concat ('ALTER TABLE `sales`.`project` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
  'SET @r = \'Table "project" is ok.\';'
);

select @qry as '';

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '7EA682D7A35E4398A7C782C5F177F4D8', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.default'), null)
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'C0D24606E108403D92397A3C0AEE219E', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.default'), null)
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '7E228CCA41014B51A73A444EEE34AD92', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.default'), null)
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '16380EA4B54B4E8BB3CF78F36BC51AA2', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.default'), null)
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'ECF2AAA32B1A455595F7AF087089C005', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.default'), null)
);

set @sub_query = '';

set @old_default = null;
select `default_value`
  into @old_default
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'id' and
      `table` = 'member';
set @sub_query = if (@old_default IS NOT NULL,
  concat(@sub_query, 'ALTER COLUMN `id` DROP DEFAULT, ')
,
  @sub_query
);

set @old_default = null;
select `default_value`
  into @old_default
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'project' and
      `table` = 'member';
set @sub_query = if (@old_default IS NOT NULL,
  concat(@sub_query, 'ALTER COLUMN `project` DROP DEFAULT, ')
,
  @sub_query
);

set @old_default = null;
select `default_value`
  into @old_default
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'user' and
      `table` = 'member';
set @sub_query = if (@old_default IS NOT NULL,
  concat(@sub_query, 'ALTER COLUMN `user` DROP DEFAULT, ')
,
  @sub_query
);

set @old_default = null;
select `default_value`
  into @old_default
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'admin' and
      `table` = 'member';
set @sub_query = if (@old_default IS NOT NULL,
  concat(@sub_query, 'ALTER COLUMN `admin` DROP DEFAULT, ')
,
  @sub_query
);

set @old_default = null;
select `default_value`
  into @old_default
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'nickname' and
      `table` = 'member';
set @sub_query = if (@old_default IS NOT NULL,
  concat(@sub_query, 'ALTER COLUMN `nickname` DROP DEFAULT, ')
,
  @sub_query
);

set @old_default = null;
select `default_value`
  into @old_default
  from json_table(@_sql_columns, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`
  where `name` = 'pin' and
      `table` = 'member';
set @sub_query = if (@old_default IS NOT NULL,
  concat(@sub_query, 'ALTER COLUMN `pin` DROP DEFAULT, ')
,
  @sub_query
);

set @qry = if (@sub_query != '',
  concat ('ALTER TABLE `sales`.`member` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
  'SET @r = \'Table "member" is ok.\';'
);

select @qry as '';

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '197EF5B6132D4FC5A284EC950999BFD4', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.default'), null)
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '4426A25349774BE6A296440E10CD42BB', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.default'), null)
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', '0FB8B46DDF0348FBB5459592689E71C8', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.default'), null)
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'A6643F4E00B24616A21CB88193ABDAE8', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.default'), null)
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'F27DEAD22DBB4256BA9B0B04147411EE', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.default'), null)
);

set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', 'B278231268FA4DBF8EF910285AA64776', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.default'), null)
);

set @sub_query = null;
select group_concat(concat('`sales`.`', `name`, '`')
  SEPARATOR ', ') into @sub_query
from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
where
  `type` = 'BASE TABLE' and
  `name` like '_sql__drop_%';
set @qry = if (isnull(@sub_query), 'SET @r = \'No extra table.\';',
  concat('DROP TABLE ', @sub_query, ';')
);

select @qry as '';

set @_sql_tables = (
  select coalesce(json_arrayagg(json_object(
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'engine', `engine`
  )), json_array())
  from (
      select *
      from json_table(@_sql_tables, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`
      where not (`type` = 'BASE TABLE' and `name` like '_sql__drop_%')
      order by `type`, `name`
  ) as `_sql_ordered_tables`
);

set @old_constraint = null;
set @old_table = null;
set @old_key_def = null;
set @old_referenced_table = null;
set @old_f_key_def = null;
select `name` into @old_constraint
from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
where
  `table` = 'member' and
  `name` = 'fk_member_project';
set @qry = if (isnull(@old_constraint),
  'ALTER TABLE `sales`.`member` ADD CONSTRAINT `fk_member_project` FOREIGN KEY (`project`) REFERENCES `sales`.`project` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT;',
  'SET @r = \'Foreign key "fk_member_project" is ok.\';');

select @qry as '';

set @_sql_foreign_keys = if(isnull(@old_constraint),
  json_array_append(@_sql_foreign_keys, '$', json_object(
      'table', 'member',
      'name', 'fk_member_project',
      'key_def', '`project`',
      'referenced_table', 'project',
      'f_key_def', '`id`',
      'update', 'RESTRICT',
      'delete', 'RESTRICT'
  )),
  @_sql_foreign_keys
);

set @old_constraint = null;
set @old_table = null;
set @old_key_def = null;
set @old_referenced_table = null;
set @old_f_key_def = null;
select `name` into @old_constraint
from json_table(@_sql_foreign_keys, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`
where
  `table` = 'member' and
  `name` = 'fk_member_user';
set @qry = if (isnull(@old_constraint),
  'ALTER TABLE `sales`.`member` ADD CONSTRAINT `fk_member_user` FOREIGN KEY (`user`) REFERENCES `sales`.`user` (`id`) ON UPDATE RESTRICT ON DELETE RESTRICT;',
  'SET @r = \'Foreign key "fk_member_user" is ok.\';');

select @qry as '';

set @_sql_foreign_keys = if(isnull(@old_constraint),
  json_array_append(@_sql_foreign_keys, '$', json_object(
      'table', 'member',
      'name', 'fk_member_user',
      'key_def', '`user`',
      'referenced_table', 'user',
      'f_key_def', '`id`',
      'update', 'RESTRICT',
      'delete', 'RESTRICT'
  )),
  @_sql_foreign_keys
);

set @all_views = '';

set @all_views = concat(@all_views, '{project_account}');

set @sub_query = null;
select group_concat(concat('`sales`.`', `name`, '`') SEPARATOR ', ')
  into @sub_query
  from json_table(@_sql_views, '$[*]' columns (
        `name` varchar(255) path '$.name'
    )) as `planned_views`
  where instr(@all_views, concat('{', `name`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra view.\';'
,
  concat('DROP VIEW ', @sub_query, ';')
);

select @qry as '';

set @_sql_views = (
  select coalesce(json_arrayagg(json_object(
      'name', `name`
  )), json_array())
  from (
      select *
      from json_table(@_sql_views, '$[*]' columns (
        `name` varchar(255) path '$.name'
    )) as `planned_views`
      where instr(@all_views, concat('{', `name`, '}')) != 0
      order by `name`
  ) as `_sql_ordered_views`
);

set @qry = 'CREATE OR REPLACE VIEW `sales`.`project_account` AS SELECT `project`.`id`, `project`.`name`, `user`.`email` FROM `project` JOIN `member` ON `member`.`project` = `project`.`id` JOIN `user` ON `user`.`id` = `member`.`user`;';

select @qry as '';

set @old_view = null;
select `name` into @old_view
  from json_table(@_sql_views, '$[*]' columns (
        `name` varchar(255) path '$.name'
    )) as `planned_views`
  where `name` = 'project_account';
set @_sql_views = if(isnull(@old_view),
  json_array_append(@_sql_views, '$', json_object(
      'name', 'project_account'
  )),
  @_sql_views
);

set @all_routines = '';

set @all_routines = concat(@all_routines, '{FUNCTION:active_project_count}');

set @all_routines = concat(@all_routines, '{PROCEDURE:archive_project}');

set @sub_query = null;
select group_concat(
    concat('DROP ', `type`, ' `sales`.`', `name`, '`;') SEPARATOR ' ')
  into @sub_query
  from json_table(@_sql_routines, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `type` varchar(32) path '$.type',
        `comment` text path '$.comment'
    )) as `planned_routines`
  where instr(@all_routines, concat('{', `type`, ':', `name`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra routine.\';'
,
  @sub_query
);

select @qry as '';

set @_sql_routines = (
  select coalesce(json_arrayagg(json_object(
      'name', `name`,
      'type', `type`,
      'comment', `comment`
  )), json_array())
  from (
      select *
      from json_table(@_sql_routines, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `type` varchar(32) path '$.type',
        `comment` text path '$.comment'
    )) as `planned_routines`
      where instr(@all_routines, concat('{', `type`, ':', `name`, '}')) != 0
      order by `type`, `name`
  ) as `_sql_ordered_routines`
);

set @old_comment = null;
set @routine_hash = '5efacf6d581c48a8c16eaa4a76cbdcb2388befc801be60d43f0e7820e04bb5bc';
select `comment`
  into @old_comment
  from json_table(@_sql_routines, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `type` varchar(32) path '$.type',
        `comment` text path '$.comment'
    )) as `planned_routines`
  where `type` = 'FUNCTION' and
      `name` = 'active_project_count';
set @routine_changed =
  isnull(@old_comment) or
  if(
      @old_comment regexp 'SQLR_HASH:[0-9a-fA-F]{64}$',
      lower(right(@old_comment, 64)),
      ''
  ) != @routine_hash;
set @qry = if (@routine_changed and not isnull(@old_comment),
  'DROP FUNCTION `sales`.`active_project_count`;'
,
  if(isnull(@old_comment),
    'SET @r = \'Routine active_project_count absence is ok.\';'
  ,
    'SET @r = \'Routine active_project_count is ok.\';'
  )
);

select @qry as '';

set @_sql_routines = if(@routine_changed,
  (
      select coalesce(json_arrayagg(json_object(
          'name', `name`,
          'type', `type`,
          'comment', `comment`
      )), json_array())
      from (
          select *
          from json_table(@_sql_routines, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `type` varchar(32) path '$.type',
        `comment` text path '$.comment'
    )) as `planned_routines`
          where not (`type` = 'FUNCTION' and
              `name` = 'active_project_count')
          order by `type`, `name`
      ) as `_sql_ordered_routines`
  ),
  @_sql_routines
);

set @qry = if (@routine_changed,
  'DELIMITER d5efacf6d581c4
CREATE FUNCTION `sales`.`active_project_count`() RETURNS int DETERMINISTIC READS SQL DATA BEGIN RETURN (SELECT COUNT(*) FROM project WHERE archived = 0); END d5efacf6d581c4
DELIMITER ;'
,
  'SET @r = \'Routine active_project_count is ok.\';'
);

select @qry as '';

set @routine_comment = null;
select `ROUTINE_COMMENT`
  into @routine_comment
  from `INFORMATION_SCHEMA`.`ROUTINES`
  where `ROUTINE_SCHEMA` = 'sales' and
      `ROUTINE_TYPE` = 'FUNCTION' and
      `ROUTINE_NAME` = 'active_project_count';
set @routine_comment = concat(
  regexp_replace(
      ifnull(@routine_comment, ''),
      '\n?SQLR_HASH:[0-9a-fA-F]{64}$',
      ''
  ),
  '\nSQLR_HASH:',
  @routine_hash
);
set @qry = if (@routine_changed,
  concat('ALTER FUNCTION `sales`.`active_project_count` COMMENT ', quote(@routine_comment), ';')
,
  'SET @r = \'Routine comment active_project_count is ok.\';'
);

select @qry as '';

set @_sql_routines = if(@routine_changed,
  json_array_append(@_sql_routines, '$', json_object(
      'name', 'active_project_count',
      'type', 'FUNCTION',
      'comment', @routine_comment
  )),
  @_sql_routines
);

set @old_comment = null;
set @routine_hash = '85b8af341d17c409caff5e5d9d08e86be7d64b14eac20229fd90a93e28aa1569';
select `comment`
  into @old_comment
  from json_table(@_sql_routines, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `type` varchar(32) path '$.type',
        `comment` text path '$.comment'
    )) as `planned_routines`
  where `type` = 'PROCEDURE' and
      `name` = 'archive_project';
set @routine_changed =
  isnull(@old_comment) or
  if(
      @old_comment regexp 'SQLR_HASH:[0-9a-fA-F]{64}$',
      lower(right(@old_comment, 64)),
      ''
  ) != @routine_hash;
set @qry = if (@routine_changed and not isnull(@old_comment),
  'DROP PROCEDURE `sales`.`archive_project`;'
,
  if(isnull(@old_comment),
    'SET @r = \'Routine archive_project absence is ok.\';'
  ,
    'SET @r = \'Routine archive_project is ok.\';'
  )
);

select @qry as '';

set @_sql_routines = if(@routine_changed,
  (
      select coalesce(json_arrayagg(json_object(
          'name', `name`,
          'type', `type`,
          'comment', `comment`
      )), json_array())
      from (
          select *
          from json_table(@_sql_routines, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `type` varchar(32) path '$.type',
        `comment` text path '$.comment'
    )) as `planned_routines`
          where not (`type` = 'PROCEDURE' and
              `name` = 'archive_project')
          order by `type`, `name`
      ) as `_sql_ordered_routines`
  ),
  @_sql_routines
);

set @qry = if (@routine_changed,
  'DELIMITER d85b8af341d17c
CREATE PROCEDURE `sales`.`archive_project`(IN `project_id` int unsigned) MODIFIES SQL DATA SQL SECURITY INVOKER BEGIN UPDATE project SET archived = 1 WHERE id = project_id; END d85b8af341d17c
DELIMITER ;'
,
  'SET @r = \'Routine archive_project is ok.\';'
);

select @qry as '';

set @routine_comment = null;
select `ROUTINE_COMMENT`
  into @routine_comment
  from `INFORMATION_SCHEMA`.`ROUTINES`
  where `ROUTINE_SCHEMA` = 'sales' and
      `ROUTINE_TYPE` = 'PROCEDURE' and
      `ROUTINE_NAME` = 'archive_project';
set @routine_comment = concat(
  regexp_replace(
      ifnull(@routine_comment, ''),
      '\n?SQLR_HASH:[0-9a-fA-F]{64}$',
      ''
  ),
  '\nSQLR_HASH:',
  @routine_hash
);
set @qry = if (@routine_changed,
  concat('ALTER PROCEDURE `sales`.`archive_project` COMMENT ', quote(@routine_comment), ';')
,
  'SET @r = \'Routine comment archive_project is ok.\';'
);

select @qry as '';

set @_sql_routines = if(@routine_changed,
  json_array_append(@_sql_routines, '$', json_object(
      'name', 'archive_project',
      'type', 'PROCEDURE',
      'comment', @routine_comment
  )),
  @_sql_routines
);

set @all_users = '';

set @all_users = concat(@all_users, '{alice}');

set @sub_query = null;
select group_concat(
  if(`type` = 'TABLE',
    concat('REVOKE ', `operations`, ' ON `sales`.`', `subject`, '` FROM ''', `user`, ''';'),
    concat('REVOKE ', `operations`, ' ON ', `type`, ' `sales`.`', `subject`, '` FROM ''', `user`, ''';')
  )
  separator ' '
)
into @sub_query
from json_table(@_sql_permissions, '$[*]' columns (
        `user` varchar(255) path '$.user',
        `type` varchar(32) path '$.type',
        `subject` varchar(255) path '$.subject',
        `operations` text path '$.operations'
    )) as `planned_permissions`
where instr(@all_users, concat('{', `user`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No unlisted user permissions.\';'
,
  @sub_query
);

select @qry as '';

set @_sql_permissions = (
  select coalesce(json_arrayagg(json_object(
      'user', `user`,
      'type', `type`,
      'subject', `subject`,
      'operations', `operations`
  )), json_array())
  from (
      select *
      from json_table(@_sql_permissions, '$[*]' columns (
        `user` varchar(255) path '$.user',
        `type` varchar(32) path '$.type',
        `subject` varchar(255) path '$.subject',
        `operations` text path '$.operations'
    )) as `planned_permissions`
      where instr(@all_users, concat('{', `user`, '}')) != 0
      order by `user`, `type`, `subject`
  ) as `_sql_ordered_permissions`
);

set @old_user = null;
select `name` into @old_user from json_table(@_sql_users, '$[*]' columns (
        `name` varchar(255) path '$.name'
    )) as `planned_users`
where `name` = 'alice';
set @qry = if (isnull(@old_user),
  'CREATE USER \'alice\' ACCOUNT LOCK;'
,
  'SET @r = \'User "alice" exists.\';'
);

select @qry as '';

set @_sql_users = if(isnull(@old_user),
  json_array_append(@_sql_users, '$', json_object(
      'name', 'alice'
  )),
  @_sql_users
);
set @all_grants = '';
set @all_grants = concat(@all_grants, '{TABLE:project}');
set @all_grants = concat(@all_grants, '{TABLE:user}');
set @all_grants = concat(@all_grants, '{TABLE:member}');
set @all_grants = concat(@all_grants, '{TABLE:project_account}');
set @all_grants = concat(@all_grants, '{FUNCTION:active_project_count}');
set @sub_query = null;
select group_concat(`revoke_statement` separator ' ')
into @sub_query
from (
  select concat(
      'REVOKE ', `operations`, ' ON `sales`.`', `subject`, '` FROM \'alice\';'
  ) as `revoke_statement`
  from json_table(@_sql_permissions, '$[*]' columns (
        `user` varchar(255) path '$.user',
        `type` varchar(32) path '$.type',
        `subject` varchar(255) path '$.subject',
        `operations` text path '$.operations'
    )) as `planned_permissions`
  where
      `user` = 'alice' and
      `type` = 'TABLE' and
      instr(@all_grants, concat('{TABLE:', `subject`, '}')) = 0
  union all
  select concat(
      'REVOKE ', `operations`, ' ON ', `type`, ' `sales`.`', `subject`, '` FROM \'alice\';'
  ) as `revoke_statement`
  from json_table(@_sql_permissions, '$[*]' columns (
        `user` varchar(255) path '$.user',
        `type` varchar(32) path '$.type',
        `subject` varchar(255) path '$.subject',
        `operations` text path '$.operations'
    )) as `planned_permissions`
  where
      `user` = 'alice' and
      `type` != 'TABLE' and
      instr(@all_grants, concat('{', `type`, ':', `subject`, '}')) = 0
) `extra_grants`;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra permissions for "alice".\';'
,
  @sub_query
);

select @qry as '';

set @_sql_permissions = (
  select coalesce(json_arrayagg(json_object(
      'user', `user`,
      'type', `type`,
      'subject', `subject`,
      'operations', `operations`
  )), json_array())
  from (
      select *
      from json_table(@_sql_permissions, '$[*]' columns (
        `user` varchar(255) path '$.user',
        `type` varchar(32) path '$.type',
        `subject` varchar(255) path '$.subject',
        `operations` text path '$.operations'
    )) as `planned_permissions`
      where not (
          `user` = 'alice' and
          (
              (`type` = 'TABLE' and instr(@all_grants, concat('{TABLE:', `subject`, '}')) = 0) or
              (`type` != 'TABLE' and instr(@all_grants, concat('{', `type`, ':', `subject`, '}')) = 0)
          )
      )
      order by `user`, `type`, `subject`
  ) as `_sql_ordered_permissions`
);

set @old_grant = null;
select `operations` into @old_grant
from json_table(@_sql_permissions, '$[*]' columns (
        `user` varchar(255) path '$.user',
        `type` varchar(32) path '$.type',
        `subject` varchar(255) path '$.subject',
        `operations` text path '$.operations'
    )) as `planned_permissions`
where
  `user` = 'alice' and
  `type` = 'TABLE' and
  `subject` = 'project';

set @qry = if (@old_grant = 'Select,Insert,Update,Delete',
  'SET @r = \'Grant permissions on "project" for "alice" is ok.\';'
,
  'GRANT Select,Insert,Update,Delete ON `sales`.`project` TO \'alice\';'
);

select @qry as '';

set @_sql_permissions = (
  select coalesce(json_arrayagg(json_object(
      'user', `user`,
      'type', `type`,
      'subject', `subject`,
      'operations', `operations`
  )), json_array())
  from (
      select *
      from json_table(@_sql_permissions, '$[*]' columns (
        `user` varchar(255) path '$.user',
        `type` varchar(32) path '$.type',
        `subject` varchar(255) path '$.subject',
        `operations` text path '$.operations'
    )) as `planned_permissions`
      where not (
          `user` = 'alice' and
          `type` = 'TABLE' and
          `subject` = 'project'
      )
      order by `user`, `type`, `subject`
  ) as `_sql_ordered_permissions`
);

set @_sql_permissions = json_array_append(@_sql_permissions, '$', json_object(
  'user', 'alice',
  'type', 'TABLE',
  'subject', 'project',
  'operations', 'Select,Insert,Update,Delete'
));

set @old_grant = null;
select `operations` into @old_grant
from json_table(@_sql_permissions, '$[*]' columns (
        `user` varchar(255) path '$.user',
        `type` varchar(32) path '$.type',
        `subject` varchar(255) path '$.subject',
        `operations` text path '$.operations'
    )) as `planned_permissions`
where
  `user` = 'alice' and
  `type` = 'TABLE' and
  `subject` = 'user';

set @qry = if (@old_grant = 'Select,Insert,Update,Delete',
  'SET @r = \'Grant permissions on "user" for "alice" is ok.\';'
,
  'GRANT Select,Insert,Update,Delete ON `sales`.`user` TO \'alice\';'
);

select @qry as '';

set @_sql_permissions = (
  select coalesce(json_arrayagg(json_object(
      'user', `user`,
      'type', `type`,
      'subject', `subject`,
      'operations', `operations`
  )), json_array())
  from (
      select *
      from json_table(@_sql_permissions, '$[*]' columns (
        `user` varchar(255) path '$.user',
        `type` varchar(32) path '$.type',
        `subject` varchar(255) path '$.subject',
        `operations` text path '$.operations'
    )) as `planned_permissions`
      where not (
          `user` = 'alice' and
          `type` = 'TABLE' and
          `subject` = 'user'
      )
      order by `user`, `type`, `subject`
  ) as `_sql_ordered_permissions`
);

set @_sql_permissions = json_array_append(@_sql_permissions, '$', json_object(
  'user', 'alice',
  'type', 'TABLE',
  'subject', 'user',
  'operations', 'Select,Insert,Update,Delete'
));

set @old_grant = null;
select `operations` into @old_grant
from json_table(@_sql_permissions, '$[*]' columns (
        `user` varchar(255) path '$.user',
        `type` varchar(32) path '$.type',
        `subject` varchar(255) path '$.subject',
        `operations` text path '$.operations'
    )) as `planned_permissions`
where
  `user` = 'alice' and
  `type` = 'TABLE' and
  `subject` = 'member';

set @qry = if (@old_grant = 'Select,Insert,Update,Delete',
  'SET @r = \'Grant permissions on "member" for "alice" is ok.\';'
,
  'GRANT Select,Insert,Update,Delete ON `sales`.`member` TO \'alice\';'
);

select @qry as '';

set @_sql_permissions = (
  select coalesce(json_arrayagg(json_object(
      'user', `user`,
      'type', `type`,
      'subject', `subject`,
      'operations', `operations`
  )), json_array())
  from (
      select *
      from json_table(@_sql_permissions, '$[*]' columns (
        `user` varchar(255) path '$.user',
        `type` varchar(32) path '$.type',
        `subject` varchar(255) path '$.subject',
        `operations` text path '$.operations'
    )) as `planned_permissions`
      where not (
          `user` = 'alice' and
          `type` = 'TABLE' and
          `subject` = 'member'
      )
      order by `user`, `type`, `subject`
  ) as `_sql_ordered_permissions`
);

set @_sql_permissions = json_array_append(@_sql_permissions, '$', json_object(
  'user', 'alice',
  'type', 'TABLE',
  'subject', 'member',
  'operations', 'Select,Insert,Update,Delete'
));

set @old_grant = null;
select `operations` into @old_grant
from json_table(@_sql_permissions, '$[*]' columns (
        `user` varchar(255) path '$.user',
        `type` varchar(32) path '$.type',
        `subject` varchar(255) path '$.subject',
        `operations` text path '$.operations'
    )) as `planned_permissions`
where
  `user` = 'alice' and
  `type` = 'TABLE' and
  `subject` = 'project_account';

set @qry = if (@old_grant = 'Select',
  'SET @r = \'Grant permissions on "project_account" for "alice" is ok.\';'
,
  'GRANT Select ON `sales`.`project_account` TO \'alice\';'
);

select @qry as '';

set @revoke_operations = '';

set @revoke_operations = if(find_in_set('Insert', ifnull(@old_grant, '')) = 0,
  @revoke_operations,
  if(@revoke_operations = '', 'Insert', concat(@revoke_operations, ',Insert'))
);

set @revoke_operations = if(find_in_set('Update', ifnull(@old_grant, '')) = 0,
  @revoke_operations,
  if(@revoke_operations = '', 'Update', concat(@revoke_operations, ',Update'))
);

set @revoke_operations = if(find_in_set('Delete', ifnull(@old_grant, '')) = 0,
  @revoke_operations,
  if(@revoke_operations = '', 'Delete', concat(@revoke_operations, ',Delete'))
);

set @qry = if (@old_grant = 'Select',
  'SET @r = \'Revoke permissions on "project_account" for "alice" is ok.\';'
,
  if(@revoke_operations = '',
    'SET @r = \'No revoke permissions on project_account for alice needed.\';'
  ,
    concat('REVOKE ', @revoke_operations, ' ON `sales`.`project_account` FROM \'alice\';')
  )
);

select @qry as '';

set @_sql_permissions = (
  select coalesce(json_arrayagg(json_object(
      'user', `user`,
      'type', `type`,
      'subject', `subject`,
      'operations', `operations`
  )), json_array())
  from (
      select *
      from json_table(@_sql_permissions, '$[*]' columns (
        `user` varchar(255) path '$.user',
        `type` varchar(32) path '$.type',
        `subject` varchar(255) path '$.subject',
        `operations` text path '$.operations'
    )) as `planned_permissions`
      where not (
          `user` = 'alice' and
          `type` = 'TABLE' and
          `subject` = 'project_account'
      )
      order by `user`, `type`, `subject`
  ) as `_sql_ordered_permissions`
);

set @_sql_permissions = json_array_append(@_sql_permissions, '$', json_object(
  'user', 'alice',
  'type', 'TABLE',
  'subject', 'project_account',
  'operations', 'Select'
));

set @old_grant = null;
select `operations` into @old_grant
from json_table(@_sql_permissions, '$[*]' columns (
        `user` varchar(255) path '$.user',
        `type` varchar(32) path '$.type',
        `subject` varchar(255) path '$.subject',
        `operations` text path '$.operations'
    )) as `planned_permissions`
where
  `user` = 'alice' and
  `type` = 'FUNCTION' and
  `subject` = 'active_project_count';

set @qry = if (@old_grant = 'Execute',
  'SET @r = \'Grant permissions on "active_project_count" for "alice" is ok.\';'
,
  'GRANT Execute ON FUNCTION `sales`.`active_project_count` TO \'alice\';'
);

select @qry as '';

set @_sql_permissions = (
  select coalesce(json_arrayagg(json_object(
      'user', `user`,
      'type', `type`,
      'subject', `subject`,
      'operations', `operations`
  )), json_array())
  from (
      select *
      from json_table(@_sql_permissions, '$[*]' columns (
        `user` varchar(255) path '$.user',
        `type` varchar(32) path '$.type',
        `subject` varchar(255) path '$.subject',
        `operations` text path '$.operations'
    )) as `planned_permissions`
      where not (
          `user` = 'alice' and
          `type` = 'FUNCTION' and
          `subject` = 'active_project_count'
      )
      order by `user`, `type`, `subject`
  ) as `_sql_ordered_permissions`
);

set @_sql_permissions = json_array_append(@_sql_permissions, '$', json_object(
  'user', 'alice',
  'type', 'FUNCTION',
  'subject', 'active_project_count',
  'operations', 'Execute'
));

