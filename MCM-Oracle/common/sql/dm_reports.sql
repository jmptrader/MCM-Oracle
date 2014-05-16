drop index dm_reports.dm_reports_script_id_ind
go

drop table dm_reports
go

create table dm_reports (
  id              int identity primary key,
  label           varchar(30) not null,
  type            varchar(8) not null,
  script_id       int null,
  name            varchar(50) not null,
  directory       varchar(200) null,
  mode            varchar(10) null,
  starttime       int not null,
  endtime         int null,
  size            float null,
  nr_records      int null,
  project         varchar(32) null,
  entity          varchar(6) null,
  runtype         char(1) null,
  business_date   char(8) null
) with identity_gap = 100
go

create index dm_reports_script_id_ind on dm_reports(script_id)
go
