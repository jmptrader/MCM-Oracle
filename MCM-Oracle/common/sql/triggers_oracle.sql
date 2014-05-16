create or replace trigger update_session_duration
before update on sessions
for each row
begin
  if :new.mx_endtime > 0 then
    :new.duration := :new.mx_endtime - :old.mx_starttime;
  end if;
  if :new.req_endtime > 0 then
    :new.duration := :new.req_endtime - :old.req_starttime;
  end if;
  if :new.start_delay > :old.mx_starttime then
    :new.start_delay := :new.start_delay - :old.mx_starttime;
  end if;
end;
/
