select if(
  (
    select count(*)
    from mysql.user
    where user = 'Bob'
  ) = 1
  and (
    select count(*)
    from mysql.tables_priv
    where db = 'demo'
      and user = 'Bob'
  ) = 0
  and (
    select count(*)
    from mysql.tables_priv
    where db = 'demo'
      and user = 'Alice'
      and table_name = 'account'
      and table_priv = 'Select'
  ) = 1,
  'ok',
  'bad unlisted user revoke'
);
