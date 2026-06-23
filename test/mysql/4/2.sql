select if(
  demo.double_value(6) = 18
  and (
    select count(*)
    from information_schema.routines
    where routine_schema = 'demo'
      and routine_name = 'set_value'
  ) = 0,
  'ok',
  'bad routine update'
);
