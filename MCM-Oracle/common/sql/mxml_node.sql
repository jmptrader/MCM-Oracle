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
  proc_time        int null,
)
go
