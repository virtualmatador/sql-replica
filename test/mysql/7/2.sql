select if(
  (
    select group_concat(column_name order by ordinal_position)
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'metric'
  ) = 'id,metric_day,tenant_id,amount,status,note'
  and (
    select column_type
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'metric'
      and column_name = 'amount'
  ) = 'bigint'
  and (
    select column_default
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'metric'
      and column_name = 'amount'
  ) is null
  and (
    select column_default
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'metric'
      and column_name = 'status'
  ) = '1'
  and (
    select count(*)
    from information_schema.statistics
    where table_schema = 'demo'
      and table_name = 'metric'
      and index_name = 'idx_metric_value'
  ) = 0
  and (
    select group_concat(column_name order by seq_in_index)
    from information_schema.statistics
    where table_schema = 'demo'
      and table_name = 'metric'
      and index_name = 'idx_metric_tenant_day'
  ) = 'metric_day,tenant_id',
  'ok',
  'bad metric reshape'
);
