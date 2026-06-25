select if(
  demo.double_value(6) = 18
  and (
    select count(*)
    from mysql.procs_priv
    where Db = 'demo'
      and User = 'Runner'
      and Routine_name = 'double_value'
      and Routine_type = 'FUNCTION'
      and Proc_priv = 'Execute'
  ) = 1
  and (
    select count(*)
    from mysql.procs_priv
    where Db = 'demo'
      and User = 'Runner'
      and Routine_name = 'set_value'
      and Routine_type = 'PROCEDURE'
  ) = 0
  and (
    select count(*)
    from information_schema.routines
    where routine_schema = 'demo'
      and routine_name = 'set_value'
  ) = 0,
  'ok',
  'bad routine update'
);
