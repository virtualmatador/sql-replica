select if(
  (
    select character_set_name
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'article'
      and column_name = 'title'
  ) = 'latin1'
  and (
    select collation_name
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'article'
      and column_name = 'title'
  ) = (
    select collation_name
    from information_schema.collations
    where character_set_name = 'latin1'
      and is_default = 'Yes'
  ),
  'ok',
  'bad explicit charset'
);
