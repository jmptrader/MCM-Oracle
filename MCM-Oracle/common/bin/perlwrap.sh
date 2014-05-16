#!/bin/bash

. /lch/fxclear/common/default/.profile

cd $PROJECT_DIR/common/bin

if [ -z "$1" ]; then
   echo "Usage: `basename $0` <perlscript>"
   exit 1
else 
   perl $1 $2 $3 $4 $5 $6 $7 $8 $9
fi
