alter table demo.product add column obsolete int null;
create table demo.extra_product (id int);
select if(
  (
    select count(*)
    from information_schema.tables
    where table_schema = 'demo'
      and table_name = 'product'
      and engine = 'InnoDB'
      and table_comment = 'PRODUCT_TABLE'
  ) = 1
  and (
    select group_concat(column_name order by ordinal_position)
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'product'
      and column_name != 'obsolete'
  ) = 'id,sku,price,note'
  and (
    select count(*)
    from information_schema.statistics
    where table_schema = 'demo'
      and table_name = 'product'
      and index_name = 'idx_product_sku'
      and non_unique = 0
  ) = 1,
  'ok',
  'bad initial product'
);
