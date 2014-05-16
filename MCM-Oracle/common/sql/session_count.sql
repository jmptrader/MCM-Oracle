drop table session_count
go

create table session_count (
  win_user        char(8) not null,
  hostname        char(8) not null,
  ncount          int not null
)
go
