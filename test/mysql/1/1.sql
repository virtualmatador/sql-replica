select if(
  (
    select group_concat(column_name order by ordinal_position)
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'account'
  ) = 'id,name',
  'ok',
  'bad columns'
);
