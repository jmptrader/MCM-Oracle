#!/usr/bin/bash

. /lch/fxclear/common/default/.profile

script.pl \
-name shutdown_workflows \
-xml xmlrequestscript_stoptask.xml \
-output \
-project common \
-sched_js shutdown_workflows
