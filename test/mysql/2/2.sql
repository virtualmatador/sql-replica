select if(
  (
    select count(*)
    from information_schema.tables
    where table_schema = 'demo'
      and table_name = 'item'
      and table_comment = 'PRODUCT_TABLE'
  ) = 1
  and (
    select count(*)
    from information_schema.tables
    where table_schema = 'demo'
      and table_name in ('product', 'extra_product')
  ) = 0
  and (
    select group_concat(column_name order by ordinal_position)
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'item'
  ) = 'id,code,price,description'
  and (
    select column_type
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'item'
      and column_name = 'code'
  ) = 'varchar(48)'
  and (
    select column_default
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'item'
      and column_name = 'price'
  ) = '7'
  and (
    select count(*)
    from information_schema.statistics
    where table_schema = 'demo'
      and table_name = 'item'
      and index_name = 'idx_item_code'
      and non_unique = 1
  ) = 1,
  'ok',
  'bad product reshape'
);
