select if(
  (
    select count(*)
    from information_schema.referential_constraints
    where constraint_schema = 'demo'
      and constraint_name = 'fk_project_account'
      and table_name = 'project'
      and referenced_table_name = 'account'
      and update_rule = 'RESTRICT'
      and delete_rule = 'RESTRICT'
  ) = 1
  and (
    select count(*)
    from information_schema.views
    where table_schema = 'demo'
      and table_name = 'project_account'
  ) = 1,
  'ok',
  'bad initial fk view'
);
