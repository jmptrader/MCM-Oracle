drop table blockers
go

create table blockers (
  id              int identity primary key,
  statement_id    int not null,
  spid            smallint not null,
  db_name         varchar(15) not null,
  pid             int null,
  login           varchar(30) null,
  hostname        varchar(30) null,
  application     varchar(30) null,
  tran_name       varchar(64) null,
  cmd             varchar(30) null,
  status          char(12),
  starttime       int not null,
  duration        int not null,
  sql_text        varchar(3800) null,
  sql_tag         varchar(10) null
) with identity_gap = 100
go

create index blockers_statement_id_ind on blockers(statement_id)
go
