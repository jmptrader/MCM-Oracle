#!/usr/bin/bash

. /lch/fxclear/common/default/.profile

script.pl \
-name startup_workflows \
-xml xmlrequestscript_launchtask.xml \
-output \
-project common \
-sched_js startup_workflows
