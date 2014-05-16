drop table transfers
go

create table transfers (
  id              int identity primary key,
  hostname        char(8) not null,
  project         varchar(32) null,
  sched_jobstream varchar(30) null,
  entity          varchar(6) null,
  content         varchar(15) null,
  target          varchar(15) null,
  starttime       int null,
  endtime         int null,
  duration        int null,
  filelength      int null,
  reruns          int null,
  killed          char(1) null,
  exitcode        int null,
  cmdline         varchar(500) not null,
  pid             int not null,
  cdpid           int null,
  username        char(8) not null,
  business_date   char(8) null,
  logfile         varchar(128) null,
  cdkeyfile       varchar(128) null
) with identity_gap = 100
go
