alter table cores modify size float not null
go

alter table dm_reports modify size float null
go

alter table reports modify size float null
go

alter table sessions modify vsize float null
go

alter table scripts modify vsize float null
go
