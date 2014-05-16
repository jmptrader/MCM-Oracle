drop table users;

create table users (
  id              int primary key,
  name            varchar(30) unique,
  first_name      varchar(30) null,
  last_name       varchar(30) null,
  password        varchar(30) null,
  location        varchar(15) null,
  type            varchar(15) not null,
  config_data     varchar(50) null,
  disabled        char(1) null
);

drop table groups;

create table groups (
  id              int primary key,
  name            varchar(30) unique,
  type            varchar(15) not null,
  description     varchar(50) null,
  config_data     varchar(50) null
);

drop table environments;

create table environments (
  id              int primary key,
  name            varchar(16) unique,
  description     varchar(50) null,
  pillar          char(1) not null,
  samba_read      varchar(50) null,
  samba_write     varchar(50) null,
  config_data     varchar(50) null,
  disabled        char(1) null
);

drop table rights;

create table rights (
  id              int primary key,
  name            varchar(30) unique,
  type            varchar(15) not null,
  description     varchar(50) null
);

drop table user_group;

create table user_group (
  user_id         int not null,
  group_id        int not null
);

drop table user_group_right;

create table user_group_right (
  user_group_id   int not null,
  right_id        int not null,
  environment_id  int not null,
  config_data     varchar(50) null
);

drop table replicate;

drop sequence replicate_seq;

create table replicate (
  id              int primary key,
  statement_key   varchar(40) not null,
  svalues         varchar(350) null,
  sync_peer_1     char(1) not null,
  sync_peer_2     char(1) not null,
  sync_peer_3     char(1) not null,
  sync_peer_4     char(1) not null
);

create sequence replicate_seq start with 1;
