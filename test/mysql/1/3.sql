select if(
  (
    select count(*)
    from information_schema.tables
    where table_schema = 'demo'
      and table_name = 'person'
      and table_comment = 'ACCOUNT_TABLE'
  ) = 1
  and (
    select count(*)
    from information_schema.tables
    where table_schema = 'demo'
      and table_name = 'customer'
  ) = 0
  and (
    select group_concat(column_name order by ordinal_position)
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'person'
  ) = 'id,full_name'
  and (
    select full_name
    from demo.person
    where id = 1
  ) = 'saved name',
  'ok',
  'bad data-preserving rename'
);
