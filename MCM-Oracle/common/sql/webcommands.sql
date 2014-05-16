drop table webcommands
go

create table webcommands (
  id              int identity primary key,
  cmdline         varchar(500) not null,
  pid             int null,
  win_user        char(8) null,
  starttime       int not null,
  business_date   char(8) null
) with identity_gap = 100
go
