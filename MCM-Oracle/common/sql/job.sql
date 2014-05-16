drop index jobs.jobs_name_ind
go

drop table jobs
go

create table jobs (
  id              int identity primary key,
  name            varchar(30) not null,
  status          varchar(15) not null,
  next_runtime    int null,
  starttime       int null,
  endtime         int null,
  duration        int null,
  exitcode        int null
)
go

create index jobs_name_ind on jobs(name)
go
