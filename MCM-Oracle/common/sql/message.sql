drop table messages
go

create table messages (
  id              int identity primary key,
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
go
