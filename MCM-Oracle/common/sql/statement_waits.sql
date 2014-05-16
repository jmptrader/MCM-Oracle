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

