[statements_stats]
execute("if exists (select 1 from sysobjects where type='U' and name = 'statements_stats') drop table statements_stats")
execute("create table statements_stats(
sql_tag varchar(255),
avg_cpu_time INT null,
stddev_cpu_time NUMERIC(15,2) null,
avg_wait_time INT null,
stddev_wait_time NUMERIC(15,2) null,
avg_logical_reads NUMERIC(15,2) null,
stddev_logical_reads NUMERIC(15,2) null,
avg_physical_reads NUMERIC(15,2) null,
stddev_physical_reads NUMERIC(15,2) null,
avg_occr_by_date INT null,
stddev_occr_by_date NUMERIC(15,2) null
)
insert into statements_stats (sql_tag,avg_cpu_time,stddev_cpu_time,avg_wait_time,stddev_wait_time,avg_logical_reads,stddev_logical_reads,avg_physical_reads,stddev_physical_reads) 
select sql_tag,convert(INT,AVG(cpu_time*1.0)),STDDEV(cpu_time),AVG(wait_time),STDDEV(wait_time),convert(NUMERIC(15,2),AVG(logical_reads*1.0)),convert(NUMERIC(15,2),STDDEV(logical_reads*1.0)),convert(NUMERIC(15,2),AVG(physical_reads*1.0)),convert(NUMERIC(15,2),STDDEV(physical_reads*1.0))
from statements group by sql_tag

create table temp_occr_stats(
sql_tag varchar(255),
avg_occr_by_date INT null,
stddev_occr_by_date NUMERIC(15,2) null,
)
insert into temp_occr_stats (sql_tag,avg_occr_by_date, stddev_occr_by_date)
select sql_tag, avg(occr_by_date),STDDEV(occr_by_date) from (select sql_tag , count(sql_tag) as occr_by_date ,business_date from statements group by sql_tag,business_date) dt group by sql_tag 
update statements_stats
set statements_stats.avg_occr_by_date = temp_occr_stats.avg_occr_by_date,
statements_stats.stddev_occr_by_date = temp_occr_stats.stddev_occr_by_date
from temp_occr_stats,statements_stats
where statements_stats.sql_tag = temp_occr_stats.sql_tag
drop table temp_occr_stats")