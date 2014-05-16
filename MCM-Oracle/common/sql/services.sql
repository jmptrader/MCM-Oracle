drop table services
go

create table services (
  id                      int identity primary key,
  name                    varchar(30) not null,
  starttime               int not null,
  endtime                 int null,
  service_start_duration  int null,
  service_start_rc        int null,
  post_start_duration     int null,
  post_start_rc           int null,
  pre_stop_duration       int null,
  pre_stop_rc             int null,
  service_stop_duration   int null,
  service_stop_rc         int null,
  business_date           char(8) null
) with identity_gap = 100
go

drop table service_processes
go

create table service_processes (
  service_id              int not null,
  label                   varchar(30) not null,
  hostname                char(8) not null,
  pid                     int not null,
  starttime               int not null,
  endtime                 int null,
  cpu_seconds             int null,
  vsize                   float null
)
go
