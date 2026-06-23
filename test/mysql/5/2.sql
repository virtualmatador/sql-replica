create user Bob account lock;
grant select on demo.account to Bob;
select if(
  (
    select count(*)
    from mysql.user
    where user = 'Alice'
  ) = 1
  and (
    select count(*)
    from mysql.tables_priv
    where db = 'demo'
      and user = 'Alice'
      and table_name = 'account'
      and table_priv = 'Select'
  ) = 1,
  'ok',
  'bad grant update'
);
