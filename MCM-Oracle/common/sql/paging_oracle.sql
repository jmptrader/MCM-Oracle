CREATE OR REPLACE PROCEDURE sp_page_sessions(page_nr IN INT, recs_per_page IN INT, order_clause IN VARCHAR2, where_clause IN VARCHAR2 DEFAULT NULL, result_set OUT SYS_REFCURSOR) IS
    target_table      VARCHAR2(16)  := 'sessions';
    target_fields     VARCHAR2(400) := 'id, hostname, req_starttime, mx_starttime, mx_endtime, req_endtime, mx_scripttype, mx_scriptname, win_user, mx_user, mx_group, mx_client_host, exitcode, ab_session_id, runtime, cputime, iotime, pid, corefile, entity, runtype, sched_jobstream, business_date, duration, mx_nick, project, reruns, killed, start_delay, cpu_seconds, vsize, remote_delay, nr_queries';
    full_where_clause VARCHAR2(256) := '';
    sql_command       VARCHAR2(1200);
    first_rec         INT;
BEGIN
  IF NVL(where_clause, 'A') != 'A' THEN
    full_where_clause := ' WHERE ' || REPLACE( where_clause, '"', '''' );
  END IF;

  first_rec := (page_nr - 1) * recs_per_page;

  sql_command := 'select * from ( select count(*) over (), t.*, rownum as rn from ( select ' || target_fields || ' from ' || target_table || full_where_clause || ' order by ' || order_clause || ' ) t ) where rn > ' || first_rec || ' and rownum <= ' || recs_per_page;

  OPEN result_set FOR sql_command;
END;
/

CREATE OR REPLACE PROCEDURE sp_page_alerts(page_nr IN INT, recs_per_page IN INT, order_clause IN VARCHAR2, where_clause IN VARCHAR2 DEFAULT NULL, result_set OUT SYS_REFCURSOR) IS
    target_table      VARCHAR2(16)  := 'alerts';
    target_fields     VARCHAR2(400) := 'id, timestamp, name, item, category, wlevel, message, business_date, ack_received, ack_timestamp, ack_user, trigger_count, trigger_timestamp, logfile';
    full_where_clause VARCHAR2(256) := '';
    sql_command       VARCHAR2(1200);
    first_rec         INT;
BEGIN
  IF NVL(where_clause, 'A') != 'A' THEN
    full_where_clause := ' WHERE ' || REPLACE( where_clause, '"', '''' );
  END IF;

  first_rec := (page_nr - 1) * recs_per_page;

  sql_command := 'select * from ( select count(*) over (), t.*, rownum as rn from ( select ' || target_fields || ' from ' || target_table || full_where_clause || ' order by ' || order_clause || ' ) t ) where rn > ' || first_rec || ' and rownum <= ' || recs_per_page;

  OPEN result_set FOR sql_command;
END;
/

CREATE OR REPLACE PROCEDURE sp_page_logfiles(page_nr IN INT, recs_per_page IN INT, order_clause IN VARCHAR2, where_clause IN VARCHAR2 DEFAULT NULL, result_set OUT SYS_REFCURSOR) IS
    target_table      VARCHAR2(16)  := 'logfiles';
    target_fields     VARCHAR2(400) := 'id, timestamp, filename, type, extract, start_pos, length';
    full_where_clause VARCHAR2(256) := '';
    sql_command       VARCHAR2(1200);
    first_rec         INT;
BEGIN
  IF NVL(where_clause, 'A') != 'A' THEN
    full_where_clause := ' WHERE ' || REPLACE( where_clause, '"', '''' );
  END IF;

  first_rec := (page_nr - 1) * recs_per_page;

  sql_command := 'select * from ( select count(*) over (), t.*, rownum as rn from ( select ' || target_fields || ' from ' || target_table || full_where_clause || ' order by ' || order_clause || ' ) t ) where rn > ' || first_rec || ' and rownum <= ' || recs_per_page;

  OPEN result_set FOR sql_command;
END;
/

CREATE OR REPLACE PROCEDURE sp_page_users(page_nr IN INT, recs_per_page IN INT, order_clause IN VARCHAR2, where_clause IN VARCHAR2 DEFAULT NULL, result_set OUT SYS_REFCURSOR) IS
    target_table      VARCHAR2(16)  := 'users';
    target_fields     VARCHAR2(400) := 'id, name, first_name, last_name, password, location, type, config_data, disabled';
    full_where_clause VARCHAR2(256) := '';
    sql_command       VARCHAR2(1200);
    first_rec         INT;
BEGIN
  IF NVL(where_clause, 'A') != 'A' THEN
    full_where_clause := ' WHERE ' || REPLACE( where_clause, '"', '''' );
  END IF;

  first_rec := (page_nr - 1) * recs_per_page;

  sql_command := 'select * from ( select count(*) over (), t.*, rownum as rn from ( select ' || target_fields || ' from ' || target_table || full_where_clause || ' order by ' || order_clause || ' ) t ) where rn > ' || first_rec || ' and rownum <= ' || recs_per_page;

  OPEN result_set FOR sql_command;
END;
/

CREATE OR REPLACE PROCEDURE sp_page_groups(page_nr IN INT, recs_per_page IN INT, order_clause IN VARCHAR2, where_clause IN VARCHAR2 DEFAULT NULL, result_set OUT SYS_REFCURSOR) IS
    target_table      VARCHAR2(16)  := 'groups';
    target_fields     VARCHAR2(400) := 'id, name, type, description, config_data';
    full_where_clause VARCHAR2(256) := '';
    sql_command       VARCHAR2(1200);
    first_rec         INT;
BEGIN
  IF NVL(where_clause, 'A') != 'A' THEN
    full_where_clause := ' WHERE ' || REPLACE( where_clause, '"', '''' );
  END IF;

  first_rec := (page_nr - 1) * recs_per_page;

  sql_command := 'select * from ( select count(*) over (), t.*, rownum as rn from ( select ' || target_fields || ' from ' || target_table || full_where_clause || ' order by ' || order_clause || ' ) t ) where rn > ' || first_rec || ' and rownum <= ' || recs_per_page;

  OPEN result_set FOR sql_command;
END;
/

CREATE OR REPLACE PROCEDURE sp_page_environments(page_nr IN INT, recs_per_page IN INT, order_clause IN VARCHAR2, where_clause IN VARCHAR2 DEFAULT NULL, result_set OUT SYS_REFCURSOR) IS
    target_table      VARCHAR2(16)  := 'environments';
    target_fields     VARCHAR2(400) := 'id, name, description, pillar, samba_read, samba_write, config_data, disabled';
    full_where_clause VARCHAR2(256) := '';
    sql_command       VARCHAR2(1200);
    first_rec         INT;
BEGIN
  IF NVL(where_clause, 'A') != 'A' THEN
    full_where_clause := ' WHERE ' || REPLACE( where_clause, '"', '''' );
  END IF;

  first_rec := (page_nr - 1) * recs_per_page;

  sql_command := 'select * from ( select count(*) over (), t.*, rownum as rn from ( select ' || target_fields || ' from ' || target_table || full_where_clause || ' order by ' || order_clause || ' ) t ) where rn > ' || first_rec || ' and rownum <= ' || recs_per_page;

  OPEN result_set FOR sql_command;
END;
/

CREATE OR REPLACE PROCEDURE sp_page_rights(page_nr IN INT, recs_per_page IN INT, order_clause IN VARCHAR2, where_clause IN VARCHAR2 DEFAULT NULL, result_set OUT SYS_REFCURSOR) IS
    target_table      VARCHAR2(16)  := 'rights';
    target_fields     VARCHAR2(400) := 'id, name, type, description';
    full_where_clause VARCHAR2(256) := '';
    sql_command       VARCHAR2(1200);
    first_rec         INT;
BEGIN
  IF NVL(where_clause, 'A') != 'A' THEN
    full_where_clause := ' WHERE ' || REPLACE( where_clause, '"', '''' );
  END IF;

  first_rec := (page_nr - 1) * recs_per_page;

  sql_command := 'select * from ( select count(*) over (), t.*, rownum as rn from ( select ' || target_fields || ' from ' || target_table || full_where_clause || ' order by ' || order_clause || ' ) t ) where rn > ' || first_rec || ' and rownum <= ' || recs_per_page;

  OPEN result_set FOR sql_command;
END;
/

CREATE OR REPLACE PROCEDURE sp_page_services(page_nr IN INT, recs_per_page IN INT, order_clause IN VARCHAR2, where_clause IN VARCHAR2 DEFAULT NULL, result_set OUT SYS_REFCURSOR) IS
    target_table      VARCHAR2(16)  := 'services';
    target_fields     VARCHAR2(400) := 'id, name, starttime, endtime, service_start_duration, service_start_rc, post_start_duration, post_start_rc, pre_stop_duration, pre_stop_rc, service_stop_duration, service_stop_rc, business_date';
    full_where_clause VARCHAR2(256) := '';
    sql_command       VARCHAR2(1200);
    first_rec         INT;
BEGIN
  IF NVL(where_clause, 'A') != 'A' THEN
    full_where_clause := ' WHERE ' || REPLACE( where_clause, '"', '''' );
  END IF;

  first_rec := (page_nr - 1) * recs_per_page;

  sql_command := 'select * from ( select count(*) over (), t.*, rownum as rn from ( select ' || target_fields || ' from ' || target_table || full_where_clause || ' order by ' || order_clause || ' ) t ) where rn > ' || first_rec || ' and rownum <= ' || recs_per_page;

  OPEN result_set FOR sql_command;
END;
/

CREATE OR REPLACE PROCEDURE sp_page_feedertables(page_nr IN INT, recs_per_page IN INT, order_clause IN VARCHAR2, where_clause IN VARCHAR2 DEFAULT NULL, result_set OUT SYS_REFCURSOR) IS
    target_table      VARCHAR2(16)  := 'feedertables';
    target_fields     VARCHAR2(400) := 'id, session_id, name, batch_name, feeder_name, entity, runtype, timestamp, job_id, ref_data, nr_records, tabletype';
    full_where_clause VARCHAR2(256) := '';
    sql_command       VARCHAR2(1200);
    first_rec         INT;
BEGIN
  IF NVL(where_clause, 'A') != 'A' THEN
    full_where_clause := ' WHERE ' || REPLACE( where_clause, '"', '''' );
  END IF;

  first_rec := (page_nr - 1) * recs_per_page;

  sql_command := 'select * from ( select count(*) over (), t.*, rownum as rn from ( select ' || target_fields || ' from ' || target_table || full_where_clause || ' order by ' || order_clause || ' ) t ) where rn > ' || first_rec || ' and rownum <= ' || recs_per_page;

  OPEN result_set FOR sql_command;
END;
/

CREATE OR REPLACE PROCEDURE sp_page_dm_reports(page_nr IN INT, recs_per_page IN INT, order_clause IN VARCHAR2, where_clause IN VARCHAR2 DEFAULT NULL, result_set OUT SYS_REFCURSOR) IS
    target_table      VARCHAR2(16)  := 'dm_reports';
    target_fields     VARCHAR2(400) := 'id, label, type, script_id, name, directory, rmode, starttime, endtime, rsize, nr_records, project, entity, runtype, business_date';
    full_where_clause VARCHAR2(256) := '';
    sql_command       VARCHAR2(1200);
    first_rec         INT;
BEGIN
  IF NVL(where_clause, 'A') != 'A' THEN
    full_where_clause := ' WHERE ' || REPLACE( where_clause, '"', '''' );
  END IF;

  first_rec := (page_nr - 1) * recs_per_page;

  sql_command := 'select * from ( select count(*) over (), t.*, rownum as rn from ( select ' || target_fields || ' from ' || target_table || full_where_clause || ' order by ' || order_clause || ' ) t ) where rn > ' || first_rec || ' and rownum <= ' || recs_per_page;

  OPEN result_set FOR sql_command;
END;
/

CREATE OR REPLACE PROCEDURE sp_page_scripts(page_nr IN INT, recs_per_page IN INT, order_clause IN VARCHAR2, where_clause IN VARCHAR2 DEFAULT NULL, result_set OUT SYS_REFCURSOR) IS
    target_table      VARCHAR2(16)  := 'scripts';
    target_fields     VARCHAR2(400) := 'id, scriptname, path, cmdline, hostname, pid, username, starttime, endtime, exitcode, project, sched_jobstream, business_date, duration, killed, cpu_seconds, vsize, logfile, name';
    full_where_clause VARCHAR2(256) := '';
    sql_command       VARCHAR2(1200);
    first_rec         INT;
BEGIN
  IF NVL(where_clause, 'A') != 'A' THEN
    full_where_clause := ' WHERE ' || REPLACE( where_clause, '"', '''' );
  END IF;

  first_rec := (page_nr - 1) * recs_per_page;

  sql_command := 'select * from ( select count(*) over (), t.*, rownum as rn from ( select ' || target_fields || ' from ' || target_table || full_where_clause || ' order by ' || order_clause || ' ) t ) where rn > ' || first_rec || ' and rownum <= ' || recs_per_page;

  OPEN result_set FOR sql_command;
END;
/

CREATE OR REPLACE PROCEDURE sp_page_statements(page_nr IN INT, recs_per_page IN INT, order_clause IN VARCHAR2, where_clause IN VARCHAR2 DEFAULT NULL, result_set OUT SYS_REFCURSOR) IS
    target_table      VARCHAR2(16)  := 'statements';
    target_fields     VARCHAR2(400) := 'id, session_id, script_id, service_id, schema, username, sid, hostname, osuser, pid, program, command, starttime, endtime, duration, cpu, wait_time, logical_reads, physical_reads, physical_writes, sql_tag, plan_tag, business_date';
    full_where_clause VARCHAR2(256) := '';
    sql_command       VARCHAR2(1200);
    first_rec         INT;
BEGIN
  IF NVL(where_clause, 'A') != 'A' THEN
    full_where_clause := ' WHERE ' || REPLACE( where_clause, '"', '''' );
  END IF;

  first_rec := (page_nr - 1) * recs_per_page;

  sql_command := 'select * from ( select count(*) over (), t.*, rownum as rn from ( select ' || target_fields || ' from ' || target_table || full_where_clause || ' order by ' || order_clause || ' ) t ) where rn > ' || first_rec || ' and rownum <= ' || recs_per_page;

  OPEN result_set FOR sql_command;
END;
/

CREATE OR REPLACE PROCEDURE sp_page_jobs(page_nr IN INT, recs_per_page IN INT, order_clause IN VARCHAR2, where_clause IN VARCHAR2 DEFAULT NULL, result_set OUT SYS_REFCURSOR) IS
    target_table      VARCHAR2(16)  := 'jobs';
    target_fields     VARCHAR2(400) := 'id, name, status, next_runtime, starttime, endtime, duration, exitcode';
    full_where_clause VARCHAR2(256) := '';
    sql_command       VARCHAR2(1200);
    first_rec         INT;
BEGIN
  IF NVL(where_clause, 'A') != 'A' THEN
    full_where_clause := ' WHERE ' || REPLACE( where_clause, '"', '''' );
  END IF;

  first_rec := (page_nr - 1) * recs_per_page;

  sql_command := 'select * from ( select count(*) over (), t.*, rownum as rn from ( select ' || target_fields || ' from ' || target_table || full_where_clause || ' order by ' || order_clause || ' ) t ) where rn > ' || first_rec || ' and rownum <= ' || recs_per_page;

  OPEN result_set FOR sql_command;
END;
/

CREATE OR REPLACE PROCEDURE sp_page_cores(page_nr IN INT, recs_per_page IN INT, order_clause IN VARCHAR2, where_clause IN VARCHAR2 DEFAULT NULL, result_set OUT SYS_REFCURSOR) IS
    target_table      VARCHAR2(16)  := 'cores';
    target_fields     VARCHAR2(400) := 'id, session_id, pstack_path, pmap_path, core_path, hostname, csize, timestamp, win_user, mx_user, mx_group, mx_nick, function, business_date';
    full_where_clause VARCHAR2(256) := '';
    sql_command       VARCHAR2(1200);
    first_rec         INT;
BEGIN
  IF NVL(where_clause, 'A') != 'A' THEN
    full_where_clause := ' WHERE ' || REPLACE( where_clause, '"', '''' );
  END IF;

  first_rec := (page_nr - 1) * recs_per_page;

  sql_command := 'select * from ( select count(*) over (), t.*, rownum as rn from ( select ' || target_fields || ' from ' || target_table || full_where_clause || ' order by ' || order_clause || ' ) t ) where rn > ' || first_rec || ' and rownum <= ' || recs_per_page;

  OPEN result_set FOR sql_command;
END;
/

CREATE OR REPLACE PROCEDURE sp_page_messages(page_nr IN INT, recs_per_page IN INT, order_clause IN VARCHAR2, where_clause IN VARCHAR2 DEFAULT NULL, result_set OUT SYS_REFCURSOR) IS
    target_table      VARCHAR2(16)  := 'messages';
    target_fields     VARCHAR2(400) := 'id, type, priority, environment, destination, timestamp, validity, message';
    full_where_clause VARCHAR2(256) := '';
    sql_command       VARCHAR2(1200);
    first_rec         INT;
BEGIN
  IF NVL(where_clause, 'A') != 'A' THEN
    full_where_clause := ' WHERE ' || REPLACE( where_clause, '"', '''' );
  END IF;

  first_rec := (page_nr - 1) * recs_per_page;

  sql_command := 'select * from ( select count(*) over (), t.*, rownum as rn from ( select ' || target_fields || ' from ' || target_table || full_where_clause || ' order by ' || order_clause || ' ) t ) where rn > ' || first_rec || ' and rownum <= ' || recs_per_page;

  OPEN result_set FOR sql_command;
END;
/

CREATE OR REPLACE PROCEDURE sp_page_blockers(page_nr IN INT, recs_per_page IN INT, order_clause IN VARCHAR2, where_clause IN VARCHAR2 DEFAULT NULL, result_set OUT SYS_REFCURSOR) IS
    target_table      VARCHAR2(16)  := 'blockers';
    target_fields     VARCHAR2(400) := 'id, statement_id, spid, db_name, pid, login, hostname, application, tran_name, cmd, status, starttime, duration, business_date';
    full_where_clause VARCHAR2(256) := '';
    sql_command       VARCHAR2(1200);
    first_rec         INT;
BEGIN
  IF NVL(where_clause, 'A') != 'A' THEN
    full_where_clause := ' WHERE ' || REPLACE( where_clause, '"', '''' );
  END IF;

  first_rec := (page_nr - 1) * recs_per_page;

  sql_command := 'select * from ( select count(*) over (), t.*, rownum as rn from ( select ' || target_fields || ' from ' || target_table || full_where_clause || ' order by ' || order_clause || ' ) t ) where rn > ' || first_rec || ' and rownum <= ' || recs_per_page;

  OPEN result_set FOR sql_command;
END;
/

CREATE OR REPLACE PROCEDURE sp_page_webcommands(page_nr IN INT, recs_per_page IN INT, order_clause IN VARCHAR2, where_clause IN VARCHAR2 DEFAULT NULL, result_set OUT SYS_REFCURSOR) IS
    target_table      VARCHAR2(16)  := 'webcommands';
    target_fields     VARCHAR2(400) := 'id, cmdline, pid, win_user, starttime, business_date';
    full_where_clause VARCHAR2(256) := '';
    sql_command       VARCHAR2(1200);
    first_rec         INT;
BEGIN
  IF NVL(where_clause, 'A') != 'A' THEN
    full_where_clause := ' WHERE ' || REPLACE( where_clause, '"', '''' );
  END IF;

  first_rec := (page_nr - 1) * recs_per_page;

  sql_command := 'select * from ( select count(*) over (), t.*, rownum as rn from ( select ' || target_fields || ' from ' || target_table || full_where_clause || ' order by ' || order_clause || ' ) t ) where rn > ' || first_rec || ' and rownum <= ' || recs_per_page;

  OPEN result_set FOR sql_command;
END;
/
