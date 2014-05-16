drop table mxtables_hist
go

create table mxtables_hist (
  timestamp       char(8) not null,
  name            varchar(30) not null,
  nr_rows         int not null,
  reserved        int not null
)
go
