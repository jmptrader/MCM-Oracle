drop trigger del_cascade_session
go

create trigger del_cascade_session
on sessions
for delete
as
  delete reports
  from reports, deleted
  where reports.session_id = deleted.id

  delete feedertables
  from feedertables, deleted
  where feedertables.session_id = deleted.id

  delete dm_filters
  from dm_filters, deleted
  where dm_filters.session_id = deleted.id

  delete timings
  from timings, deleted
  where timings.session_id = deleted.id

  delete performance
  from performance, deleted
  where performance.session_id = deleted.id

  delete sybase
  from sybase, deleted
  where sybase.session_id = deleted.id

  delete usercalls
  from usercalls, deleted
  where usercalls.session_id = deleted.id

  delete syscalls
  from syscalls, deleted
  where syscalls.session_id = deleted.id

  delete sqltrace
  from sqltrace, deleted
  where sqltrace.session_id = deleted.id

  delete sqlio
  from sqlio, deleted
  where sqlio.session_id = deleted.id

  delete memory
  from memory, deleted
  where memory.session_id = deleted.id

  delete ab_books_sessions
  from ab_books_sessions, deleted
  where ab_books_sessions.session_id = deleted.id

  delete md_uploads
  from md_uploads, deleted
  where md_uploads.session_id = deleted.id
go

drop trigger del_cascade_script
go

create trigger del_cascade_script
on scripts
for delete
as
  delete dm_reports
  from dm_reports, deleted
  where dm_reports.script_id = deleted.id

  delete md_uploads
  from md_uploads, deleted
  where md_uploads.script_id = deleted.id
go

drop trigger del_cascade_ab_session
go

create trigger del_cascade_ab_session
on ab_sessions
for delete
as
  delete sessions
  from sessions, deleted
  where sessions.ab_session_id = deleted.id

  delete reports
  from reports, deleted
  where reports.ab_session_id = deleted.id

  delete ab_books
  from ab_books, deleted
  where ab_books.ab_session_id = deleted.id
go

drop trigger del_cascade_ab_book
go

create trigger del_cascade_ab_book
on ab_books
for delete
as
  delete ab_books_sessions
  from ab_books_sessions, deleted
  where ab_books_sessions.book_id = deleted.id
go

drop trigger update_session_duration
go

create trigger update_session_duration
on sessions
for update
as
  if update (mx_endtime)
    update sessions
      set duration = sessions.mx_endtime - sessions.mx_starttime
      from sessions, deleted
      where deleted.id = sessions.id
  if update (req_endtime)
    update sessions
      set duration = sessions.req_endtime - sessions.req_starttime
      from sessions, deleted
      where deleted.id = sessions.id
  if update (start_delay)
    update sessions
      set start_delay = sessions.start_delay - sessions.mx_starttime
      from sessions, deleted
      where deleted.id = sessions.id
go

drop trigger update_script_duration
go

create trigger update_script_duration
on scripts
for update
as
  if update (endtime)
    update scripts
      set duration = scripts.endtime - scripts.starttime
      from scripts, deleted
      where deleted.id = scripts.id
go

drop trigger update_transfer_duration
go

create trigger update_transfer_duration
on transfers
for update
as
  if update (endtime)
    update transfers
      set duration = transfers.endtime - transfers.starttime
      from transfers, deleted
      where deleted.id = transfers.id
go

drop trigger update_task_duration
go

create trigger update_task_duration
on tasks
for update
as
  if update (endtime)
    update tasks 
      set duration = tasks.endtime - tasks.starttime
      from tasks, deleted
      where deleted.id = tasks.id
go

drop trigger update_report_duration
go

create trigger update_report_duration
on reports
for update
as
  if update (endtime)
    update reports
      set duration = reports.endtime - reports.starttime
      from reports, deleted
      where deleted.id = reports.id
go

drop trigger update_ab_session_duration
go

create trigger update_ab_session_duration
on ab_sessions
for update
as
  if update (endtime)
    update ab_sessions
      set duration = ab_sessions.endtime - ab_sessions.starttime
      from ab_sessions, deleted
      where deleted.id = ab_sessions.id
go

drop trigger update_runtime_duration
go

create trigger update_runtime_duration
on runtimes
for update
as
  if update (endtime)
    update runtimes
      set duration = runtimes.endtime - runtimes.starttime
      from runtimes, deleted
      where deleted.id = runtimes.id
go

drop trigger update_tws_duration
go

create trigger update_tws_duration
on tws_executions
for update
as
  if update (endtime)
    update tws_executions
      set duration = tws_executions.endtime - tws_executions.starttime
      from tws_executions, deleted
      where deleted.id = tws_executions.id
go

drop trigger del_cascade_user
go

create trigger del_cascade_user
on users
for delete
as
  delete user_group
  from user_group, deleted
  where user_group.user_id = deleted.id

  delete user_group_right
  from user_group_right, deleted
  where user_group_right.user_group_id = deleted.id
go

drop trigger del_cascade_group
go

create trigger del_cascade_group
on groups
for delete
as
  delete user_group_right
  from user_group_right, deleted
  where user_group_right.user_group_id = deleted.id
go

drop trigger del_cascade_environment
go

create trigger del_cascade_environment
on environments
for delete
as
  delete user_group_right
  from user_group_right, deleted
  where user_group_right.environment_id = deleted.id
go

drop trigger del_cascade_right
go

create trigger del_cascade_right
on rights
for delete
as
  delete user_group_right
  from user_group_right, deleted
  where user_group_right.right_id = deleted.id
go

create trigger del_cascade_statements
on statements
for delete
as
  delete blockers
  from blockers, deleted
  where blockers.statement_id = deleted.id
go

create trigger del_cascade_md_upload
on md_uploads
for delete
as
  delete md_pairs
  from md_pairs, deleted
  where md_pairs.upload_id = deleted.id
go
