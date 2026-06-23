select if(
  (
    select count(*)
    from mysql.user
    where user = 'Alice'
      and account_locked = 'Y'
  ) = 1
  and (
    select count(*)
    from mysql.tables_priv
    where db = 'demo'
      and user = 'Alice'
      and table_name = 'account'
      and table_priv = 'Select,Insert'
  ) = 1,
  'ok',
  'bad initial grants'
);
