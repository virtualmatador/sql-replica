insert into demo.ticket (id) values (1);
select if(
  (
    select title
    from demo.ticket
    where id = 1
  ) = 'untitled'
  and (
    select status
    from demo.ticket
    where id = 1
  ) = 'open',
  'ok',
  'bad string defaults'
);
