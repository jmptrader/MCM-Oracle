[BxxT_ACC_ACCACO_x_REP]
create table __TABLE__ (
  H_PORTALCODE  char(3),
  H_CONTRCOCODE char(3),
  H_ORGUNITCODE char(3),
  H_REFID       char(46), 
  B_OBJCODE     char(6),
  B_NB          char(50),
  B_ENT_GLCODE  char(4),
  B_GLKEY       char(40),
  B_MODELANR    char(12),
  B_AMOUNT      numeric(17,0),
  B_CURR        char(3),
  B_DC          char(3),
  B_OUTSTTYPE   char(3),
  B_BS_DAT      char(8))

[create_index]
create index __INDEX__ on __TABLE__ ( __COLUMNS__ )

[drop_table]
if object_id('__TABLE__') is not null execute('drop table __TABLE__')
