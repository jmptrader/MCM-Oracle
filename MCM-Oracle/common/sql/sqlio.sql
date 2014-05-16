drop index sqlio.sqlio_session_id_ind
go
 
drop table sqlio
go
 
create table sqlio (
  session_id      int not null,
  name            varchar(100) not null,
  logical         numeric(10) not null,
  physical        numeric(10) not null
)
go
 
create index sqlio_session_id_ind on sqlio(session_id)
go
