drop table bct_reports
go

create table bct_reports (
  id              int identity primary key,
  dm_report_id    int not null,
  environment     varchar(6) not null,
  name            varchar(50) null,
  directory       varchar(200) null,
  size            float null,
  nr_records      int null,
  nr_columns      int null,
  separator       char(1) not null,
  timestamp       int not null,
  win_user        char(8) null,
  comment         varchar(200) null
)
go

drop table bct_processes
go

create table bct_processes (
  id              int identity primary key,
  name            varchar(30) not null,
  report_label    varchar(30) not null,
  timestamp       int not null,
  win_user        char(8) null
)
go

drop table bct_excluded
go

create table bct_excluded (
  report_id       int not null,
  process_id      int null,
  column          int not null
)
go

create index bct_excluded_report_id_ind on bct_excluded(report_id)
go

drop table bct_filters
go

create table bct_filters (
  report_id       int not null,
  process_id      int null,
  column          int not null,
  filter          varchar(50) not null
)
go

create index bct_filters_report_id_ind on bct_filters(report_id)
go

drop table bct_sorting
go

create table bct_sorting (
  report_id       int not null,
  process_id      int null,
  column          int not null,
  ascending       char(1) not null,
  ranking         int not null       
)
go

create index bct_sorting_report_id_ind on bct_sorting(report_id)
go

drop table bct_comparisons
go

create table bct_comparisons (
  id                 int identity primary key,
  bct_report_id1     int not null,
  bct_report_id2     int not null,
  max_nr_differences int null,
  win_user           char(8) null,
  starttime          int not null,
  endtime            int null,
  directory          varchar(200) null,
  nr_differences     int null,
  nr_extra_lines1    int null,
  nr_extra_lines2    int null,
  nr_diff_lines      int null
)
go
