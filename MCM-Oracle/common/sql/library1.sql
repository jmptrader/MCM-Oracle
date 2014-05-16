[load_or_dump_check]
select spid from master..sysprocesses where db_name(dbid)=? and (cmd like '%LOAD DATABASE%' or cmd like '%DUMP DATABASE%')

[open_connections_check]
select spid from master..sysprocesses where db_name(dbid)=? and spid not in (?,?) 

[col_info]
select  colid, c.name
from    syscolumns c, systypes t
where   c.id = object_id('MUREXDB.__TABLE_NAME__')
    and c.usertype *= t.usertype
order by 1

[murex_version]
select M_NAME, M_BUILD_ID, UTIMESTAMP from MUREXDB.VRS_INFO_DBF

[murex_dates]
-- local variable needed later
declare @incdbh_m_date datetime
declare @incdbh_i integer
-- select the date from MUREX
select @incdbh_m_date = __DATE_COLUMN__ from __TABLE__ where __SELECT_COLUMN__ = ?
-- if the day is a holiday or a Sunday or Saturday,
-- we subtract more days until it is an office day
select @incdbh_i = 0
while( @incdbh_i <= __SHIFT__ )
begin
-- don't shift the date if no shifter has been provided
    if( @incdbh_i <> 0 )
    begin
        select @incdbh_m_date = dateadd( dd, __DIRECTION__, @incdbh_m_date )
    end
    while( exists( select M_DATE
        from MUREXDB.CAL_HOL_DBF
        where M_DATE = @incdbh_m_date
        and ( M_CAL_LABEL = ? ) )
-- check for general (repeating) holidays
        or exists( select M_DATE
        from MUREXDB.CAL_HOL_DBF
        where datepart( dd, M_DATE ) = datepart( dd, @incdbh_m_date )
        and datepart( mm, M_DATE ) = datepart( mm, @incdbh_m_date )
        and ( M_CAL_LABEL = ? )
        and M_GENERAL = 1 )
        or datepart( dw, @incdbh_m_date ) in ( 1, 7 ) )
    begin
        select @incdbh_m_date = dateadd( dd, __DIRECTION__, @incdbh_m_date )
    end
    select @incdbh_i = @incdbh_i + 1
end
select convert(char(8), @incdbh_m_date, 112)

[calendar_isunion]
select M_ISUNION from MUREXDB.CAL_DEF_DBF where M_LABEL = ?

[calendar_isholiday_1]
select count(*) from MUREXDB.CAL_HOL_DBF where M_CAL_LABEL = ? and ( M_DATE = ? or ( M_GENERAL = 1 and datepart(dd, M_DATE) = datepart(dd, ?) and datepart(mm, M_DATE) = datepart(mm, ?) ) )

[calendar_isholiday_2]
select count(*) from MUREXDB.CAL_HOL_DBF where M_CAL_LABEL in ( select M_REF from MUREXDB.CAL_UNI_DBF where M_CTN = ? ) and ( M_DATE = ? or ( M_GENERAL = 1 and datepart(dd, M_DATE) = datepart(dd, ?) and datepart(mm, M_DATE) = datepart(mm, ?) ) )

[fo_desks]
select rtrim(M_LABEL) from MUREXDB.TRN_DSKD_DBF

[plc_centers]
select rtrim(M_LABEL) from MUREXDB.TRN_PLCC_DBF

[proc_centers]
select rtrim(M_LABEL) from MUREXDB.TRN_PC_DBF

[entities]
select rtrim(M_LABEL) from MUREXDB.TRN_ENTD_DBF

[entity_sets]
select rtrim(M_LABEL) from MUREXDB.TRN_ENTS_DBF

[entity_set_ref]
select M_REFERENCE from MUREXDB.TRN_ENTS_DBF where M_LABEL = ?

[fo_desk_ref]
select M_REFERENCE from MUREXDB.TRN_DSKD_DBF where M_LABEL = ?

[plcc_ref]
select M_REFERENCE from MUREXDB.TRN_PLCC_DBF where M_LABEL = ?

[plcc_calendar]
select M_CALENDAR from MUREXDB.TRN_PLCC_DBF where M_LABEL = ?

[pc_ref]
select M_REFERENCE from MUREXDB.TRN_PC_DBF where M_LABEL = ?

[mds_ref]
select M_REFERENCE from MUREXDB.TRN_MDS_DBF where M_LABEL = ?

[mds_label]
select rtrim(M_LABEL) from MUREXDB.TRN_MDS_DBF where M_REFERENCE = ?

[mds_sr_ref]
select M_REFERENCE from MUREXDB.MD_RTSRH_DBF where M_LABEL = ?

[mds_template_ref]
select M_REFERENCE, M_ITEMS from MUREXDB.MD_TEMPL_DBF where M_LABEL = ?

[mds_template_item_ref]
select M_REF from MUREXDB.MD_ITEML_DBF where M_CTN = ? and M_REF <> 0

[mds_template_item]
select rtrim(M_LABEL), M_SOURCE, M_DEST, M_DEST_TYPE from MUREXDB.MD_ITEM_DBF where M_REFERENCE = ?

[scanner_template_ref]
select M_REFERENCE from MUREXDB.SCANNERCFG_DBF where M_TEMPLATE = ?

[entity_set_to_entities]
select rtrim(M_LABEL) from MUREXDB.TRN_ENTD_DBF
where M_REF in
( select T1.M_REF from MUREXDB.TRN_ENTDL_DBF T1, MUREXDB.TRN_ENTS_DBF T2 
  where T1.M_CTN       = T2.M_ENTITIES 
  and   T1.M__TYPE_EX_ = 4
  and   T2.M_LABEL     = ? 
)

[entity_to_entity_set]
select rtrim(M_LABEL) from MUREXDB.TRN_ENTS_DBF
where M_ENTITIES in
( select T1.M_CTN from MUREXDB.TRN_ENTDL_DBF T1, MUREXDB.TRN_ENTD_DBF T2
  where T1.M_REF       = T2.M_REF
  and   T1.M__TYPE_EX_ = 4
  and   T2.M_LABEL     = ?
)

[entity_set_to_plcc]
select rtrim(M_LABEL) from MUREXDB.TRN_PLCC_DBF
where M_ENT_SETS in
( select T1.M_CTN from MUREXDB.TRN_ENTSL_DBF T1, MUREXDB.TRN_ENTS_DBF T2
  where T1.M_REF       = T2.M_REFERENCE
  and   T1.M__TYPE_EX_ = 4
  and   T2.M_LABEL     = ?
)

[batch_to_report]
select rtrim(M_ELTNAME), rtrim(M_ELTFILLAB) from REPBATCH#TRN_RPBE_DBF where M_NAME = ?

[report_file_tables]
select rtrim(M_RP_FILE), rtrim(M_DBFNAME0), rtrim(M_DBFNAME1), rtrim(M_DBFNAME2), rtrim(M_DBFNAME3), rtrim(M_DBFNAME4) from MUREXDB.REPORT2#TRN_REP_DBF where M_RP_CODE = ?

[set_dyntable]
update MUREXDB.DYNDBF2#TRN_DYND_DBF set M_DBFHISTO = ? where M_CREATION = ?

[get_dyntable]
select rtrim(M_DBFHISTO) from MUREXDB.DYNDBF2#TRN_DYND_DBF where M_CREATION = ?

[set_repfile]
update MUREXDB.REPORT2#TRN_REP_DBF set M_RP_FILE = ? where M_RP_CODE = ?

[repfile_dyntable_check]
select A.M_RP_FILE, B.M_DBFHISTO from MUREXDB.REPORT2#TRN_REP_DBF A, MUREXDB.DYNDBF2#TRN_DYND_DBF B where A.M_RP_CODE = ? and A.M_DBFNAME0 = B.M_CREATION

[set_mds]
update MUREXDB.REPBATCH#TRN_RPBA_DBF set M_MDS = ? where M_NAME = ?

[closedown_date]
select M__DT_LAT from MUREXDB.TRN_ENTD_DBF where M_LABEL = ?

[get_mx_date_iso]
MUREXDB.get_mx_date_iso  @office = "__OFFICE__", @roll = __ROLL__

[nr_acc_lines]
select count(*) from MUREXDB.ACG_ENTRY_DBF where M_EN_DATE = ? and M_ENTITY = ?

[acc_roll_monitor]
select count(*) from MUREXDB.ACCOUNT#__MONTH____YEAR__#ACC_DT1_DBF where M_EN_DATE = ?

[price_load_cache_instrument]
select  rtrim(h.M_SE_LABEL), rtrim(h.M_SE_RTF0), rtrim(h.M_SE_GROUP), rtrim(r.M_SE_MARKET),
        rtrim(r.M_SE_CUR), rtrim(r.M_SE_TRDCL)
from    MUREXDB.SE_HEAD_DBF h, MUREXDB.SE_ROOT_DBF r
where   h.M_SE_LABEL = r.M_SE_LABEL
    and r.M_SE_DE != 'Y'
    and h.M_SE_LABEL in ( '__LIST__' )

[price_load_cache_clauses]
select  rtrim(M_SE_GROUP), rtrim(M_SE_TRDCL), rtrim(M_SE_CUR)
from    MUREXDB.SE_TRDC_DBF

[price_load_fetch_prices]
select  rtrim(x.M_INSTRUM), rtrim(x.M_MARKET),
        y.M_BID, y.M_ASK, y.M_IDENTITY,
        rtrim(m.M_LABEL)
from    MUREXDB.MPX_PRIC_DBF x, MUREXDB.MPY_PRIC_DBF y, OM_MAT_DBF m 
where   x.M_INSTRUM in ( '__LIST__' )
    and x.M__INDEX_ = y.M__INDEX_
    and x.M__ALIAS_= ?
    and x.M__DATE_ = ?
    and y.M_MATCOD *= m.M_CODE
    and ( m.M_DELETED = 0 or ( m.M_DELETED = 1 and m.M_DELET_D = ? ) ) 

[price_load_update]
update  MPY_PRIC_DBF
set     M_BID = ?, M_ASK = ?, M_RFDATE = ?, M_RFTIME = ?
where   M_IDENTITY = ?

[dividends]
select 
   Market = X.M_MARKET, Instrument = X.M_INSTRUM,  
   Y.M_EXDATE, Y.M_PAYDATE, Y.M_BID, Y.M_ASK
from
   MPY_DIV_DBF Y,
   MPX_DIV_DBF X
where 
   X.M__DATE_ = "__DATE__" and 
   Y.M_EXDATE <= dateadd(day,7, "__DATE__") and 
   Y.M_EXDATE >= "__DATE__" and 
   Y.M__INDEX_ = X.M__INDEX_ and
   ABS(Y.M_BID + Y.M_ASK ) > 0.00
order by
   Y.M_EXDATE, X.M_MARKET, X.M_INSTRUM

[mx_user_password_reset]
if (select count(*) from MUREXDB.MX_USER_DBF where M_LABEL="__USER__") >= 1
    update MUREXDB.MX_USER_DBF set M_PASSWORD="__PASSWORD__" where M_LABEL="__USER__"
if (select count(*) from MUREXDB.MX_USER_HPASSWORDS_DBF where M_USER_ID in ( select M_REFERENCE from MUREXDB.MX_USER_DBF where M_LABEL="__USER__")) >= 1
    delete MUREXDB.MX_USER_HPASSWORDS_DBF where M_USER_ID in ( select M_REFERENCE from MUREXDB.MX_USER_DBF where M_LABEL="__USER__" )
if (select count(*) from MUREXDB.USR_HPSW_DBF where M_USER_NAME="__USER__") >= 1
    delete MUREXDB.USR_HPSW_DBF where M_USER_NAME="__USER__"

[turboload_check_date]
select count(*) from GMP_GRCV_DBF where M__DATE_ = '___DATE___'

[turboload_get_curve_id]
select distinct h.M_SE_CODE, v.M_CURVE_ID, v.M_MARKET0, v.M_GROUP
from SE_MKTOP_DBF m, FIX_EPT_DBF f, SE_HEAD_DBF h, OP_SOW_DBF o,
FIXFLDVH_DBF fh ,FIXFLDVB_DBF ff, GMP_GRCV_DBF v
where m.M_SE_INUM = f.M_INT_NB
AND o.M_EQ_INUM = m.M_SE_INUM and o.M_EQ_RTYPE = 'INSTR' 
AND m.M_SE_LABEL = h.M_SE_LABEL
ANd h.M_SE_GEN = m.M_SE_GEN
AND v.M_LABEL0 = h.M_SE_LABEL
AND v.M__DATE_ = '___DATE___'
AND fh.M_LABEL = 'INSTR'
AND fh.M_NUM = m.M_SE_INUM
AND fh.M_LINK = ff.M_LINK
AND ff.M_INDEX = 0
AND f.M_SKELET = 'Turbo'
AND f.M_FAMILY = 'INSTR'
AND h.M_SE_GROUP = 'Warrant'
AND h.M_SE_TYPE = 'Flex'
AND o.M_EQ_OMAT > '___DATE___'

[turboload_update]
update GMP_CAAE_DBF
set M_DATE = ? , M_TIME = ? , 
    M_NVALUE0 = ? , M_NVALUE1 = ?
where M__DATE_ =  ?
      AND M_CURVE_ID = ?
      AND M__ALIAS_ = ?


[turboload_set_num_off]
set arithabort numeric_truncation off

[turboload_UpdateTurboNewIssue]
execute UpdateTurboNewIssue_31 '___WKN___', '___DATE___', ___STRIKE___, ___BARRIER___, '___DATESTAMP___', ___TIMESTAMP___, '___DESK___'

[turboload_cache_instrument]
select h.M_SE_LABEL, r.M_SE_MARKET, o.M_EQ_UNDERL
from SE_MKTOP_DBF m, SE_HEAD_DBF h, OP_SOW_DBF o, SE_ROOT_DBF r
where o.M_EQ_INUM = m.M_SE_INUM
and o.M_EQ_RTYPE = 'INSTR'
AND m.M_SE_LABEL = h.M_SE_LABEL
AND r.M_SE_LABEL = h.M_SE_LABEL
ANd h.M_SE_GEN = m.M_SE_GEN
order by h.M_SE_LABEL

[portfolio_type_1]
select M_TYPE from MUREXDB.TRN_PFLD_DBF where M_LABEL = ?

[portfolio_type_2]
select count(*) from MUREXDB.MUB#MUB_TREE_DBF where M_FATHER_L = ?

[ab_valid_books]
select rtrim(M_LABEL) from MUREXDB.TRN_PFLD_DBF where M_TYPE = 0

[ab_explode]
select rtrim(M_PFOLIO) from MUREXDB.TRN_PFLT_DBF where M_FATHER = ?

[ab_batches]
select rtrim(M_NAME) from MUREXDB.REPBATCH#TRN_RPBE_DBF where M_NAME like ?

[ab_delete_batch]
delete from MUREXDB.REPBATCH#TRN_RPCH_DBF where M_VALUE = ? and M_ID = 'DYNDBF PORTFOLIO'

[delete_filter]
delete from MUREXDB.REPBATCH#TRN_RPCH_DBF where M_VALUE = ? and M_RANGE = ?

[ab_define_batch]
insert into MUREXDB.REPBATCH#TRN_RPCH_DBF values (NULL, 'DYNDBF PORTFOLIO', ?, 0, ?, 'S', '', 0, 1)

[install_filter]
insert into MUREXDB.REPBATCH#TRN_RPCH_DBF values (NULL, ?, ?, ?, ?, ?, '', 0, 1)

[ab_check_batch_type]
select M_IDENTITY from MUREXDB.TRN_CMTX_DBF where M_RP_CODE in (select M_ELTNAME from MUREXDB.REPBATCH#TRN_RPBE_DBF where M_NAME = ?)

[ab_get_matrix_name]
select M_ELTNAME from MUREXDB.REPBATCH#TRN_RPBE_DBF where M_NAME = ?

[ab_get_unique_portfolio_id]
execute sp_MxGetUniqueId 'SPB_PTF', 'TRN_PFLD_DBF', 1

[ab_insert_combined_portfolio]
insert into
  MUREXDB.TABLE#DATA#PORTFOLI_DBF
  (M_LABEL, M_COKIS, M_MNGD_CERT)
values
  (?, ' ', 0)
insert into
  MUREXDB.TRN_PFLD_DBF
  (M_REF, M_LABEL, M_DSP_LABEL, M_DESC, M_COMMENT0, M_COMMENT1, M_COMMENT2, M_COMMENT3, M_COMMENT4, M_COMMENT5, M_TYPE, M_PCENTER, M_ACCSECTION, M_ENTITY, M_LEG_ENT, M_ACCCUR, M_FLT_DBF, M_FLT_LABEL, M_PTFHUB, M_PTFDRAFT, M_SUBTYPE, M_TRDSECTION)
values
  (?, ?, ?, ' ', ' ', ' ', ' ', ' ', ' ', ' ', 1, 0, ' ', ' ', 0, ' ', ' ', ' ', ' ', ' ', 0, 0)

[ab_get_portfolio_id]
select M_REF from MUREXDB.TRN_PFLD_DBF where M_LABEL = ?

[ab_add_portfolio]
insert into
  MUREXDB.MUB#GRP_COMB_DBF
  (M_GROUP, M_LABEL, M_UNIT, M_UNIT_TYPE, M_UNIT_REF)
values
  (?, ?, ?, 2, 0)

[ab_delete_portfolio]
delete MUREXDB.MUB#GRP_COMB_DBF where M_LABEL = ?
delete MUREXDB.TRN_PFLD_DBF where M_LABEL = ?
delete MUREXDB.TABLE#DATA#PORTFOLI_DBF where M_LABEL = ?

[ab_get_target_and_storage_id]
select M_CTRG_REF, M_CSTR_REF from MUREXDB.VAR_CMCF_DBF where M_REFERENCE in (select M_COM_REF from MUREXDB.VAR_EMCF_DBF where rtrim(M_LABEL) = ? )

[ab_update_storage]
update MUREXDB.VAR_CSCF_DBF set M_LABEL = ?, M_OUT_NAME = ? where M_REFERENCE = ?
update MUREXDB.VAR_CFCF_DBF set f.M_LABEL = s.M_LABEL from MUREXDB.VAR_CFCF_DBF f, MUREXDB.VAR_CSCF_DBF s where f.M_REFERENCE = s.M_FLD_REF and s.M_REFERENCE = ?

[ab_update_target]
update MUREXDB.VAR_CTCF_DBF set M_CFLT_REF = ? where M_REFERENCE = ?

[taper_dividend_get]
select "generator ", M_INSTRUM, "/", M_MARKET
from MUREXDB.MPX_DIV_DBF x
where x.M__DATE_ = ?
and M__ALIAS_ = 'FO'
and (x.M_IMPORT = 1 or x.M_IMPORT = 2 or x.M_IMPORT = 3)
and M__LINK_ <> 0
and (M_INSTRUM <> "DEM DAX CASH" or M_MARKET <> "DEM FSE")

[retrieve_mx_user]
select M_REFERENCE, M_DESC, M_PASSWORD, M_PASS_CD, M_LOCKED from MUREXDB.MX_USER_DBF where M_LABEL = ?

[retrieve_mx_users]
select M_REFERENCE, M_LABEL, M_DESC, M_PASSWORD, M_PASS_CD, M_LOCKED from MUREXDB.MX_USER_DBF

[nr_uncommitted_trades]
select count(*) from MUREXDB.STPFC_ENTRY_TABLE where STATUS_TAKEN = 'N' and STP_STATUS_VALIDATION_LEVEL <> 'COM'

[nr_uncommitted_mktops]
select count(*) from MUREXDB.STPEVT_ENTRY_TABLE where STATUS_TAKEN = 'N' and STP_STATUS_VALIDATION_LEVEL <> 'COM'

[nf_outstanding_trade_mop_validation]
select 
(select count(*) from MUREXDB.STPFC_ENTRY_TABLE where STATUS_TAKEN = 'N' and STP_STATUS_VALIDATION_LEVEL <> 'COM')
+
(select count(*) from MUREXDB.STPEVT_ENTRY_TABLE where STATUS_TAKEN = 'N' and STP_STATUS_VALIDATION_LEVEL <> 'COM')

[retrieve_mxml_tasks]
select rtrim(CODE), XML, XML_LZ, rtrim(TYPE_CODE), rtrim(FLOW_CODE), WORKFLOW_ID from MUREXDB.MXMLEX_TASK_TABLE where STATUS_TAKEN = 'N'

[retrieve_mxml_link]
select TO_TASK from MUREXDB.MXMLEX_LINK_TABLE where FROM_TASK = ? and FROM_NODE = ? and STATUS_TAKEN = 'N'

[retrieve_mxml_messages]
select REFERENCE_ID, STATUS_TAKEN, TS_TIME_LONG, PROC_TIME, WAIT_TIME, STATUS_TIME_LONG from MUREXDB.STP__WORKFLOW___ENTRY_TABLE where XMLFLOW_STATUS = ? and TIME_STAMP_DATE = ?

[mxml_messages_timerange]
select min(TS_TIME_LONG), max(TS_TIME_LONG) from MUREXDB.STP__WORKFLOW___ENTRY_TABLE where XMLFLOW_STATUS = ?

[retrieve_workflow_code]
select rtrim(MW_SUB_CODE) from MUREXDB.MW_LOGICAL_WORKFLOW_TBL where MW_ID = ?

[mxml_nr_messages]
select count(*) from MUREXDB.STP__WORKFLOW___ENTRY_TABLE where XMLFLOW_STATUS = ? and STATUS_TAKEN = ?

[mxml_nr_messages_per_day]
select count(*) from MUREXDB.STP__WORKFLOW___ENTRY_TABLE where XMLFLOW_STATUS = ? and STATUS_TAKEN = ? and STATUS_DATE = ?

[mxml_proc_time]
select avg(PROC_TIME) from MUREXDB.STP__WORKFLOW___ENTRY_TABLE where XMLFLOW_STATUS = ? and STATUS_TAKEN = ? and PROC_TIME > 0

[mxml_lost_messages]
select count(*) NR_MESSAGES, rtrim(XMLFLOW_STATUS), STATUS_TAKEN from MUREXDB.STP__WORKFLOW___ENTRY_TABLE where XMLFLOW_STATUS not in (select id from __MONDB_NAME__..mxml_nodes) group by XMLFLOW_STATUS, STATUS_TAKEN

[mxml_property_table]
if exists ( select 1 from sysobjects where name = 'KBC_MXML_PROPERTIES' )
begin
  drop table MUREXDB.KBC_MXML_PROPERTIES
end
go
 
create table MUREXDB.KBC_MXML_PROPERTIES
(
  PROPERTY  varchar(50) primary key,
  VALUE     varchar(300) null
)

[mxml_add_property]
insert into MUREXDB.KBC_MXML_PROPERTIES (PROPERTY, VALUE) values (?,?)

[mxml_update_property]
update MUREXDB.KBC_MXML_PROPERTIES set VALUE = ? where PROPERTY = ?

[retrieve_unprocessed_mxml_node_items]
select CONVERT( CHAR(10), TIME_STAMP_DATE, 103) TIME_STAMP_DATE, CONVERT( CHAR(8), TIME_STAMP_TIME, 8)  TIME_STAMP_TIME, FC_ORIGIN_ID, STP_STATUS_VALIDATION_LEVEL,JOB_DESCRIPTION,XMLFLOW_ERROR_TYPE,DOC_PARENT_ID,STPDOC_REF_TYPE,STPDOC_UNDERLYING_REF_TYPE, STPDOC_ACTION,QUEUENAME, STPDOC_LAST_SIGNER, STPDOC_DATA_TYPE1,DOC_TEMPLATE_NAME,DOC_TEMPLATE_TYPE from STPDOC_ENTRY_TABLE where XMLFLOW_STATUS in ( __IDLIST__ ) and STATUS_TAKEN = "N" order by TIME_STAMP_DATE,TIME_STAMP_TIME

[warehouse_filter]
select distinct M_NB from MUREXDB.RT_LNMOD_DBF where M_DOUBLE > 999999999999

[warehouse_tables]
select name from sysobjects where name like 'PS_%' and type = 'U'

[refresh_indexes]
insert __MONDB_NAME__..indexes (name, ntable, ndatabase, index_id, nr_keys) select name, object_name(id), db_name(), indid, keycnt - 1 from sysindexes where indid > 1 and indid < 255 and name not like 'KBC_REPBATCH_P%'

[count_indexes]
select count(*) from sysindexes where indid > 1 and indid < 255 and name not like 'KBC_REPBATCH_P%'

[missing_indexes]
select name, ntable, ndatabase, index_id, nr_keys from __MONDB_NAME__..indexes where name not in (select name from sysindexes where indid > 1 and indid < 255 and name not like 'KBC_REPBATCH_P%')

[cleanup_hist_acc_table]
delete from MUREXDB.ACG_TRD_GEN_HIS_DBF where M_TRADE > 0 and datediff( day, M_GI_DATE, '__DATE__' ) >= ?

[select_mapping]
select M_TYPE, M_DESC,
  M_SOURCEVAL1, M_SOURCEVAL2, M_SOURCEVAL3, M_SOURCEVAL4, M_SOURCEVAL5, M_SOURCEVAL6, M_SOURCEVAL7, M_SOURCEVAL8, M_SOURCEVAL9,
  M_DESTINVAL1, M_DESTINVAL2, M_DESTINVAL3, M_DESTINVAL4, M_DESTINVAL5, M_DESTINVAL6, M_DESTINVAL7, M_DESTINVAL8, M_DESTINVAL9
from MUREXDB.BXXM_CFG_REP

[select_dyn_audit_ref_data_and_rep_date2]
select top 1 M_REF_DATA, M_REP_DATE2
  from MUREXDB.DYN_AUDIT_REP
 where M_EXE_STATUS = 'S'
   and M_DELETED    = 'N'
   and M_OUTPUTTBL  = ?
   and M_TAG_DATA   = ?
 order by M_DATEGEN desc, M_TIMEGEN desc

[select_exchange_rates]
select CMUAL2+'/'+CMUALF as INSTRUMENT, AGEMID as EXCHANGE_RATE, M_C_PREC as PRECISION
  from BXXE_KLM_RATES_REP, BXXC_CFG_PRECCUR_REP
  where CENTRY  = ? 
  and CMUAL2 <> '   '
  and DBGGLD <= ?
  and DEIGLD >= ?
  and M_C_CURRENCY = CMUALF
union
select CMUALF+'/'+CMUAL2 as INSTRUMENT, 1 / (AGEMID - AGERST) as EXCHANGE_RATE, M_C_PREC as PRECISION
  from BXXE_KLM_RATES_REP, BXXC_CFG_PRECCUR_REP
  where CENTRY  = ?
  and CMUAL2 <> '   '
  and DBGGLD <= ?
  and DEIGLD >= ?
  and M_C_CURRENCY = CMUAL2
  and CMUALF+'/'+CMUAL2 not in (
  select CMUAL2+'/'+CMUALF
    from BXXE_KLM_RATES_REP
    where CENTRY  = ?
    and DBGGLD <= ?
    and DEIGLD >= ?  
  )
union
select left(M_BASKET,3)+'/'+left(M_CURRENCY,3) as INSTRUMENT, M_PRICE as EXCHANGE_RATE, M_C_PREC as PRECISION
  from BXXC_CFG_BSKCUR_REP, BXXC_CFG_PRECCUR_REP
  where M_C_CURRENCY = left(M_CURRENCY,3)
    and left(M_BASKET,3)+'/'+left(M_CURRENCY,3) not in (
    select CMUAL2+'/'+CMUALF
    from BXXE_KLM_RATES_REP
    where CENTRY  = ?
    and DBGGLD <= ?
    and DEIGLD >= ?
    )
    and left(M_BASKET,3)+'/'+left(M_CURRENCY,3) not in (
    select CMUALF+'/'+CMUAL2
    from BXXE_KLM_RATES_REP
    where CENTRY  = ?
    and DBGGLD <= ?
    and DEIGLD >= ?
    )
union
select distinct CMUAL2+'/'+CMUAL2 as INSTRUMENT, 1 as EXCHANGE_RATE, M_C_PREC as PRECISION
  from BXXE_KLM_RATES_REP, BXXC_CFG_PRECCUR_REP   
  where M_C_CURRENCY = CMUAL2  
    and CMUAL2 <> '   '

[select_last_valid_exchange_rates_1]
select CMUAL2+'/'+CMUALF as INSTRUMENT, AGEMID as EXCHANGE_RATE, M_C_PREC as PRECISION
  from BXXE_KLM_RATES_REP r1, BXXC_CFG_PRECCUR_REP
  where CMUAL2 <> '   '
  and CENTRY = ?
  and DEIGLD = 
  ( select max(r2.DEIGLD)
      from BXXE_KLM_RATES_REP r2
      where r2.CENTRY = r1.CENTRY
      and r2.CMUAL2 = r1.CMUAL2
      and r2.CMUALF = r1.CMUALF
  )
  and DBGGLD = 
  ( select max(r2.DBGGLD)
      from BXXE_KLM_RATES_REP r2
      where r2.CENTRY = r1.CENTRY
      and r2.CMUAL2 = r1.CMUAL2
      and r2.CMUALF = r1.CMUALF
      and r2.DEIGLD = r1.DEIGLD
  )  
  and M_C_CURRENCY = CMUALF

[select_last_valid_exchange_rates_2]
select CMUALF+'/'+CMUAL2 as INSTRUMENT, 1 / (AGEMID - AGERST) as EXCHANGE_RATE, M_C_PREC as PRECISION
  from BXXE_KLM_RATES_REP r1, BXXC_CFG_PRECCUR_REP
  where CENTRY = ?
  and CMUAL2 <> '   '
  and DEIGLD = 
  ( select max(r2.DEIGLD)
      from BXXE_KLM_RATES_REP r2
      where r2.CENTRY = r1.CENTRY
      and r2.CMUAL2 = r1.CMUAL2
      and r2.CMUALF = r1.CMUALF
  )
  and DBGGLD = 
  ( select max(r2.DBGGLD)
      from BXXE_KLM_RATES_REP r2
      where r2.CENTRY = r1.CENTRY
      and r2.CMUAL2 = r1.CMUAL2
      and r2.CMUALF = r1.CMUALF
      and r2.DEIGLD = r1.DEIGLD
  )  
  and M_C_CURRENCY = CMUAL2


