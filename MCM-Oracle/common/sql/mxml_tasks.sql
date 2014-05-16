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

