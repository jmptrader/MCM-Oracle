alter table blockers add sql_text varchar(3800) null, sql_tag varchar(10) null
go

create table cores (
  id              int identity primary key,
  session_id      int not null,
  pstack_path     varchar(64) not null,
  pmap_path       varchar(64) not null,
  core_path       varchar(64) null,
  hostname        char(8) not null,
  size            float not null,
  timestamp       int not null,
  win_user        char(8) null,
  mx_user         char(10) null,
  mx_group        char(10) null,
  mx_nick         varchar(32) null,
  function        varchar(200) null,
  business_date   char(8) null
) with identity_gap = 100
go

create table dm_filters (
  id              int identity primary key,
  session_id      int not null,
  batch_name      varchar(50) not null,
  dates           varchar(32) null,
  mds             varchar(62) null,
  products        varchar(500) null,
  portfolios      varchar(500) null,
  expression      varchar(30) null
)
go

create index dm_filters_session_id_ind on dm_filters(session_id)
go

create table dm_items (
  session_id       int not null,
  item_ref         int not null
)
go

create index dm_items_session_id_ind on dm_items(session_id)
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

create table dm_scanners (
  id               int identity primary key,
  session_id       int not null,
  nr_engines       int null,
  batch_size       int null,
  nr_retries       int null,
  nr_batches       int null,
  nr_items         int null,
  nr_missing_items int null
)
go

create index dm_scanners_session_id_ind on dm_scanners(session_id)
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

alter table reports modify size float null
go

alter table scripts modify vsize float null
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

alter table sessions add nr_queries numeric(10) null
go

alter table sessions modify vsize float null
go

alter table statements add service_id int null
go

alter table statements add plan_tag varchar(10) null
go

create index statements_service_id_ind on statements(service_id)
go

drop table usercalls
go

create table usercalls (
  session_id      int not null,
  library         varchar(32) not null,
  function        varchar(100) not null,
  ncount          numeric(15) not null,
  cpu             numeric(15) not null, 
  elapsed         numeric(15) not null
)
go

create index usercalls_session_id_ind on usercalls(session_id)
go
