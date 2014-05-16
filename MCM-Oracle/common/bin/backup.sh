#!/bin/sh

DIR=$MXCOMMON/$MXVERSION
TIMESTAMP=`date +%y%m%d_%H%M%S`

BACKUPFILE=${DIR}/backups/backup_${TIMESTAMP}.tar

cd $DIR

tar cvfX $BACKUPFILE ./conf/backup.exclude -I ./conf/backup.include
gzip --best $BACKUPFILE

