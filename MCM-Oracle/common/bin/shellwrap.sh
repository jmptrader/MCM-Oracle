#!/usr/bin/env perl

. /murex/common/default/.userprofile

cd $MXCOMMON/$MXVERSION/bin

if [ -z "$1" ]; then
   echo "Usage: `basename $0` <shellscript>"
   exit 1
else 
   /usr/bin/ksh $1 $2 $3 $4 $5 $6 $7 $8 $9
fi
