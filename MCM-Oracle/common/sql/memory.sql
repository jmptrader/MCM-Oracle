drop index memory.memory_session_id_ind
go
 
drop table memory
go
 
create table memory (
  session_id      int not null,
  timestamp       int not null,
  vsize           numeric(8) not null,
  rss             numeric(8) not null,
  anon            numeric(8) not null
)
go
 
create index memory_session_id_ind on memory(session_id)
go

