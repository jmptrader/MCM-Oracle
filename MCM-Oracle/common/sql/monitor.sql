drop index sessions.sessions_ab_session_id_ind
go

drop table sessions
go

create table sessions (
  id              int identity primary key,
  hostname        char(8) not null,
  cmdline         varchar(3600) not null,
  req_starttime   int null,
  mx_starttime    int null,
  mx_endtime      int null,
  req_endtime     int null,
  mx_scripttype   varchar(16) null,
  mx_scriptname   varchar(30) null,
  win_user        char(30) null,
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
) with identity_gap = 100
go

create index sessions_ab_session_id_ind on sessions(ab_session_id)
go

drop table session_count
go

create table session_count (
  win_user        char(8) not null,
  hostname        char(8) null,
  ncount          int not null,
  mx_scripttype   varchar(16) null
) 
go

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

drop table tasks
go

create table tasks (
  id              int identity primary key,
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
  duration        int null,
) with identity_gap = 100
go

drop index reports.reports_session_id_ind
go

drop table reports
go

create table reports (
  id              int identity primary key,
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
  size            float null,
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
  project         varchar(32) null, 
) with identity_gap = 100
go

create index reports_session_id_ind on reports(session_id)
go

drop index timings.timings_session_id_ind
go

drop table timings
go

create table timings (
  session_id      int not null,
  timestamp       int not null,
  id              int not null,
  context         varchar(30) null,
  command         varchar(30) null,
  elapsed         decimal(10,2) not null,
  cpu             decimal(10,2) not null,
  rdb             decimal(10,2) not null
)
go

create index timings_session_id_ind on timings(session_id)
go

drop index performance.performance_session_id_ind
go

drop table performance
go

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
)
go

create index performance_session_id_ind on performance(session_id)
go

drop index memory.memory_session_id_ind
go

drop table memory
go

create table memory (
  session_id      int not null,
  timestamp       int not null,
  vsize           numeric(8) not null,
  rss             numeric(8) not null,
  anon            numeric(8) not null
)
go

create index memory_session_id_ind on memory(session_id)
go

drop index syscalls.syscalls_session_id_ind
go

drop table syscalls
go

create table syscalls (
  session_id      int not null,
  name            varchar(32) not null,
  elapsed         numeric(15) null,
  cpu             numeric(15) null,
  ncount          numeric(15) null
)
go

create index syscalls_session_id_ind on syscalls(session_id)
go

drop index usercalls.usercalls_session_id_ind
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

drop index sqltrace.sqltrace_session_id_ind
go

drop table sqltrace
go

create table sqltrace (
  session_id      int not null,
  name            varchar(100) not null,
  tot_duration    numeric(10) not null,
  avg_duration    numeric(10) not null,
  type            varchar(6) not null,
  ncount          numeric(7) not null,
  percentage      decimal(5,2) not null
)
go 

create index sqltrace_session_id_ind on sqltrace(session_id)
go

drop index sqlio.sqlio_session_id_ind
go

drop table sqlio
go

create table sqlio (
  session_id      int not null,
  name            varchar(100) not null,
  logical         numeric(10) not null,
  physical        numeric(10) not null
)
go

create index sqlio_session_id_ind on sqlio(session_id)
go

drop index sybase.sybase_session_id_ind
go

drop table sybase
go

create table sybase (
  session_id      int not null,
  timestamp       int not null,
  cpu             int,
  io              int,
  mem             int
)
go

create index sybase_session_id_ind on sybase(session_id)
go

drop table logfiles
go

create table logfiles (
  id              int identity primary key, 
  timestamp       int not null,
  filename        varchar(100) not null,
  type            varchar(8) not null,
  extract         varchar(2000) null,
  start_pos       int null,
  length          int null
)
go

drop table mxtables
go

create table mxtables (
  name            varchar(30) not null,
  nr_rows         int not null,
  data            int not null,
  indexes         int not null,
  unused          int not null,
  reserved        int not null,
  growth_rate     numeric(8,2) null,
  db_name         varchar(15) not null
)
go

create index mxtables_db_name_ind on mxtables(db_name)
go

drop table mxtables_hist
go

create table mxtables_hist (
  timestamp       char(8) not null,
  name            varchar(30) not null,
  nr_rows         int not null,
  reserved        int not null,
  db_name         varchar(15) not null
)
go

drop table mxtables_category
go

create table mxtables_category (
  name            varchar(30) not null,
  db_name         varchar(15) not null,
  category        varchar(20) null
)
go

create index mxtables_hist_db_name_ind on mxtables_hist(db_name)
go

drop table mxml_nodes
go

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
)
go

drop table mxml_tasks
go

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
)
go

drop table mxml_links
go

create table mxml_links (
  id               char(8) not null,
  target_task      varchar(50) null
)
go

drop table mxml_directories
go

create table mxml_directories (
  taskname         varchar(50) not null,
  received         varchar(200) null,
  error            varchar(200) null
)
go

drop index mxml_nodes_hist.mxml_nodes_hist_ind
go

drop table mxml_nodes_hist
go

create table mxml_nodes_hist (
  id              char(8),
  timestamp       int not null,
  msg_taken_n     int not null
)
go

create index mxml_nodes_hist_ind on mxml_nodes_hist(id, timestamp)
go

drop table ab_sessions
go

create table ab_sessions (
  id              int identity primary key, 
  hostname        char(8) not null,
  cmdline         varchar(3600) not null,
  starttime       int not null,
  endtime         int null,
  nr_books_ok     int null,
  nr_books_nok    int null,
  business_date   char(8) null,
  duration        int null,
  sched_jobstream varchar(30) null,
  batchname       varchar(16) null,
  pid             int null,
) with identity_gap = 100
go

drop index ab_books.ab_books_ab_session_id_ind
go

drop table ab_books
go

create table ab_books (
  id              int identity primary key,
  book            varchar(30) not null,
  batch           varchar(16) not null,
  ab_session_id   int not null,
  starttime       int null,
  endtime         int null,
  runtime         int null,
  nr_runs         int null,
  status          char(8) not null,
  report_id       int null,
  reference       varchar(30) not null,
  est_runtime     int null
)
go

create index ab_books_ab_session_id_ind on ab_books(ab_session_id)
go

drop table ab_books_sessions
go

create table ab_books_sessions (
  book_id         int not null,
  session_id      int not null
)
go 

go

drop index tws_dependencies.reference_id_ind
go

drop index tws_dependencies.type_ind
go

drop table tws_dependencies
go

create table tws_dependencies (
  reference_id	varchar(75),
  type		varchar(25),
  dependent_id	varchar(75)
)
go

create index reference_id_ind on tws_dependencies(reference_id)
go

create index type_ind on tws_dependencies(type)
go

drop table tws_jobs
go

create table tws_jobs (
  id		varchar(50) primary key,
  command 	varchar(250), 
  description 	varchar(50) null,
  ecar 		varchar(10) null
)
go

drop table tws_streams
go

create table tws_streams (
  id 			varchar(25) primary key,
  branch 		char(2) null,
  postfix 		varchar(10) null,
  run 			char(1) null,
  priority 		int null,
  resource_name 	varchar(10) null,
  resource_value 	int null,
  development_server 	varchar(10) null,
  integration_server 	varchar(10) null,
  acceptance_server 	varchar(10) null,
  production_server 	varchar(10) null
)
go

drop index tws_stream_jobs.stream_id_ind
go

drop index tws_stream_jobs.job_id_ind
go

drop table tws_stream_jobs
go

create table tws_stream_jobs (
  stream_id 			varchar(25) not null,
  job_id 			varchar(50) not null,
  run_as_user 			varchar(10) null,
  run_on_working_day_1 		char(1) DEFAULT 'Y' not null,
  run_on_working_day_2 		char(1) DEFAULT 'Y' not null,
  run_on_working_day_3 		char(1) DEFAULT 'Y' not null,
  run_on_working_day_4 		char(1) DEFAULT 'Y' not null,
  run_on_other_working_days 	char(1) DEFAULT 'Y' not null,
  calendar 			varchar(10) null,
  day_plan 			varchar(10) null,
  start_time 			time null,
  stop_time 			time null
)
go

create index stream_id_ind on tws_stream_jobs(stream_id)
go

create index job_id_ind on tws_stream_jobs(job_id)
go

drop index alerts.alerts_name_ind
go
 
drop table alerts
go
 
create table alerts (
  id                int identity primary key,
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
)
go
 
create index alerts_name_ind on alerts(name)
go

drop table indexes
go

create table indexes (
  name              varchar(30) not null,
  ntable            varchar(30) not null,
  ndatabase         varchar(30) not null,
  id                int not null,
  index_id          smallint not null,
  nr_keys           smallint not null
)
go

drop table messages
go

create table messages (
  id              int identity primary key,
  type            varchar(8) not null,
  priority        varchar(8) not null,
  environment     varchar(6) not null,
  userid          varchar(16) not null,
  timestamp       int not null,
  validity        int not null,
  title           varchar(30) not null,
  message         varchar(100) not null,
  delivered       char(1) not null,
  confirmed       char(1) not null
)
go

drop table scripts
go

create table scripts (
  id              int identity primary key,
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
) with identity_gap = 100
go

drop table transfers
go

create table transfers (
  id              int identity primary key,
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
) with identity_gap = 100
go

drop table statements
go

create table statements (
  id              int identity primary key,
  session_id      int null,
  script_id       int null,
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
  sql_tag         varchar(20) null,
  full_table_scan char(1) null,
  business_date   char(8) null,
  service_id      int null,
  plan_tag        varchar(10) null
) with identity_gap = 100
go

create index statements_session_id_ind on statements(session_id)
go

create index statements_script_id_ind on statements(script_id)
go

create index statements_service_id_ind on statements(service_id)
go

create index statements_sql_tag_ind on statements(sql_tag)
go

create index statements_plan_tag_ind on statements(plan_tag)
go

drop table blockers
go

create table blockers (
  id              int identity primary key,
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
) with identity_gap = 100
go

create index blockers_statement_id_ind on blockers(statement_id)
go

drop table statement_waits
go

create table statement_waits (
  statement_id    int not null,
  event_id        smallint not null,
  nr_waits        int not null,
  wait_time       int not null
)
go

create index statement_waits_id_ind on statement_waits(statement_id)
go

drop table wait_event_info
go

create table wait_event_info (
  event_id        smallint not null,
  description     varchar(50)
)
go

// insert into wait_event_info ( event_id, description ) select WaitEventID, Description from  master..monWaitEventInfo

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
  nr_records      int not null,
  tabletype       varchar(10) null
)
go

create index feedertables_session_id_ind on feedertables(session_id)
go

drop index dm_filters.dm_filters_session_id_ind
go

drop table dm_filters
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

drop index dm_scanners.dm_scanners_session_id_ind
go

drop table dm_scanners
go

create table dm_scanners (
  id                int identity primary key,
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
)
go

create index dm_scanners_session_id_ind on dm_scanners(session_id)
go

drop index dm_items.dm_items_session_id_ind
go

drop table dm_items
go

create table dm_items (
  session_id       int not null,
  item_ref         int not null
)
go

create index dm_items_session_id_ind on dm_items(session_id)
go

drop table cores
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

drop table webcommands
go

create table webcommands (
  id              int identity primary key,
  cmdline         varchar(500) not null,
  pid             int null,
  win_user        char(8) null,
  starttime       int not null,
  business_date   char(8) null
) with identity_gap = 100
go

drop table md_uploads
go

create table md_uploads (
  id              int identity primary key,
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
)
go

drop table md_pairs
go

create table md_pairs (
  name            char(7) not null,
  upload_id       int not null
)
go

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
  business_date   char(8) not null,
  job_nr          varchar(8) null
)
go

create index tws_executions_tws_date_ind on tws_executions(tws_date)
go

drop table imswift_status
go

create table imswift_status (
  id              int identity primary key,
  sendersref      varchar(15) not null,
  relatedref      varchar(15) null,
  messagetype     varchar(10) not null,
  reasoncode      varchar(32) not null,
  account         varchar(20) not null,
  itemstate       varchar(20) not null,
  state           varchar(10) not null,
  operationtype   char(8) null,
  eventtype       char(1) null,
  passnum         varchar(32) null,
  swapsendersref  varchar(15) null,
  swapitemtype    varchar(30) null,
  docid           varchar(30) null,
  mxstatus        varchar(30) null, 
  timestamp       int not null,
  runid           varchar(40) not null,
  runstatus       varchar(30) not null
)
go

drop table resourcepool
go

create table resourcepool (
  resourcename   varchar(20) primary key,
  initial_size   numeric(10,2) not null,
  available      numeric(10,2) not null
)
go

drop table svn_users
go

create table svn_users (
  username        varchar(30) unique,
  password        varchar(30) null,
)
go

drop table locks
go

create table locks (
  FILENAME       VARCHAR(128) NOT NULL,
  LOCK_DATE      DATETIME default getDate() NOT NULL,
  USERID         VARCHAR(8)
)
go

drop table commitpoints
go

create table commitpoints (
ID              int identity primary key,
NAME            varchar(50) not null,
CODE            char(1) not null,
DESCR           varchar(50) not null,
CDATE           char(8) not null,
CKEY            varchar(500) not null )
go
