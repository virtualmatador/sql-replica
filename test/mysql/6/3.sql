select if(
  (
    select count(*)
    from information_schema.tables
    where table_schema = 'demo'
      and table_type = 'BASE TABLE'
  ) = 0,
  'ok',
  'bad empty table section'
);
