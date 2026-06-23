insert into demo.customer (display_name) values ('saved name');
select if(
  (
    select count(*)
    from information_schema.tables
    where table_schema = 'demo'
      and table_name = 'customer'
      and table_comment = 'ACCOUNT_TABLE'
  ) = 1
  and (
    select count(*)
    from information_schema.tables
    where table_schema = 'demo'
      and table_name = 'account'
  ) = 0
  and (
    select group_concat(column_name order by ordinal_position)
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'customer'
  ) = 'id,display_name',
  'ok',
  'bad rename'
);
