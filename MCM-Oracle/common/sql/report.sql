drop table NDM_MESSAGES_REP
go

create table NDM_MESSAGES_REP   
  (INIT_IDEN_VL varchar(25),
   CTT_IDEN_VL int,
   CTT_VSN_NO int,
   OPR_CD char(2),
   MKT_OPR_CD char(2),
   OPR_TS char(19),
   COMPRESSED BIT default 0,
   DATA IMAGE null,
   UPD_TS DATETIME DEFAULT getDate(),
   SLCT_TS DATETIME null,
   PRIMARY KEY (INIT_IDEN_VL, CTT_IDEN_VL, CTT_VSN_NO, OPR_CD, MKT_OPR_CD, OPR_TS))
go

create index NDM_MESSAGES_REP_ND0 on MUREXDB.NDM_MESSAGES_REP(INIT_IDEN_VL, CTT_IDEN_VL, CTT_VSN_NO)
go

create index NDM_MESSAGES_REP_ND1 on MUREXDB.NDM_MESSAGES_REP(SLCT_TS)
go

