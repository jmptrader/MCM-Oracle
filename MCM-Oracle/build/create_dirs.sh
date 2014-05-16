ENV=ATHENS
SRV=`hostname`
DATADIR=/lch/fxclear/data
DATA2DIR=/lch/fxclear/data2

mkdir $DATADIR/$ENV
mkdir $DATADIR/$ENV/xx_apache
mkdir $DATADIR/$ENV/xx_apache/data
mkdir $DATADIR/$ENV/xx_apache/data/mason
mkdir $DATADIR/$ENV/xx_apache/data/mason/cache
mkdir $DATADIR/$ENV/xx_apache/data/mason/obj
mkdir $DATADIR/$ENV/xx_apache/log
mkdir $DATADIR/$ENV/xx_apache/run
mkdir $DATADIR/$ENV/xx_apache/run/sessions
mkdir $DATADIR/$ENV/xx_apache/run/sessions/data
mkdir $DATADIR/$ENV/xx_apache/run/sessions/locks

mkdir $DATA2DIR/$ENV
mkdir $DATA2DIR/$ENV/common
mkdir $DATA2DIR/$ENV/common/data
mkdir $DATA2DIR/$ENV/common/data/core
mkdir $DATA2DIR/$ENV/common/data/ctrlm
mkdir $DATA2DIR/$ENV/common/data/mms
mkdir $DATA2DIR/$ENV/common/data/showplan
mkdir $DATA2DIR/$ENV/common/data/sqltrace
mkdir $DATA2DIR/$ENV/common/log
mkdir $DATA2DIR/$ENV/common/log/gc
mkdir $DATA2DIR/$ENV/common/log/jobs
mkdir $DATA2DIR/$ENV/common/run
mkdir $DATA2DIR/$ENV/common/run/pipes
mkdir $DATA2DIR/$ENV/common/run/semaphores
mkdir $DATA2DIR/$ENV/common/weblog

mkdir $DATA2DIR/$SRV
mkdir $DATA2DIR/$SRV/common
mkdir $DATA2DIR/$SRV/common/data
mkdir $DATA2DIR/$SRV/common/log
mkdir $DATA2DIR/$SRV/common/run
