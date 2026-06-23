select if(
  (
    select count(*)
    from information_schema.tables
    where table_schema = 'demo'
      and table_type = 'BASE TABLE'
      and table_name in ('keep_me', 'remove_me')
  ) = 2,
  'ok',
  'bad null table section'
);
