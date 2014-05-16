#!/usr/bin/bash

. /lch/fxclear/common/default/.profile

name=$1
nick=$2

xmlfile=${LOCAL_DIR}/${MXUSER}/scripts/mxProcessingScripts/common/${name}_ps.xml

NAME=`echo $name | tr '[:lower:]' '[:upper:]'`

scriptshell.pl \
-name $NAME \
-xml $xmlfile \
-split \
-nick $nick \
-sched_js $NAME \
-project common

