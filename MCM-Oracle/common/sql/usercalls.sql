drop index usercalls.usercalls_session_id_ind
go

drop table usercalls
go

create table usercalls (
  session_id      int not null,
  library         varchar(32) not null,
  function        varchar(100) not null,
  ncount          numeric(15) not null,
  cpu             numeric(15) not null, 
  elapsed         numeric(15) not null
)
go

create index usercalls_session_id_ind on usercalls(session_id)
go

alter table sessions add nr_queries numeric(10) null
go
