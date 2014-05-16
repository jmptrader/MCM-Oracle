drop index runtimes.runtimes_descriptor_ind
go

drop table runtimes
go

create table runtimes (
  id              int identity primary key,
  descriptor      varchar(30) not null,
  starttime       int null,
  endtime         int null,
  duration        int null,
  exitcode        int null
)
go

create index runtimes_descriptor_ind on runtimes(descriptor)
go
