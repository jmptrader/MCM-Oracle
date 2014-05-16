drop table indexes
go

create table indexes (
  name              varchar(30) not null,
  ntable            varchar(30) not null,
  ndatabase         varchar(30) not null,
  index_id          smallint not null,
  nr_keys           smallint not null
)
go
