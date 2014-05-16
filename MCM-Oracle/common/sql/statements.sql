drop table statements
go

create table statements (
  id              int identity primary key,
  session_id      int null,
  script_id       int null,
  service_id      int null,
  spid            smallint not null,
  db_name         varchar(15) not null,
  pid             int null,
  login           varchar(30) null,
  hostname        varchar(30) null,
  application     varchar(30) null,
  starttime       int not null,
  endtime         int null,
  duration        int null,
  cpu_time        int null,
  wait_time       int null,
  logical_reads   int null,
  physical_reads  int null,
  sql_text        varchar(3800) null,
  sql_tag         varchar(10) null,
  full_table_scan char(1) null,
  business_date   char(8) null
) with identity_gap = 100
go

create index statements_session_id_ind on statements(session_id)
go

create index statements_script_id_ind on statements(script_id)
go

create index statements_service_id_ind on statements(service_id)
go
