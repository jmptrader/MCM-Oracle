drop procedure sp_page_sessions
go

create procedure sp_page_sessions
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(400)

    select @table  = 'sessions'
    select @fields = 'id, hostname, req_starttime, mx_starttime, mx_endtime, req_endtime, mx_scripttype, mx_scriptname, win_user, mx_user, mx_group, mx_client_host, exitcode, ab_session_id, runtime, cputime, iotime, pid, corefile, entity, runtype, sched_jobstream, business_date, duration, mx_nick, project, reruns, killed, start_delay, cpu_seconds, vsize, remote_delay, nr_queries'

  create table #temptable (
    rownumber       int identity,
    id              int, 
    hostname        char(8) not null,
    req_starttime   int null,
    mx_starttime    int null,
    mx_endtime      int null,
    req_endtime     int null,
    mx_scripttype   varchar(16) null,
    mx_scriptname   varchar(30) null,
    win_user        char(8) null,
    mx_user         char(10) null,
    mx_group        char(10) null,
    mx_client_host  char(8) null, 
    exitcode        int null,
    ab_session_id   int null,
    runtime         int null,
    cputime         int null,
    iotime          int null,
    pid             int null,
    corefile        varchar(64) null,
    entity          varchar(6) null,
    runtype         char(1) null,
    sched_jobstream varchar(30) null,
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
  )

  declare @sql_command varchar(1200)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_tasks
go

create procedure sp_page_tasks
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(300)

    select @table  = 'tasks'
    select @fields = 'id, hostname, cmdline, starttime, endtime, name, exitcode, logfile, xmlfile, sched_jobstream, pid, business_date, duration'

  create table #temptable (
    rownumber       int identity,
    id              int,
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
  )

  declare @sql_command varchar(1200)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_scripts
go

create procedure sp_page_scripts
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(300)

    select @table  = 'scripts'
    select @fields = 'id, scriptname, path, cmdline, hostname, pid, username, starttime, endtime, exitcode, project, sched_jobstream, business_date, duration, killed, cpu_seconds, vsize, logfile, name'

  create table #temptable (
    rownumber       int identity,
    id              int,
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
  )

  declare @sql_command varchar(1200)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_transfers
go

create procedure sp_page_transfers
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(300)

    select @table  = 'transfers'
    select @fields = 'id, hostname, project, sched_jobstream, entity, content, target, starttime, endtime, duration, filelength, reruns, killed, exitcode, cmdline, pid, cdpid, username, business_date, logfile, cdkeyfile'

  create table #temptable (
    rownumber       int identity,
    id              int,
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
    cdpid           int not null,
    username        char(8) not null,
    business_date   char(8) null,
    logfile         varchar(128) null,
    cdkeyfile       varchar(128) null
  )

  declare @sql_command varchar(1200)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
 
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_runtimes
go

create procedure sp_page_runtimes
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(300)

    select @table  = 'runtimes'
    select @fields = 'id, descriptor, starttime, endtime, duration, exitcode'

  create table #temptable (
    rownumber       int identity,
    id              int,
    descriptor      varchar(30) not null,
    starttime       int null,
    endtime         int null,
    duration        int null,
    exitcode        int null
  )

  declare @sql_command varchar(1200)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_jobs
go

create procedure sp_page_jobs
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(300)

    select @table  = 'jobs'
    select @fields = 'id, name, status, next_runtime, starttime, endtime, duration, exitcode'

  create table #temptable (
    rownumber       int identity,
    id              int,
    name            varchar(30) not null,
    status          varchar(15) not null,
    next_runtime    int null,
    starttime       int null,
    endtime         int null,
    duration        int null,
    exitcode        int null
  )

  declare @sql_command varchar(1200)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_reports
go

create procedure sp_page_reports
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'reports'
    select @fields = 'id, label, type, session_id, batchname, reportname, entity, runtype, mds, starttime, endtime, size, nr_records, tablename, path, business_date, duration, ab_session_id, command, exitcode, cduration, status, archived, compressed, filter, project'

  create table #temptable (
    rownumber       int identity,
    id              int,
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
    project         varchar(32) null
  )

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_alerts
go

create procedure sp_page_alerts
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'alerts'
    select @fields = 'id, timestamp, name, item, category, wlevel, message, business_date, ack_received, ack_timestamp, ack_user, trigger_count, trigger_timestamp, logfile'

  create table #temptable (
    rownumber         int identity,
    id                int,
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

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_ab_sessions
go

create procedure sp_page_ab_sessions
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'ab_sessions'
    select @fields = 'id, hostname, cmdline, starttime, endtime, nr_books_ok, nr_books_nok, business_date, duration, sched_jobstream, batchname, pid'

  create table #temptable (
    rownumber       int identity,
    id              int, 
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
    pid             int null
  )

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_ab_books
go

create procedure sp_page_ab_books
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'ab_books'
    select @fields = 'id, book, batch, ab_session_id, starttime, endtime, runtime, nr_runs, status, report_id, reference, est_runtime'

  create table #temptable (
    rownumber       int identity,
    id              int,
    book            varchar(30) not null,
    batch           varchar(16) not null,
    ab_session_id   int not null,
    starttime       int null,
    endtime         int null,
    runtime         int null,
    nr_runs         int not null,
    status          char(8) not null,
    report_id       int null,
    reference       varchar(30) not null,
    est_runtime     int null
  )

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_logfiles
go

create procedure sp_page_logfiles
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'logfiles'
    select @fields = 'id, timestamp, filename, type, extract, start_pos, length'

  create table #temptable (
    rownumber       int identity,
    id              int,
    timestamp       int not null,
    filename        varchar(100) not null,
    type            varchar(8) not null,
    extract         varchar(2000) null,
    start_pos       int null,
    length          int null
  )

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_users
go

create procedure sp_page_users
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'users'
    select @fields = 'id, name, first_name, last_name, password, location, type, config_data, disabled'

  create table #temptable (
    rownumber       int identity,
    id              int,
    name            varchar(30) not null,
    first_name      varchar(30) null,
    last_name       varchar(30) null,
    password        varchar(30) null,
    location        varchar(15) null,
    type            varchar(15) not null,
    config_data     varchar(50) null,
    disabled        char(1) null
  )

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_groups
go

create procedure sp_page_groups
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'groups'
    select @fields = 'id, name, type, description, config_data'

  create table #temptable (
    rownumber       int identity,
    id              int,
    name            varchar(30) not null,
    type            varchar(15) not null,
    description     varchar(50) null,
    config_data     varchar(50) null
  )

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_environments
go

create procedure sp_page_environments
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'environments'
    select @fields = 'id, name, description, pillar, samba_read, samba_write, config_data, disabled'

  create table #temptable (
    rownumber       int identity,
    id              int,
    name            varchar(8) not null,
    description     varchar(50) null,
    pillar          char(1) not null,
    samba_read      varchar(50) null,
    samba_write     varchar(50) null,
    config_data     varchar(50) null,
    disabled        char(1) null
  )

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_rights
go

create procedure sp_page_rights
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'rights'
    select @fields = 'id, name, type, description'

  create table #temptable (
    rownumber       int identity,
    id              int,
    name            varchar(30) not null,
    type            varchar(15) not null,
    description     varchar(50) null
  )

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_messages
go

create procedure sp_page_messages
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'messages'
    select @fields = 'id, type, priority, environment, userid, timestamp, validity, title, message, delivered, confirmed'

  create table #temptable (
    rownumber       int identity,
    id              int,
    type            varchar(8) not null,
    priority        varchar(8) not null,
    environment     varchar(5) not null,
    userid          varchar(16) not null,
    timestamp       int not null,
    validity        int not null,
    title           varchar(30) not null,
    message         varchar(100) not null,
    delivered       char(1) not null,
    confirmed       char(1) not null
  )

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_statements
go

create procedure sp_page_statements
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'statements'
    select @fields = 'id, session_id, script_id, spid, db_name, pid, login, hostname, application, starttime, endtime, duration, cpu_time, wait_time, logical_reads, physical_reads, sql_tag, full_table_scan, business_date, service_id, plan_tag'

  create table #temptable (
    rownumber       int identity,
    id              int,
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
    sql_tag         varchar(10) null,
    full_table_scan char(1) null,
    business_date   char(8) null,
    service_id      int null,
    plan_tag        varchar(10) null
  )

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_blockers
go

create procedure sp_page_blockers
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'blockers'
    select @fields = 'id, statement_id, spid, db_name, pid, login, hostname, application, tran_name, cmd, status, starttime, duration, business_date'

  create table #temptable (
    rownumber       int identity,
    id              int,
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
    business_date   char(8) null
  )

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_feedertables
go

create procedure sp_page_feedertables
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'feedertables'
    select @fields = 'id, session_id, name, batch_name, feeder_name, entity, runtype, timestamp, job_id, ref_data, nr_records, tabletype'

  create table #temptable (
    rownumber       int identity,
    id              int,
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

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_dm_reports
go

create procedure sp_page_dm_reports
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'dm_reports'
    select @fields = 'id, label, type, script_id, name, directory, mode, starttime, endtime, size, nr_records, project, entity, runtype, business_date'

  create table #temptable (
    rownumber       int identity,
    id              int,
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
  )

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_cores
go

create procedure sp_page_cores
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'cores'
    select @fields = 'id, session_id, pstack_path, pmap_path, core_path, hostname, size, timestamp, win_user, mx_user, mx_group, mx_nick, function, business_date'

  create table #temptable (
    rownumber       int identity,
    id              int,
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
  )

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_services
go

create procedure sp_page_services
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'services'
    select @fields = 'id, name, starttime, endtime, service_start_duration, service_start_rc, post_start_duration, post_start_rc, pre_stop_duration, pre_stop_rc, service_stop_duration, service_stop_rc, business_date'

  create table #temptable (
    rownumber               int identity,
    id                      int,
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
  )

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_webcommands
go

create procedure sp_page_webcommands
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'webcommands'
    select @fields = 'id, cmdline, pid, win_user, starttime, business_date'

  create table #temptable (
    rownumber               int identity,
    id                      int,
    cmdline                 varchar(500) not null,
    pid                     int null,
    win_user                char(8) null,
    starttime               int not null,
    business_date           char(8) null
  )

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_md_uploads
go

create procedure sp_page_md_uploads
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'md_uploads'
    select @fields = 'id, timestamp, type, channel, status, nr_not_imported, xml_path, xml_size, win_user, md_group, action, md_date, mds, script_id, session_id'

  create table #temptable (
    rownumber               int identity,
    id                      int,
    timestamp               int not null,
    type                    varchar(15) null,
    channel                 varchar(15) not null,
    status                  varchar(15) null,
    nr_not_imported         int null,
    xml_path                varchar(128) null,
    xml_size                int null,
    win_user                char(8) null,
    md_group                varchar(15) null,
    action                  varchar(15) null,
    md_date                 char(8) null,
    mds                     varchar(20) null,
    script_id               int null,
    session_id              int null
  )

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

drop procedure sp_page_imswift_statuses
go

create procedure sp_page_imswift_statuses
  @page_nr int,
  @recs_per_page int,
  @order_clause varchar(256),
  @where_clause varchar(512) = NULL
as
begin
  set nocount on

    declare @table varchar(16)
    declare @fields varchar(256)

    select @table  = 'imswift_status'
    select @fields = 'id, sendersref, relatedref, messagetype, reasoncode, account, itemstate, state, operationtype, eventtype, passnum, swapsendersref, swapitemtype, timestamp'

  create table #temptable (
    rownumber               int identity,
    id                      int,
    sendersref              varchar(15) not null,
    relatedref              varchar(15) not null,
    messagetype             varchar(10) not null,
    reasoncode              varchar(32) not null,
    account                 varchar(20) not null,
    itemstate               varchar(20) not null,
    state                   varchar(10) not null,
    operationtype           char(8) null,
    eventtype               char(1) null,
    passnum                 varchar(32) null,
    swapsendersref          varchar(15) null,
    swapitemtype            varchar(30) null,
    timestamp               int not null
  )

  declare @sql_command varchar(1024)

  if isnull(@where_clause, ' ') != ' '
    select @where_clause = ' where ' + @where_clause

  select @sql_command = 'insert into #temptable (' + @fields + ') select ' + @fields + ' from ' + @table + @where_clause + ' order by ' + @order_clause
  
  exec(@sql_command)

  declare @first_rec int, @last_rec int

  select @first_rec = (@page_nr - 1) * @recs_per_page
  select @last_rec  = (@page_nr * @recs_per_page + 1)

  select @sql_command = 'select total = (select count(*) from #temptable), ' + @fields + ' from #temptable where rownumber > @first_rec and rownumber < @last_rec' + ' order by ' + @order_clause

  exec(@sql_command)

  set nocount off
end
go

