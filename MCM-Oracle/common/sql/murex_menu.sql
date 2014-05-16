drop table users
go

create table users (
	id		int identity primary key		not null,
	name		char(6)					not null,
	full_name	varchar(30)				not null,
	password	varchar(30)				not null
)
go

drop table groups
go

create table groups (
	id		int identity primary key		not null,
	name		varchar(30)				not null,
	type		varchar(30)				not null,
	label		varchar(30)				null
)
go

drop table environments
go

create table environments (
	id		int identity primary key		not null,
	name		char(8)					not null,
	label		varchar(30)				null,
	pillar		char(1)					not null,
	samba_read	varchar(50)				null,
	samba_write	varchar(50)				null
)
go

drop index applications.applications_nd0
go

drop table applications
go

create table applications(
	id		int identity primary key		not null,
	name		char(10)				not null,
	label		varchar(30)				null,
	button_label	varchar(30)				null
)
go

create index applications_nd0 on applications (name)
go

drop index user_group.user_group_nd0
go

drop index user_group.user_group_nd1
go

drop table user_group
go

create table user_group(
	user_id		int					not null,
	group_id	int					not null
)
go

create index user_group_nd0 on user_group (user_id)
go

create index user_group_nd1 on user_group (group_id)
go

drop index user_environment.user_environment_nd0
go

drop index user_environment.user_environment_nd1
go

drop table user_environment
go

create table user_environment(
	user_id		int					not null,
	environment_id	int					not null,
	max_sessions	int					null,
	overrride	bit					not null,
	web_access	bit					not null
)
go

create index user_environment_nd0 on user_environment (user_id)
go

create index user_environment_nd1 on user_environment (environment_id)
go

drop index environment_group.environment_group_nd0
go

drop index environment_group.environment_group_nd1
go

drop table environment_group
go

create table environment_group(
	environment_id	int		not null,
	group_id	int		not null,
	rights		char(100)	null
)
go

create index environment_group_nd0 on environment_group (environment_id)
go

create index environment_group_nd1 on environment_group (group_id)
go

create trigger delete_cascade_users 
on users
for delete
as
delete user_group
from user_group, deleted
where user_id = deleted.id

delete user_environment
from user_environment,deleted
where user_id  = deleted.id

go

create trigger delete_cascade_groups
on groups
for delete
as
delete user_group
from user_group, deleted
where group_id = deleted.id

delete environment_group
from environment_group, deleted
where group_id = deleted.id

go

create trigger delete_cascade_environments
on environments
for delete
as
delete user_environment
from user_environment, deleted
where environment_id = deleted.id

delete environment_group
from environment_group, deleted
where environment_id = deleted.id

go
