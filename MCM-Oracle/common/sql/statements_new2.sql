alter table statements add plan_tag varchar(10) null
go

create index statements_plan_tag_ind on statements(plan_tag)
go
