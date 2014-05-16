drop table md_uploads
go

create table md_uploads (
  id              int identity primary key,
  timestamp       int not null,
  type            varchar(15) null,
  channel         varchar(15) not null,
  status          varchar(15) null,
  nr_not_imported int null,
  xml_path        varchar(128) null,
  xml_size        int null,
  win_user        char(8) null,
  md_group        varchar(15) null,
  action          varchar(15) null,
  md_date         char(8) null,
  mds             varchar(20) null,
  script_id       int null,
  session_id      int null
)
go

drop table md_pairs
go

create table md_pairs (
  name            char(7) not null,
  upload_id       int not null
)
go
