drop table tws_jobs
go

create table tws_jobs (
  id              int identity primary key,
  name            varchar(50) not null,
  jobstream       varchar(25) not null,
  username        varchar(10) not null,
  workstation     char(9) not null,
  plantime        char(5) not null,
  command         varchar(250) not null,
  remote          char(1) not null,
  instance        char(1) null,
  nowait          char(1) null,
  project         varchar(32) null,
  scriptname      varchar(50) null,
  timestamp       int not null
)
go

drop table tws_executions
go

create table tws_executions (
  id              int identity primary key,
  tws_job_id      int not null,
  mode            varchar(10) not null,
  starttime       int not null,
  endtime         int null,
  duration        int null,
  exitcode        int null,
  stdout          char(1) null,
  plan_date       char(8) not null,
  tws_date        char(8) not null,
  business_date   char(8) not null
)
go

create index tws_executions_tws_date_ind on tws_executions(tws_date)
go
