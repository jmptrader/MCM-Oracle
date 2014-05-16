alter table statements add service_id int null
go

create index statements_service_id_ind on statements(service_id)
go
