drop index dm_scanners.dm_scanners_session_id_ind
go

drop table dm_scanners
go

create table dm_scanners (
  id               int identity primary key,
  session_id       int not null,
  nr_engines       int null,
  batch_size       int null,
  nr_retries       int null,
  nr_batches       int null,
  nr_items         int null,
  nr_missing_items int null
)
go

create index dm_scanners_session_id_ind on dm_scanners(session_id)
go

drop index dm_items.dm_items_session_id_ind
go

drop table dm_items
go

create table dm_items (
  session_id       int not null,
  item_ref         int not null
)
go

create index dm_items_session_id_ind on dm_items(session_id)
go
