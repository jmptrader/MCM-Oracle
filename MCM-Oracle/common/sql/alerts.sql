drop index alerts.alerts_name_ind
go

drop table alerts
go
 
create table alerts (
  id                int identity primary key,
  timestamp         int not null,
  name              varchar(20) not null,
  item              varchar(30) null,
  category          varchar(20) not null,
  wlevel            varchar(8) not null,
  message           varchar(200) null,
  business_date     char(8) not null,
  ack_received      char(1) null,
  ack_timestamp     int null,
  ack_user          char(8) null,
  trigger_count     int null,
  trigger_timestamp int null,
  logfile           varchar(128) null
)
go

create index alerts_name_ind on alerts(name)
go
