[user_select]
select id, name, first_name, last_name, password, location, type, config_data, disabled from users

[user_select_by_id]
select id, name, first_name, last_name, password, location, type, config_data, disabled from users where id = ?

[user_select_by_name]
select id, name, first_name, last_name, password, location, type, config_data, disabled from users where name = ?

[user_group_select]
select A.group_id, B.name, B.type, B.description, B.config_data from user_group A, groups B where A.user_id = ? and A.group_id = B.id

[user_right_select]
select A.right_id, A.environment_id, A.config_data, B.name, B.type, B.description from user_group_right A, rights B where A.user_group_id = ? and A.right_id = B.id

[user_right_select_by_environment]
select A.right_id, A.environment_id, A.config_data, B.name, B.type, B.description from user_group_right A, rights B where A.user_group_id = ? and A.right_id = B.id and ( A.environment_id = ? or A.environment_id = 0 )

[user_insert]
insert into users (id, name, first_name, last_name, password, location, type, config_data, disabled) values (?, ?, ?, ?, ?, ?, ?, ?, ?)

[user_update]
update users set name = ?, first_name = ?, last_name = ?, password = ?, location = ?, type = ?, config_data = ?, disabled = ? where id = ?

[user_delete]
delete from users where id = ?

[user_group_delete]
delete from user_group where user_id = ?

[user_group_insert]
insert into user_group (user_id, group_id) values (?, ?)

[group_select]
select id, name, type, description, config_data from groups

[group_select_by_id]
select id, name, type, description, config_data from groups where id = ?

[group_select_by_name]
select id, name, type, description, config_data from groups where name = ?

[group_user_select]
select A.user_id, B.name, B.first_name, B.last_name, B.password, B.location, B.type, B.config_data, B.disabled from user_group A, users B where A.group_id = ? and A.user_id = B.id

[group_right_select]
select A.right_id, A.environment_id, A.config_data, B.name, B.type, B.description from user_group_right A, rights B where A.user_group_id = ? and A.right_id = B.id

[group_right_select_by_environment]
select A.right_id, A.environment_id, A.config_data, B.name, B.type, B.description from user_group_right A, rights B where A.user_group_id = ? and A.right_id = B.id and A.environment_id = ?

[group_insert]
insert into groups (id, name, type, description, config_data) values (?, ?, ?, ?, ?)

[group_update]
update groups set name = ?, type = ?, description = ?, config_data = ? where id = ?

[group_delete]
delete from groups where id = ?

[group_user_delete]
delete from user_group where group_id = ?

[group_right_delete]
delete from user_group_right where user_group_id = ? and environment_id = ?

[group_right_insert]
insert into user_group_right (user_group_id, right_id, environment_id) values (?, ?, ?)

[user_or_group_select]
select name, first_name+' '+last_name as description from users where id = ? union all select name, description from groups where id = ?

[environment_select]
select id, name, description, pillar, samba_read, samba_write, config_data, disabled from environments

[environment_select_by_id]
select id, name, description, pillar, samba_read, samba_write, config_data, disabled from environments where id = ?

[environment_select_by_name]
select id, name, description, pillar, samba_read, samba_write, config_data, disabled from environments where name = ?

[environment_insert]
insert into environments (id, name, description, pillar, samba_read, samba_write, config_data, disabled) values (?, ?, ?, ?, ?, ?, ?, ?)

[environment_update]
update environments set name = ?, description = ?, pillar = ?, samba_read = ?, samba_write = ?, config_data = ?, disabled = ? where id = ?

[environment_delete]
delete from environments where id = ?

[environment_extended_select]
select sybase_version, db_version, binary_version, ec.contact_id as contact_id from environment_info ei, environment_contacts ec where ei.environment_id = ? and ec.environment_id = ?

[environment_info_insert]
insert into environment_info (environment_id, sybase_version, db_version, binary_version) values (?, ?, ?, ?)

[environment_info_update]
update environment_info set sybase_version = ?, db_version = ?, binary_version = ? where environment_id = ?

[environment_info_delete]
delete from environment_info where environment_id = ?

[environment_contacts_insert]
insert into environment_contacts (environment_id, contact_id) values (?, ?)

[environment_contacts_update]
update environment_contacts set contact_id = ? where environment_id = ?

[environment_contacts_delete]
delete from environment_contacts where environment_id = ?

[right_select]
select id, name, type, description from rights

[right_select_by_id]
select id, name, type, description from rights where id = ?

[right_select_by_name]
select id, name, type, description from rights where name = ?

[right_insert]
insert into rights (id, name, type, description) values (?, ?, ?, ?)

[right_update]
update rights set name = ?, type = ?, description = ? where id = ?

[right_delete]
delete from rights where id = ?
