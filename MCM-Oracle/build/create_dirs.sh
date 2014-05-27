DATADIR=/lch/fxclear/data
DATA2DIR=/lch/fxclear/data2
SRV=`hostname`

mkdir $DATADIR/$MXENV
mkdir $DATADIR/$MXENV/xx_apache
mkdir $DATADIR/$MXENV/xx_apache/data
mkdir $DATADIR/$MXENV/xx_apache/data/mason
mkdir $DATADIR/$MXENV/xx_apache/data/mason/cache
mkdir $DATADIR/$MXENV/xx_apache/data/mason/obj
mkdir $DATADIR/$MXENV/xx_apache/log
mkdir $DATADIR/$MXENV/xx_apache/run
mkdir $DATADIR/$MXENV/xx_apache/run/sessions
mkdir $DATADIR/$MXENV/xx_apache/run/sessions/data
mkdir $DATADIR/$MXENV/xx_apache/run/sessions/locks

mkdir $DATA2DIR/$MXENV
mkdir $DATA2DIR/$MXENV/common
mkdir $DATA2DIR/$MXENV/common/data
mkdir $DATA2DIR/$MXENV/common/data/core
mkdir $DATA2DIR/$MXENV/common/data/ctrlm
mkdir $DATA2DIR/$MXENV/common/data/mms
mkdir $DATA2DIR/$MXENV/common/data/showplan
mkdir $DATA2DIR/$MXENV/common/data/sqltrace
mkdir $DATA2DIR/$MXENV/common/log
mkdir $DATA2DIR/$MXENV/common/log/gc
mkdir $DATA2DIR/$MXENV/common/log/jobs
mkdir $DATA2DIR/$MXENV/common/run
mkdir $DATA2DIR/$MXENV/common/run/pipes
mkdir $DATA2DIR/$MXENV/common/run/semaphores
mkdir $DATA2DIR/$MXENV/common/weblog

mkdir $DATA2DIR/$SRV
mkdir $DATA2DIR/$SRV/common
mkdir $DATA2DIR/$SRV/common/data
mkdir $DATA2DIR/$SRV/common/log
mkdir $DATA2DIR/$SRV/common/run
