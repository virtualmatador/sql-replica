call demo.set_value(5, @procedure_result);
select if(
  demo.double_value(6) = 12
  and @procedure_result = 5
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
      and Proc_priv = 'Execute'
  ) = 1
  and (
    select count(*)
    from information_schema.routines
    where routine_schema = 'demo'
      and routine_name in ('double_value', 'set_value')
      and routine_comment regexp 'SQLR_HASH:[0-9a-f]{64}$'
  ) = 2,
  'ok',
  'bad initial routines'
);
