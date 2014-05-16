drop table cores
go

create table cores (
  id              int identity primary key,
  session_id      int not null,
  pstack_path     varchar(64) not null,
  pmap_path       varchar(64) not null,
  core_path       varchar(64) null,
  hostname        char(8) not null,
  size            float not null,
  timestamp       int not null,
  win_user        char(8) null,
  mx_user         char(10) null,
  mx_group        char(10) null,
  mx_nick         varchar(32) null,
  function        varchar(200) null,
  business_date   char(8) null
) with identity_gap = 100
go
