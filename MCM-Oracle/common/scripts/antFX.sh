#!/usr/bin/bash

. /lch/fxclear/common/default/.profile

XMLDIR=`get_config.pl XMLDIR`

antfile=${XMLDIR}/mxclearing-orchestrator-ant.xml

task=$1
marginRunNumber=$2

test "$marginRunNumber" = "` echo $marginRunNumber | tr -d [:alpha:]`" 
isNumeric=$?
tasksStandAlone=`awk -F\" '$0~/target/ && $0!~/\//{a=NR+1; task=$2} NR==a && $0!~/marginRunId/{print " "task}' $antfile`
tasksMarginRun=`awk -F\" '$0~/target/ && $0!~/\//{a=NR+1; task=$2} NR==a && $0~/marginRunId/{print " "task}' $antfile`

antRun () {
  task=$1

  ant.pl \
  -name $task \
  -xml $antfile \
  -target $task \
  -orchest \
  -output \
  -project common \
  -sched_js $task

  exit $?
}
 
antRunMR () {
  task=$1
  marginRunId=$2

  ant.pl \
  -name $task \
  -xml $antfile \
  -target $task \
  -jopt "-DmarginRunId=$marginRunId" \
  -orchest \
  -output \
  -project common \
  -sched_js $task

  exit $?
}

if [ $# -eq 1 ]; then
  echo $tasksStandAlone | grep -w $task> /dev/null && antRun $task
  echo $tasksStandAlone | grep -wv $task> /dev/null && printf "antTask $task not in \n$tasksStandAlone \n"
elif [ $# -eq 2 -a $isNumeric -eq 0 ]; then
  echo $tasksMarginRun | grep -w $task> /dev/null && antRunMR $task $marginRunNumber
  echo $tasksMarginRun | grep -wv $task> /dev/null && printf "antTask $task not in \n$tasksMarginRun \n"
elif [ $# -eq 2 -a $isNumeric -eq 1 ]; then
  echo $marginRunNumber "is not a numeric. It must be a margin run number"
elif [ $# -gt 2 -o $# -eq 0 ]; then
  printf "\nusage:\n ${0##*/} AntTask MarginRunId\n"
  printf "\nwith one parameter: the Ant task is in \n$tasksStandAlone\n"
  printf "\nwith two parameter: the Ant task is in \n$tasksMarginRun\n"
fi

