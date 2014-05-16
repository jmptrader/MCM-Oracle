drop table macros
go

create table macros (
  id             int identity primary key,
  name           varchar(16) not null,
  path           varchar(256) not null,
  description    varchar(256) not null,
) with identity_gap = 100
go

drop table macro_runs
go

create table macro_runs (
  id             int identity primary key,
  macro_id       int not null,
) with identity_gap = 100
go

drop table macro_values
go

create table macro_values (
  macro_run_id   int not null,
  placeholder    varchar(64) not null,
  value          varchar(64) null, 
)
go
