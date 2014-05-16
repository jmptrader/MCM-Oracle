drop table mxml_directories
go

create table mxml_directories (
  taskname         varchar(50) not null,
  received         varchar(200) null,
  error            varchar(200) null
)
go
