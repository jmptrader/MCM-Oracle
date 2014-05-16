insert into users ( id, name, first_name, last_name, password, type, disabled ) values ( 1, 'admin', NULL, NULL, '47RxZx2H52Z/s', 'support', 'N' );

insert into groups ( id, name, type, description, config_data ) values ( 10001, 'ADMIN', 'standard', 'Admin Group', NULL );

insert into environments ( id, name, pillar, disabled ) values ( 1, 'DEMO', 'O', 'N' );

insert into rights ( id, name, type, description ) values ( 1, 'mon_login', 'monitoring_gui', 'Dashboard Login' );
insert into rights ( id, name, type, description ) values ( 2, 'maf_login', 'monitoring_gui', 'Authorization Login' );
insert into rights ( id, name, type, description ) values ( 3, 'murex_login', 'client_menu', 'Start a Murex client session' );
insert into rights ( id, name, type, description ) values ( 4, 'stop_start_service', 'monitoring_gui', 'Stop and start Murex services' );
insert into rights ( id, name, type, description ) values ( 5, 'stop_start_collector', 'monitoring_gui', 'Stop and start Murex collectors' );
insert into rights ( id, name, type, description ) values ( 6, 'kill_session', 'monitoring_gui', 'Kill one or more sessions' );
insert into rights ( id, name, type, description ) values ( 7, 'kill_script', 'monitoring_gui', 'Kill one or more scripts' );
insert into rights ( id, name, type, description ) values ( 8, 'kill_connection', 'monitoring_gui', 'Kill one or more DB connections' );
insert into rights ( id, name, type, description ) values ( 9, 'drop_index', 'monitoring_gui', 'Drop a DB index' );
insert into rights ( id, name, type, description ) values ( 10, 'create_index', 'monitoring_gui', 'Create a DB index' );
insert into rights ( id, name, type, description ) values ( 11, 'override_disabled_env', 'monitoring_gui', 'Login to a disabled environment' );
insert into rights ( id, name, type, description ) values ( 12, 'override_max_sessions', 'monitoring_gui', 'Override the maximum number of Murex sessions' );

insert into user_group ( user_id, group_id ) values ( 1, 10001 );

insert into user_group_right ( user_group_id, right_id, environment_id, config_data ) values ( 10001, 1, 0, NULL );
insert into user_group_right ( user_group_id, right_id, environment_id, config_data ) values ( 10001, 2, 0, NULL );
