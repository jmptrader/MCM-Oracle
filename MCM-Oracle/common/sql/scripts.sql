drop table scripts
go

create table scripts (
  id              int identity primary key,
  scriptname      varchar(50) not null,
  path            varchar(128) null,
  cmdline         varchar(500) not null,
  hostname        char(8) not null,
  pid             int not null,
  username        char(8) not null,
  starttime       int null,
  endtime         int null,
  exitcode        int null,
  project         varchar(32) null,
  sched_jobstream varchar(30) null,
  business_date   char(8) null,
  duration        int null,
  killed          char(1) null,
  cpu_seconds     int null,
  vsize           float null,
  logfile         varchar(128) null,
  name            varchar(30) null
) with identity_gap = 100
go
