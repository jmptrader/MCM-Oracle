drop index dm_filters.dm_filters_session_id_ind
go

drop table dm_filters
go

create table dm_filters (
  id              int identity primary key,
  session_id      int not null,
  batch_name      varchar(50) not null,
  dates           varchar(32) null,
  mds             varchar(62) null,
  products        varchar(500) null,
  portfolios      varchar(500) null,
  expression      varchar(30) null
)
go

create index dm_filters_session_id_ind on dm_filters(session_id)
go
