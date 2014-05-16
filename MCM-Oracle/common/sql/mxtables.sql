drop table mxtables
go

create table mxtables (
  name            varchar(30) primary key,
  nr_rows         int not null,
  data            int not null,
  indexes         int not null,
  unused          int not null,
  reserved        int not null,
  growth_rate     numeric(8,2) null
)
go
