select if(
  (
    select count(*)
    from information_schema.tables
    where table_schema = 'demo'
      and table_name = 'owner'
      and table_comment = 'ACCOUNT_TABLE'
  ) = 1
  and (
    select count(*)
    from information_schema.tables
    where table_schema = 'demo'
      and table_name in ('account', 'project_account')
  ) = 0
  and (
    select group_concat(column_name order by ordinal_position)
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'owner'
  ) = 'owner_id,display_name'
  and (
    select count(*)
    from information_schema.referential_constraints
    where constraint_schema = 'demo'
      and constraint_name = 'fk_project_owner'
      and table_name = 'project'
      and referenced_table_name = 'owner'
      and update_rule = 'CASCADE'
      and delete_rule = 'CASCADE'
  ) = 1,
  'ok',
  'bad fk rename'
);
