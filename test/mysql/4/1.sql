call demo.set_value(5, @procedure_result);
select if(
  demo.double_value(6) = 12
  and @procedure_result = 5
  and (
    select count(*)
    from information_schema.routines
    where routine_schema = 'demo'
      and routine_name in ('double_value', 'set_value')
  ) = 2,
  'ok',
  'bad initial routines'
);
