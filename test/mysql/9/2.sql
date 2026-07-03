select if(
  (
    select character_set_name
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'article'
      and column_name = 'title'
  ) = (
    select default_character_set_name
    from information_schema.schemata
    where schema_name = 'demo'
  )
  and (
    select collation_name
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'article'
      and column_name = 'title'
  ) = (
    select default_collation_name
    from information_schema.schemata
    where schema_name = 'demo'
  ),
  'ok',
  'bad removed explicit charset'
);
