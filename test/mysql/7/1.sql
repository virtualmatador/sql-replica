select if(
  (
    select group_concat(column_name order by ordinal_position)
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'metric'
  ) = 'id,tenant_id,metric_day,metric_value,note'
  and (
    select count(*)
    from information_schema.statistics
    where table_schema = 'demo'
      and table_name = 'metric'
      and index_name in ('idx_metric_tenant_day', 'idx_metric_value')
  ) = 3,
  'ok',
  'bad metric setup'
);
