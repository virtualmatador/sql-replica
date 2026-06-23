insert into demo.ticket (id, status) values (2, 'closed');
select if(
  (
    select title
    from demo.ticket
    where id = 2
  ) = 'named'
  and (
    select column_default
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'ticket'
      and column_name = 'status'
  ) is null,
  'ok',
  'bad string default update'
);
