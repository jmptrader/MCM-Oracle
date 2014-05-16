[get_feeders]
select T1.M_REF, rtrim(T1.M_LABEL) from ACT_BAT_DBF T1, ACT_SET_DBF T2, ACT_SETREP_DBF T3 where T3.M_REFBAT = T1.M_REF and T3.M_REFSET = T2.M_REF and rtrim(T2.M_LABEL) = ?

[get_feeder_tables]
select T1.M_ID, rtrim(T1.M_OUTPUT), T2.M_TYPE, T2.M_REFERENCE from ACT_DYN_DBF T1, RPO_DMSETUP_TABLE_DBF T2 where T1.M_REF = ? and T1.M_OUTPUT = T2.M_LABEL

[check_feeder_table]
select count(*) from RPO_DMSETUP_TABLE_DBF where M_LABEL = ?

[get_dyntable_type]
select T1.M_CLASS_TYPE from DYNDBF2#TRN_DYND_DBF T1, RPO_DMSETUP_DYN_TABLE_DBF T2 where T1.M_CREATION = T2.M_DYN_TABLE and T2.M_REFERENCE = ?

[get_additional_dyntable_type]
select T1.M_CLASS_TYPE from DYNDBF4#TRN_DYND_DBF T1, RPO_DMSETUP_DYN_TABLE_DBF T2 where T1.M_CREATION = T2.M_DYN_TABLE and T2.M_REFERENCE = ?

[set_feeder_table]
update ACT_DYN_DBF set M_OUTPUT = ? where M_ID = ?

[set_batch_label]
update ACT_SET_DBF set M_TAGDATA = ? where rtrim(M_LABEL) = ?

[set_cmd_before]
update ACT_SET_DBF set M_CMD_BEFORE = ? where rtrim(M_LABEL) = ?

[get_unique_scanner_id]
BEGIN ?:O := sp_MxGetUniqueId('SCANNER', 'CFG', 1); END;

[insert_scanner]
insert into SCANNERCFG_DBF (TIMESTAMP, M_IDENTITY, M_REFERENCE, M_TEMPLATE, M_PROCESS_NB, M_BATCH_SIZE, M_TIMEOUT, M_RETRIES, M_THRESHOLD, M_RETRIES_BATCH_SIZE, M_RETRIES_THRESHOLD)
values (0, SCANNERCFG_DBFS.nextval, ?, ?, ?, ?, 0, ?, 0, ?, 0)

[cleanup_scanners]
delete from SCANNERCFG_DBF where M_TEMPLATE like 'BATCH_%' and M_REFERENCE not in ( select M_SCNTMPL from ACT_SET_DBF )

[cleanup_scanner]
delete from SCANNERCFG_DBF where M_REFERENCE = ?

[set_scanner]
update ACT_SET_DBF set M_SCNTMPL = ? where rtrim(M_LABEL) = ?

[get_exc_tmpl]
select M_REFERENCE from EXC_LVL_TMPL_DBF where rrim(M_LABEL) = ?

[set_exc_tmpl]
update ACT_SET_DBF set M_EXCTMPL = ? where rtrim(M_LABEL) = ?

[get_batch_filter]
select T1.M_FILTER_REF, rtrim(T1.M_LABEL) from DAPFILTER_DBF T1, ACT_SET_DBF T2 where T1.M_LABEL = T2.M_FLTTEMP and rtrim(T2.M_LABEL) = ?

[delete_portfolio_product_filter]
delete from DAPFLT_CH_DBF where M_FILTER_REF = ?

[set_portfolio_filter]
insert into DAPFLT_CH_DBF (TIMESTAMP, M_IDENTITY, M_FILTER_REF, M_CH_TYPE, M_CH_VALUE, M_CH_ID) values (0, DAPFLT_CH_DBFS.nextval, ?, 2, ?, 0)

[set_product_filter]
insert into DAPFLT_CH_DBF (TIMESTAMP, M_IDENTITY, M_FILTER_REF, M_CH_TYPE, M_CH_VALUE, M_CH_ID) values (0, DAPFLT_CH_DBFS.nextval, ?, 4, ?, 0)

[set_counterparty_filter]
insert into DAPFLT_CH_DBF (TIMESTAMP, M_IDENTITY, M_FILTER_REF, M_CH_TYPE, M_CH_VALUE, M_CH_ID) values (0, DAPFLT_CH_DBFS.nextval, ?, 0, ?, 0)

[delete_date_filter]
delete from DAPFLT_DAT_DBF where M_FILTER_REF = ?

[set_default_date_filter]
insert into DAPFLT_DAT_DBF (TIMESTAMP, M_IDENTITY, M_FILTER_REF, M_INDEX, M_VALUE, M_TYPE, M_OFFSET, M_SHIFTER, M_DESC, M_MKTDATA, M_USECLOSING, M_MDCS_SETT, M_CLOS_ENT)
values (0, DAPFLT_DAT_DBFS.nextval, ?, ?, null, 0, 0, ' ', ' ', 0, 'N', 'default', ' ')

[set_today_date_filter]
insert into DAPFLT_DAT_DBF (TIMESTAMP, M_IDENTITY, M_FILTER_REF, M_INDEX, M_VALUE, M_TYPE, M_OFFSET, M_SHIFTER, M_DESC, M_MKTDATA, M_USECLOSING, M_MDCS_SETT, M_CLOS_ENT)
values (0, DAPFLT_DAT_DBFS.nextval, ?, ?, null, 1, 0, ' ', ' ', ?, 'N', 'default', ' ')

[set_correction_date_filter]
insert into DAPFLT_DAT_DBF (TIMESTAMP, M_IDENTITY, M_FILTER_REF, M_INDEX, M_VALUE, M_TYPE, M_OFFSET, M_SHIFTER, M_DESC, M_MKTDATA, M_USECLOSING, M_MDCS_SETT, M_CLOS_ENT)
values (0, DAPFLT_DAT_DBFS.nextval, ?, ?, null, 19, 0, 'BATCH_COR_PRE', ' ', ?, 'N', 'default', ' ')

[set_reporting_date_filter]
insert into DAPFLT_DAT_DBF (TIMESTAMP, M_IDENTITY, M_FILTER_REF, M_INDEX, M_VALUE, M_TYPE, M_OFFSET, M_SHIFTER, M_DESC, M_MKTDATA, M_USECLOSING, M_MDCS_SETT, M_CLOS_ENT)
values (0, DAPFLT_DAT_DBFS.nextval, ?, ?, null, 23, 0, ' ', ' ', ?, 'N', 'default', ' ')

[set_dateshifter_date_filter]
insert into DAPFLT_DAT_DBF (TIMESTAMP, M_IDENTITY, M_FILTER_REF, M_INDEX, M_VALUE, M_TYPE, M_OFFSET, M_SHIFTER, M_DESC, M_MKTDATA, M_USECLOSING, M_MDCS_SETT, M_CLOS_ENT)
values (0, DAPFLT_DAT_DBFS.nextval, ?, ?, null, 19, 0, ?, ' ', ?, 'N', 'default', ' ')

[set_userdefined_date_filter]
insert into DAPFLT_DAT_DBF (TIMESTAMP, M_IDENTITY, M_FILTER_REF, M_INDEX, M_VALUE, M_TYPE, M_OFFSET, M_SHIFTER, M_DESC, M_MKTDATA, M_USECLOSING, M_MDCS_SETT, M_CLOS_ENT)
values (0, DAPFLT_DAT_DBFS.nextval, ?, ?, ?, 7, 0, ' ', ' ', ?, 'N', 'default', ' ')

[delete_expression_filter]
delete from DAPFLT_EXP_DBF where M_FILTER_REF = ?

[set_expression_epla_filter]
insert into DAPFLT_EXP_DBF (TIMESTAMP, M_IDENTITY, M_FILTER_REF, M_EXP_TYPE, M_EXP_IND, M_EXP_VAL) values (0, DAPFLT_EXP_DBFS.nextval, ?, 1, ?, ?)

[set_expression_filter]
insert into DAPFLT_EXP_DBF (TIMESTAMP, M_IDENTITY, M_FILTER_REF, M_EXP_TYPE, M_EXP_IND, M_EXP_VAL) values (0, DAPFLT_EXP_DBFS.nextval, ?, 2, ?, ?)

[get_intvars]
select distinct(ltrim(T1.M_NAME)), T1.M_REF, T1.M_TYPE, T1.M_DAT_TYPE, T1.M_VALUE, T1.M_DAT_VALUE, T1.M_DAT_SHIFT from DAPVAR_DBF T1, ACT_SET_DBF T2 where T1.M_REF = T2.M_VARSET and rtrim(T2.M_LABEL) = ?

[set_string_intvar]
update DAPVAR_DBF set M_TYPE = 'C', M_VALUE = ?, M_DAT_VALUE = null, M_DAT_TYPE = 0, M_DAT_OFFSET = 0, M_DAT_SHIFT = ' ' where M_NAME = ? and M_REF = ?

[set_numeric_intvar]
update DAPVAR_DBF set M_TYPE = 'N', M_VALUE = ?, M_DAT_VALUE = null, M_DAT_TYPE = 0, M_DAT_OFFSET = 0, M_DAT_SHIFT = ' ' where M_NAME = ? and M_REF = ?

[set_date_intvar_userdefined]
update DAPVAR_DBF set M_TYPE = 'D', M_VALUE = ?, M_DAT_VALUE = ?, M_DAT_TYPE = 7, M_DAT_OFFSET = 0, M_DAT_SHIFT = ' ' where M_NAME = ? and M_REF = ?

[set_date_intvar_today]
update DAPVAR_DBF set M_TYPE = 'D', M_VALUE = ?, M_DAT_VALUE = null, M_DAT_TYPE = 1, M_DAT_OFFSET = 0, M_DAT_SHIFT = ' ' where M_NAME = ? and M_REF = ?

[set_date_intvar_correction]
update DAPVAR_DBF set M_TYPE = 'D', M_VALUE = ' ', M_DAT_VALUE = null, M_DAT_TYPE = 19, M_DAT_OFFSET = 0, M_DAT_SHIFT = 'BATCH_COR_PRE' where M_NAME = ? and M_REF = ?

[set_date_intvar_dateshifter]
update DAPVAR_DBF set M_TYPE = 'D', M_VALUE = ' ', M_DAT_VALUE = null, M_DAT_TYPE = 19, M_DAT_OFFSET = 0, M_DAT_SHIFT = ? where M_NAME = ? and M_REF = ?

[mds_ref]
select M_REFERENCE from TRN_MDS_DBF where rtrim(M_LABEL) = ?

[job_info]
select M_IDJOB, rtrim(M_STATUS), M_REF_DATA from ACT_JOB_DBF where to_char(M_DATE, 'YYYYMMDD') = ? and rtrim(M_BATCH) = ? and M_PID = ?

[scanner_info]
select M_REFERENCE, M_NB_BATCHES, M_NB_ITEMS from SCANNER_REP where rtrim(M_EXT_ID) = ?

[item_info]
select M_ITM_REF from ITEM_REP where M_SCANNER_ID = ?

[nr_rows]
select count(M_REF_DATA) from __TABLE__ where M_REF_DATA = ? and M_MX_REF_JOB = ?

[get_batch_of_feeders_nr_records]
select sum(nr_records) / count(distinct session_id)  
from feedertables
where session_id in 
  (
  select  distinct A.session_id
  from feedertables A
  where A.batch_name = '__BATCH_NAME__'
  and A.feeder_name like left(A.batch_name, 3) +  'D%'
  and A.entity = '__ENTITY__'
  and A.runtype = '__RUNTYPE__'
  having 
    (select count(distinct B.session_id) from feedertables B 
     where B.batch_name = '__BATCH_NAME__'
     and B.feeder_name like left(B.batch_name, 3) +  'D%'
     and B.entity = '__ENTITY__'
     and B.runtype = '__RUNTYPE__'		
     and B.session_id <= A.session_id
    ) > count(distinct A.session_id) -3
    and A.batch_name = '__BATCH_NAME__'
    and A.feeder_name like left(A.batch_name, 3) +  'D%'
    and A.entity = '__ENTITY__'
    and A.runtype = '__RUNTYPE__'	
  )

