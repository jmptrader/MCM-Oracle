drop index feedertables.feedertables_session_id_ind
go

drop table feedertables
go

create table feedertables (
  id              int identity primary key,
  session_id      int not null,
  name            varchar(20) not null,
  batch_name      varchar(50) not null,
  feeder_name     varchar(30) not null,
  entity          varchar(6) null,
  runtype         char(1) null,
  timestamp       int not null,
  job_id          int not null,
  ref_data        int not null,
  nr_records      int not null
)
go

create index feedertables_session_id_ind on feedertables(session_id)
go
