#!/bin/sh

if [ "a$1" != "a" ]
then
    MXENV=$1
    export MXENV
fi

mkdir -p /data/$MXENV/common/data
mkdir -p /data/$MXENV/common/log/gc
mkdir -p /data/$MXENV/common/run/pipes
mkdir -p /data/$MXENV/common/run/semaphores

mkdir -p /data/$MXENV/xx_apache/data/mason
mkdir -p /data/$MXENV/xx_apache/log
mkdir -p /data/$MXENV/xx_apache/run/sessions/data
mkdir -p /data/$MXENV/xx_apache/run/sessions/locks
