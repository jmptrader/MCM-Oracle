drop index sessions_ab_session_id_ind;

drop table sessions;

drop sequence sessions_seq;

create table sessions (
  id              int primary key,
  hostname        char(8) not null,
  cmdline         varchar(3600) not null,
  req_starttime   int null,
  mx_starttime    int null,
  mx_endtime      int null,
  req_endtime     int null,
  mx_scripttype   varchar(16) null,
  mx_scriptname   varchar(30) null,
  win_user        varchar(30) null,
  mx_user         char(10) null,
  mx_group        char(10) null,
  mx_client_host  char(16) null,
  exitcode        int null,
  ab_session_id   int null,
  runtime         int null,
  cputime         int null,
  iotime          int null,
  pid             int null,
  corefile        varchar(64) null,
  sched_jobstream varchar(30) null,
  entity          varchar(6) null,
  runtype         char(1) null,
  business_date   char(8) null,
  duration        int null,
  mx_nick         varchar(32) null,
  project         varchar(32) null,
  reruns          int null,
  killed          char(1) null,
  start_delay     int null,
  cpu_seconds     int null,
  vsize           float null,
  remote_delay    int null,
  nr_queries      numeric(10) null
);

create sequence sessions_seq start with 1;

create index sessions_ab_session_id_ind on sessions(ab_session_id);

drop table session_count;

create table session_count (
  win_user        varchar(30) null,
  hostname        char(8) null,
  ncount          int not null,
  mx_scripttype   varchar(16) null
);

drop index runtimes_descriptor_ind;

drop table runtimes;

drop sequence runtimes_seq;

create table runtimes (
  id              int primary key,
  descriptor      varchar(30) not null,
  starttime       int null,
  endtime         int null,
  duration        int null,
  exitcode        int null
);

create sequence runtimes_seq start with 1;

create index runtimes_descriptor_ind on runtimes(descriptor);

drop index jobs_name_ind;

drop table jobs;

drop sequence jobs_seq;

create table jobs (
  id              int primary key,
  name            varchar(30) not null,
  status          varchar(15) not null,
  next_runtime    int null,
  starttime       int null,
  endtime         int null,
  duration        int null,
  exitcode        int null
);

create sequence jobs_seq start with 1;

create index jobs_name_ind on jobs(name);

drop table tasks;

drop sequence tasks_seq;

create table tasks (
  id              int primary key,
  hostname        char(8) not null,
  cmdline         varchar(512) not null,
  starttime       int null,
  endtime         int null,
  name            varchar(30) null,
  exitcode        int null,
  logfile         varchar(128) null,
  xmlfile         varchar(128) null,
  sched_jobstream varchar(30) null,
  pid             int null,
  business_date   char(8) null,
  duration        int null
);

create sequence tasks_seq start with 1;

drop index reports_session_id_ind;

drop table reports;

drop sequence reports_seq;

create table reports (
  id              int primary key,
  label           varchar(30) not null,
  type            varchar(8) not null,
  session_id      int null,
  batchname       varchar(30) null,
  reportname      varchar(30) null,
  entity          varchar(6) null,
  runtype         char(1) null,
  mds             varchar(20) null,
  starttime       int not null,
  endtime         int null,
  rsize           float null,
  nr_records      int null,
  tablename       varchar(50) null,
  path            varchar(200) null,
  business_date   char(8) null,
  duration        int null,
  ab_session_id   int null,
  command         varchar(200) null,
  exitcode        int null,
  cduration       int null,
  status          char(1) not null,
  compressed      char(1) not null,
  archived        char(1) not null,
  filter          varchar(20) null,
  project         varchar(32) null
);

create sequence reports_seq start with 1;

create index reports_session_id_ind on reports(session_id);

drop index timings_session_id_ind;

drop table timings;

create table timings (
  session_id      int not null,
  timestamp       int not null,
  id              int not null,
  context         varchar(30) null,
  command         varchar(30) null,
  elapsed         decimal(10,2) not null,
  cpu             decimal(10,2) not null,
  rdb             decimal(10,2) not null
);

create index timings_session_id_ind on timings(session_id);

drop index performance_session_id_ind;

drop table performance;

create table performance (
  session_id      int not null,
  timestamp       int not null,
  usr             decimal(5,2) not null,
  sys             decimal(5,2) not null,
  trp             decimal(5,2) not null,
  tfl             decimal(5,2) not null,
  dfl             decimal(5,2) not null,
  lck             decimal(5,2) not null,
  slp             decimal(5,2) not null,
  lat             decimal(5,2) not null,
  vcx             int not null,
  icx             int not null,
  scl             int not null
);

create index performance_session_id_ind on performance(session_id);

drop index memory_session_id_ind;

drop table memory;

create table memory (
  session_id      int not null,
  timestamp       int not null,
  vsize           numeric(8) not null,
  rss             numeric(8) not null,
  anon            numeric(8) not null
);

create index memory_session_id_ind on memory(session_id);

drop index syscalls_session_id_ind;

drop table syscalls;

create table syscalls (
  session_id      int not null,
  name            varchar(32) not null,
  elapsed         numeric(15) null,
  cpu             numeric(15) null,
  ncount          numeric(15) null
);

create index syscalls_session_id_ind on syscalls(session_id);

drop index usercalls_session_id_ind;

drop table usercalls;

create table usercalls (
  session_id      int not null,
  library         varchar(32) not null,
  function        varchar(100) not null,
  ncount          numeric(15) not null,
  cpu             numeric(15) not null,
  elapsed         numeric(15) not null
);

create index usercalls_session_id_ind on usercalls(session_id);

drop index sqltrace_session_id_ind;

drop table sqltrace;

create table sqltrace (
  session_id      int not null,
  name            varchar(100) not null,
  tot_duration    numeric(10) not null,
  avg_duration    numeric(10) not null,
  type            varchar(6) not null,
  ncount          numeric(7) not null,
  percentage      decimal(5,2) not null
);

create index sqltrace_session_id_ind on sqltrace(session_id);

drop index sqlio_session_id_ind;

drop table sqlio;

create table sqlio (
  session_id      int not null,
  name            varchar(100) not null,
  logical         numeric(10) not null,
  physical        numeric(10) not null
);

create index sqlio_session_id_ind on sqlio(session_id);

drop index sybase_session_id_ind;

drop table sybase;

create table sybase (
  session_id      int not null,
  timestamp       int not null,
  cpu             int,
  io              int,
  mem             int
);

create index sybase_session_id_ind on sybase(session_id);

drop table logfiles;

drop sequence logfiles_seq;

create table logfiles (
  id              int primary key, 
  timestamp       int not null,
  filename        varchar(256) not null,
  type            varchar(8) not null,
  extract         varchar(2000) null,
  start_pos       int null,
  length          int null
);

create sequence logfiles_seq start with 1;

drop table mxtables;

create table mxtables (
  name            varchar(30) not null,
  nr_rows         int not null,
  data            int not null,
  indexes         int not null,
  lobs            int not null,
  lobindexes      int not null,
  total_size      int not null,
  growth_rate     numeric(8,2) null,
  schema          varchar(15) not null
);

create index mxtables_schema_ind on mxtables(schema);

drop table mxtables_hist;

create table mxtables_hist (
  timestamp       char(8) not null,
  name            varchar(30) not null,
  nr_rows         int not null,
  total_size      int not null,
  schema          varchar(15) not null
);

drop table mxtables_category;

create table mxtables_category (
  name            varchar(30) not null,
  schema          varchar(15) not null,
  category        varchar(20) null
);

create index mxtables_hist_schema_ind on mxtables_hist(schema);

drop table mxml_nodes;

drop sequence mxml_nodes_seq;

create table mxml_nodes (
  id               char(8) primary key,
  nodename         varchar(50) not null,
  in_out           char(1) not null,
  taskname         varchar(50) not null,
  tasktype         varchar(50) not null,
  sheetname        varchar(50) not null,
  workflow         varchar(50) null,
  target_task      varchar(50) null,
  msg_taken_y      int null,
  msg_taken_n      int null,
  proc_time        int null
);

create sequence mxml_nodes_seq start with 1;

drop table mxml_tasks;

drop sequence mxml_tasks_seq;

create table mxml_tasks (
  taskname         varchar(50) not null,
  tasktype         varchar(50) not null,
  sheetname        varchar(50) not null,
  workflow         varchar(50) null,
  unblocked        char(1) null,
  loading_data     char(1) null,
  started          char(1) null,
  status           varchar(15) not null,
  timestamp        int not null
);

create sequence mxml_tasks_seq start with 1;

drop table mxml_links;

create table mxml_links (
  id               char(8) not null,
  target_task      varchar(50) null
);

drop table mxml_directories;

create table mxml_directories (
  taskname         varchar(50) not null,
  received         varchar(200) null,
  error            varchar(200) null
);

drop index mxml_nodes_hist_ind;

drop table mxml_nodes_hist;

create table mxml_nodes_hist (
  id              char(8),
  timestamp       int not null,
  msg_taken_n     int not null
);

create index mxml_nodes_hist_ind on mxml_nodes_hist(id, timestamp);

drop index alerts_name_ind;
 
drop table alerts;

drop sequence alerts_seq;
 
create table alerts (
  id                int primary key,
  timestamp         int not null,
  name              varchar(20) not null,
  item              varchar(50) null,
  category          varchar(20) not null,
  wlevel            varchar(8) not null,
  message           varchar(200) null,
  business_date     char(8) not null,
  ack_received      char(1) null,
  ack_timestamp     int null,
  ack_user          char(8) null,
  trigger_count     int null,
  trigger_timestamp int null,
  logfile           varchar(128) null
);

create sequence alerts_seq start with 1;
 
create index alerts_name_ind on alerts(name);

drop table indexes;

create table indexes (
  name              varchar(30) not null,
  ntable            varchar(30) not null,
  ndatabase         varchar(30) not null,
  id                int not null,
  index_id          smallint not null,
  nr_keys           smallint not null
);

drop table messages;

drop sequence messages_seq;

create table messages (
  id              int primary key,
  type            varchar(16) not null,
  priority        varchar(8) not null,
  environment     varchar(16) not null,
  destination     varchar(16) not null,
  timestamp       int not null,
  validity        int not null,
  message         varchar(100) not null,
  processed       char(1) not null
);

create sequence messages_seq start with 1;

drop table message_delivery;

drop sequence message_delivery_seq;

create table message_delivery (
  id              int primary key,
  message_id      int not null,
  username        varchar(30) not null,
  delivered       char(1) not null,
  delivery_ts     int not null,
  confirmation_ts int null
);

create sequence message_delivery_seq start with 1;

drop table scripts;

drop sequence scripts_seq;

create table scripts (
  id              int primary key,
  scriptname      varchar(50) not null,
  path            varchar(128) null,
  cmdline         varchar(500) not null,
  hostname        char(8) not null,
  pid             int not null,
  username        char(8) not null,
  starttime       int null,
  endtime         int null,
  exitcode        int null,
  project         varchar(32) null,
  sched_jobstream varchar(30) null,
  business_date   char(8) null,
  duration        int null,
  killed          char(1) null,
  cpu_seconds     int null,
  vsize           float null,
  logfile         varchar(128) null,
  name            varchar(30) null
);

create sequence scripts_seq start with 1;

drop table transfers;

drop sequence transfers_seq;

create table transfers (
  id              int primary key,
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
);

create sequence transfers_seq start with 1;

drop table statements;

drop sequence statements_seq;

create table statements (
  id              int primary key,
  session_id      int null,
  script_id       int null,
  service_id      int null,
  schema          varchar(30) not null,
  username        varchar(30) not null,
  sid             int not null,
  hostname        varchar(64) null,
  osuser          varchar(30) null,
  pid             int null,
  program         varchar(48) null,
  command         varchar(64) null,
  starttime       int not null,
  endtime         int null,
  duration        int null,
  cpu             int null,
  wait_time       int null,
  logical_reads   int null,
  physical_reads  int null,
  physical_writes int null,
  sql_text        blob,
  bind_values     blob,
  sql_tag         varchar(20) null,
  plan_tag        varchar(10) null,
  business_date   char(8) null
);

create sequence statements_seq start with 1;

create index statements_session_id_ind on statements(session_id);

create index statements_script_id_ind on statements(script_id);

create index statements_service_id_ind on statements(service_id);

create index statements_sql_tag_ind on statements(sql_tag);

create index statements_plan_tag_ind on statements(plan_tag);

drop table blockers;

drop sequence blockers_seq;

create table blockers (
  id              int primary key,
  statement_id    int not null,
  spid            smallint not null,
  db_name         varchar(15) not null,
  pid             int null,
  login           varchar(30) null,
  hostname        varchar(30) null,
  application     varchar(30) null,
  tran_name       varchar(64) null,
  cmd             varchar(30) null,
  status          char(12),
  starttime       int not null,
  duration        int not null,
  sql_text        varchar(3800) null,
  sql_tag         varchar(10) null,
  business_date   char(8) null
);

create sequence blockers_seq start with 1;

create index blockers_statement_id_ind on blockers(statement_id);

drop table statement_waits;

create table statement_waits (
  statement_id    int not null,
  event_id        smallint not null,
  nr_waits        int not null,
  wait_time       int not null
);

create index statement_waits_id_ind on statement_waits(statement_id);

drop table wait_event_info;

create table wait_event_info (
  event_id        smallint not null,
  description     varchar(50)
);

-- insert into wait_event_info ( event_id, description ) select WaitEventID, Description from  master..monWaitEventInfo

drop index dm_reports_script_id_ind;

drop table dm_reports;

drop sequence dm_reports_seq;

create table dm_reports (
  id              int primary key,
  label           varchar(30) not null,
  type            varchar(8) not null,
  script_id       int null,
  name            varchar(50) not null,
  directory       varchar(200) null,
  rmode           varchar(10) null,
  starttime       int not null,
  endtime         int null,
  rsize           float null,
  nr_records      int null,
  project         varchar(32) null,
  entity          varchar(6) null,
  runtype         char(1) null,
  business_date   char(8) null
);

create sequence dm_reports_seq start with 1;

create index dm_reports_script_id_ind on dm_reports(script_id);

drop index feedertables_session_id_ind;

drop table feedertables;

drop sequence feedertables_seq;

create table feedertables (
  id              int primary key,
  session_id      int not null,
  name            varchar(20) not null,
  batch_name      varchar(50) not null,
  feeder_name     varchar(30) not null,
  entity          varchar(6) null,
  runtype         char(1) null,
  timestamp       int not null,
  job_id          int not null,
  ref_data        int not null,
  nr_records      int not null,
  tabletype       varchar(10) null
);

create sequence feedertables_seq start with 1;

create index feedertables_session_id_ind on feedertables(session_id);

drop index dm_filters_session_id_ind;

drop table dm_filters;

drop sequence dm_filters_seq;

create table dm_filters (
  id              int primary key,
  session_id      int not null,
  batch_name      varchar(50) not null,
  dates           varchar(32) null,
  mds             varchar(62) null,
  products        varchar(500) null,
  portfolios      varchar(500) null,
  expression      varchar(30) null
);

create sequence dm_filters_seq start with 1;

create index dm_filters_session_id_ind on dm_filters(session_id);

drop index dm_scanners_session_id_ind;

drop table dm_scanners;

drop sequence dm_scanners_seq;

create table dm_scanners (
  id                int primary key,
  session_id        int not null,
  nr_engines        int null,
  batch_size        int null,
  nr_retries        int null,
  nr_batches        int null,
  nr_items          int null,
  nr_missing_items  int null,
  nr_table_records  int null,
  total_runtime     int null,
  total_cputime     int null,
  total_iotime      int null,
  total_cpu_seconds int null
);

create sequence dm_scanners_seq start with 1;

create index dm_scanners_session_id_ind on dm_scanners(session_id);

drop index dm_items_session_id_ind;

drop table dm_items;

create table dm_items (
  session_id       int not null,
  item_ref         int not null
);

create index dm_items_session_id_ind on dm_items(session_id);

drop table cores;

drop sequence cores_seq;

create table cores (
  id              int primary key,
  session_id      int not null,
  pstack_path     varchar(64) not null,
  pmap_path       varchar(64) not null,
  core_path       varchar(64) null,
  hostname        char(8) not null,
  csize           float not null,
  timestamp       int not null,
  win_user        char(8) null,
  mx_user         char(10) null,
  mx_group        char(10) null,
  mx_nick         varchar(32) null,
  function        varchar(200) null,
  business_date   char(8) null
);

create sequence cores_seq start with 1;

drop table services;

drop sequence services_seq;

create table services (
  id                      int primary key,
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
);

create sequence services_seq start with 1;

drop table service_processes;

drop sequence service_processes_seq;

create table service_processes (
  service_id              int not null,
  label                   varchar(30) not null,
  hostname                char(8) not null,
  pid                     int not null,
  starttime               int not null,
  endtime                 int null,
  cpu_seconds             int null,
  vsize                   float null
);

create sequence service_processes_seq start with 1;

drop table webcommands;

drop sequence webcommands_seq;

create table webcommands (
  id              int primary key,
  cmdline         varchar(500) not null,
  pid             int null,
  win_user        char(8) null,
  starttime       int not null,
  business_date   char(8) null
);

create sequence webcommands_seq start with 1;

drop table md_uploads;

create table md_uploads (
  id              int primary key,
  timestamp       int not null,
  type            varchar(15) null,
  channel         varchar(15) not null,
  status          varchar(15) null,
  nr_not_imported int null,
  xml_path        varchar(128) null,
  xml_size        int null,
  win_user        char(8) null,
  md_group        varchar(15) null,
  action          varchar(15) null,
  md_date         char(8) null,
  mds             varchar(20) null,
  script_id       int null,
  session_id      int null
);

drop table md_pairs;

create table md_pairs (
  name            char(7) not null,
  upload_id       int not null
);

drop table tws_jobs;

create table tws_jobs (
  id              int primary key,
  name            varchar(50) not null,
  jobstream       varchar(25) not null,
  username        varchar(10) not null,
  workstation     char(9) not null,
  plantime        char(5) not null,
  command         varchar(250) not null,
  remote          char(1) not null,
  instance        char(1) null,
  no_wait         char(1) null,
  project         varchar(32) null,
  scriptname      varchar(50) null,
  timestamp       int not null
);

drop table tws_executions;

create table tws_executions (
  id              int primary key,
  tws_job_id      int not null,
  tmode           varchar(10) not null,
  starttime       int not null,
  endtime         int null,
  duration        int null,
  exitcode        int null,
  stdout          char(1) null,
  plan_date       char(8) not null,
  tws_date        char(8) not null,
  business_date   char(8) not null,
  job_nr          varchar(8) null
);

create index tws_executions_tws_date_ind on tws_executions(tws_date);

drop table resourcepool;

create table resourcepool (
  resourcename   varchar(20) primary key,
  initial_size   numeric(10,2) not null,
  available      numeric(10,2) not null
);

drop table ctrlm_jobs;

drop sequence ctrlm_jobs_seq;

create table ctrlm_jobs (
  id                int primary key,
  tablename         varchar(40) not null,
  name              varchar(40) not null,
  job_type          varchar(15) not null,
  task_type         varchar(8) not null,
  ngroup            varchar(40) not null,
  owner             varchar(40) not null,
  node_id           varchar(40) not null,
  description       varchar(100) null,
  nr_in_conditions  int not null,
  nr_out_conditions int not null,
  nr_err_conditions int not null,
  nr_resources      int not null
);

create sequence ctrlm_jobs_seq start with 1;

drop table ctrlm_tables;

drop sequence ctrlm_tables_seq;

create table ctrlm_tables (
  id                int primary key,
  name              varchar(40) not null,
  nr_jobs           int not null,
  nr_in_conditions  int not null,
  nr_out_conditions int not null,
  nr_err_conditions int not null
);

create sequence ctrlm_tables_seq start with 1;

