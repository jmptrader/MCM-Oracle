#!/bin/sh

# Murex: 29 NOV 2010
# Murex: 3.1.20
MAJOR_VERSION=3.1
MINOR_VERSION=23
# Mx.3 Startup/Stop script for servers clients and utils.
# set -x 0

unset LD_LIBRARY_PATH_64
unset LD_LIBRARY_PATH_32

#--- Operating System ---
OS_TYPE=`uname`
PLATFORM_TYPE=`uname -p`

if [ "$OS_TYPE" = "AIX" ]; then
  MACHINE_NAME=`hostname -s`
else
  MACHINE_NAME=`hostname`
fi

_LS=/usr/bin/ls
_LS_L="/usr/bin/ls -l"
_PS=/usr/bin/ps
_TEE=/usr/bin/tee
_AWK=/usr/bin/awk
_ECHO=echo

if [ "$OS_TYPE" = "Linux" ]; then
_LS=/bin/ls
_LS_L="/bin/ls -l"
_PS=/bin/ps
_AWK=/bin/awk
_ECHO="echo -e"
fi

_ID=`id`
if [ "$OS_TYPE" = "AIX" ]; then
  USER_NAME=`echo $_ID| sed s/\(/" "/| sed s/\)/" "/| $_AWK '{printf "%s", substr($2,1,8)}'`
else
  USER_NAME=`echo $_ID| sed s/\(/" "/| sed s/\)/" "/| $_AWK '{print $2}'`
fi

PATH=.:$PATH
export PATH

##########################################
# Common application argument environnemnt
# Set it up here: Eventually modify the following lines according to your needs.
##########################################

# Path to store logs and PID files
LOG_PATH=logs

#Append log file at start/stop command
APPEND_LOG=1
#Create new empty log file at start/stop command
#APPEND_LOG=0

#Time loop value for the status option
#in seconds
LOOP_TIME=60

#Set File Desc default value
FD_LIMIT=1024

# Settings for the     Mx 3.1 File Server.
########################################
FILESERVER_PATH=fs
FILESERVER_CLASSPATH="murex/code/kernel/jar/common.jar:murex/code/kernel/jar/fileserver-client.jar:murex/code/kernel/jar/fileserver-server.jar"

# This file contains the complete path to the .jar files that are provided by the     Mx 3.1 File server.
# It is also used as a parameter for the other servers and the client.
MXJ_JAR_FILE=murex.download.service.download
MXJ_MONITOR_JAR_FILE=murex.download.monit_unix.download
MXJ_FILESERVER_CONFIG_FILE=murex.mxres.fs.fileserver.mxres

# Warning the MXJ_COMMON_JAR relies on the execution by any service launcher of the MXJ_JAR_FILE download.
MXJ_COMMON_JAR=jar/common.jar

# Settings for the     Mx 3.1 Xml Server.
########################################
# In case of no optional flags from the setting file
# set the var to null. Do not modify here.
XML_SERVER_ARGS=

# The xmlserver.mxres allow you to specify ports to use for the xmlserver.
#MXJ_XMLSERVER_CONFIG_FILE=public.mxres.xmlserver.xmlserver.mxres

# XmlServer Stat
#MXJ_STAT_FILE_NAME=stat
#MXJ_STAT_PERIOD=10000

# Settings for the MXML Server.
########################################
# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
DEFAULT_MXML_SERVER_ARGS=""
DEFAULT_MXML_JVM_ARGS="-Xms32M -Xmx192M -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000 -Djava.awt.headless=true"
if [ "$OS_TYPE" = "SunOS" ]; then
   case $PLATFORM_TYPE in
        sparc )
           DEFAULT_MXML_JVM_ARGS="-d64 -server $DEFAULT_MXML_JVM_ARGS"
        ;;
        i386 )
           DEFAULT_MXML_JVM_ARGS="-server $DEFAULT_MXML_JVM_ARGS"
        ;;
   esac
fi
MXML_SERVER_ARGS="$DEFAULT_MXML_SERVER_ARGS"
MXML_JVM_ARGS="$DEFAULT_MXML_JVM_ARGS"

DEFAULT_MXMLSECONDARY_JVM_ARGS="-Xms32M -Xmx128M -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000 -Djava.awt.headless=true"
if [ "$OS_TYPE" = "SunOS" ]; then
   case $PLATFORM_TYPE in
        sparc )
           DEFAULT_MXMLSECONDARY_JVM_ARGS="-d64 -server $DEFAULT_MXMLSECONDARY_JVM_ARGS"
        ;;
        i386 )
           DEFAULT_MXMLSECONDARY_JVM_ARGS="-server $DEFAULT_MXMLSECONDARY_JVM_ARGS"
        ;;
   esac
fi
MXMLSECONDARY_JVM_ARGS="$DEFAULT_MXMLSECONDARY_JVM_ARGS"

DEFAULT_MXMLSPACES_JVM_ARGS="-Xms32M -Xmx64M -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000 -Djava.awt.headless=true"
if [ "$OS_TYPE" = "SunOS" ]; then
   case $PLATFORM_TYPE in
        sparc )
           DEFAULT_MXMLSPACES_JVM_ARGS="-d64 -server $DEFAULT_MXMLSPACES_JVM_ARGS"
        ;;
        i386 )
           DEFAULT_MXMLSPACES_JVM_ARGS="-server $DEFAULT_MXMLSPACES_JVM_ARGS"
        ;;
   esac
fi
MXMLSPACES_JVM_ARGS="$DEFAULT_MXMLSPACES_JVM_ARGS"

DEFAULT_MXMLWORKER_JVM_ARGS="-Xms32M -Xmx128M -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000 -Djava.awt.headless=true"
if [ "$OS_TYPE" = "SunOS" ]; then
   case $PLATFORM_TYPE in
        sparc )
           DEFAULT_MXMLWORKER_JVM_ARGS="-d64 -server $DEFAULT_MXMLWORKER_JVM_ARGS"
        ;;
        i386 )
           DEFAULT_MXMLWORKER_JVM_ARGS="-server $DEFAULT_MXMLWORKER_JVM_ARGS"
        ;;
   esac
fi
MXMLWORKER_JVM_ARGS="$DEFAULT_MXMLWORKER_JVM_ARGS"

DEFAULT_ALERT_JVM_ARGS="-Xms32M -Xmx128M -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000"
if [ "$OS_TYPE" = "SunOS" ]; then
   case $PLATFORM_TYPE in
        sparc )
           DEFAULT_ALERT_JVM_ARGS="-d64 -server $DEFAULT_ALERT_JVM_ARGS"
        ;;
        i386 )
           DEFAULT_ALERT_JVM_ARGS="-server $DEFAULT_ALERT_JVM_ARGS"
        ;;
   esac
fi
ALERT_JVM_ARGS="$DEFAULT_ALERT_JVM_ARGS"

DEFAULT_STATISTICS_JVM_ARGS="-Xms32M -Xmx128M -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000"
if [ "$OS_TYPE" = "SunOS" ]; then
   case $PLATFORM_TYPE in
        sparc )
           DEFAULT_STATISTICS_JVM_ARGS="-d64 -server $DEFAULT_ALERT_JVM_ARGS"
        ;;
        i386 )
           DEFAULT_STATISTICS_JVM_ARGS="-server $DEFAULT_ALERT_JVM_ARGS"
        ;;
   esac
fi
STATISTICS_JVM_ARGS="$DEFAULT_STATISTICS_JVM_ARGS"
DEFAULT_MXML_PING_TIME=" /MXJ_LAUNCHER_PING_TIME:120000 /MXJ_LAUNCHER_PING_CHECK:1200000 /MXJ_PING_TIME:120000 /MXJ_PING_CHECK:1200000 /MXJ_MX_PING_TIME:120000 /MXJ_MX_PING_CHECK:1200000"


# Settings for the AMENDMENTAGENT Server.
############################################
# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
DEFAULT_AAGENT_SERVER_ARGS=""
DEFAULT_AAGENT_JVM_ARGS="-Xms32M -Xmx256M"
AAGENT_SERVER_ARGS="$DEFAULT_AAGENT_SERVER_ARGS"
AAGENT_JVM_ARGS="$DEFAULT_AAGENT_JVM_ARGS"


# Settings for MLC Services
######################################################################
# Logger for mlc not integrated with commons logging
# MXJ_MLC_LOGGER_FILE=public.mxres.mxmlc.mlclogger.xml
# Logger for mlc integrated with commons logging
MXJ_MLC_LOGGER_FILE=public.mxres.mxmlc.loggers.service_logger.mxres

# Settings for the MLC Server.
########################################
# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
DEFAULT_MXMLC_SERVER_ARGS=""
DEFAULT_MXMLC_JVM_ARGS="-Xms32M -Xmx2g -Djava.awt.headless=true -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000"

if ([ "$OS_TYPE" = "SunOS" ] || [ "$OS_TYPE" = "Linux" ]); then
	DEFAULT_MXMLC_JVM_ARGS="-server $DEFAULT_MXMLC_JVM_ARGS -XX:MaxPermSize=128M"
	# Create logs directory for gc logging
	mkdir -p logs/mxmlc/mxmlc/ >/dev/null 2>&1
	DEFAULT_MXMLC_JVM_ARGS="$DEFAULT_MXMLC_JVM_ARGS -verbose:gc -Xloggc:logs/mxmlc/mxmlc/mxmlc.gc.log -XX:+PrintGCDetails -XX:+PrintGCTimeStamps"
fi

if [ "$OS_TYPE" = "AIX" ]; then
        # Create logs directory for gc logging
        mkdir -p logs/mxmlc/mxmlc/ >/dev/null 2>&1
        DEFAULT_MXMLC_JVM_ARGS="$DEFAULT_MXMLC_JVM_ARGS -verbose:gc -Xverbosegclog:logs/mxmlc/mxmlc/mxmlc.gc.log -XX:+PrintGCDetails -XX:+PrintGCTimeStamps"
fi

MXMLC_SERVER_ARGS="$DEFAULT_MXMLC_SERVER_ARGS"
MXMLC_JVM_ARGS="$DEFAULT_MXMLC_JVM_ARGS"

# Settings for the LRB
########################################
DEFAULT_LRB_SERVER_ARGS=""
DEFAULT_LRB_JVM_ARGS="-Xms32M -Xmx512m -Djava.awt.headless=true -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000"

if ([ "$OS_TYPE" = "SunOS" ] || [ "$OS_TYPE" = "Linux" ]); then
        DEFAULT_LRB_JVM_ARGS="-server $DEFAULT_LRB_JVM_ARGS -XX:MaxPermSize=128M"
        # Create logs directory for gc logging
        mkdir -p logs/mxlrb/mxlrb/ >/dev/null 2>&1
        DEFAULT_LRB_JVM_ARGS="$DEFAULT_LRB_JVM_ARGS -verbose:gc -Xloggc:logs/mxlrb/mxlrb/mxlrb.gc.log -XX:+PrintGCDetails -XX:+PrintGCTimeStamps"
fi
if [ "$OS_TYPE" = "AIX" ]; then
        # Create logs directory for gc logging
        mkdir -p logs/mxlrb/mxlrb/ >/dev/null 2>&1
        DEFAULT_LRB_JVM_ARGS="$DEFAULT_LRB_JVM_ARGS -verbose:gc -Xverbosegclog:logs/mxlrb/mxlrb/mxlrb.gc.log -XX:+PrintGCDetails -XX:+PrintGCTimeStamps"
fi

LRB_SERVER_ARGS="$DEFAULT_LRB_SERVER_ARGS"
LRB_JVM_ARGS="$DEFAULT_LRB_JVM_ARGS"

# Settings for the WAREHOUSE Server.
########################################
# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
DEFAULT_WAREHOUSE_SERVER_ARGS=""
DEFAULT_WAREHOUSE_JVM_ARGS="-Xms32M -Xmx128M -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000"
if [ "$OS_TYPE" = "SunOS" ]; then
   DEFAULT_WAREHOUSE_JVM_ARGS="-server $DEFAULT_WAREHOUSE_JVM_ARGS"
fi
WAREHOUSE_SERVER_ARGS="$DEFAULT_WAREHOUSE_SERVER_ARGS"
WAREHOUSE_JVM_ARGS="$DEFAULT_WAREHOUSE_JVM_ARGS"

# Settings for the MANDATORY Server.
########################################
# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
DEFAULT_MANDATORY_SERVER_ARGS=""
DEFAULT_MANDATORY_JVM_ARGS="-Xms32M -Xmx256M"
if ([ "$OS_TYPE" = "SunOS" ] || [ "$OS_TYPE" = "Linux" ]); then
   DEFAULT_MANDATORY_JVM_ARGS="-server -XX:MaxPermSize=128M $DEFAULT_MANDATORY_JVM_ARGS"
fi
MANDATORY_SERVER_ARGS="$DEFAULT_MANDATORY_SERVER_ARGS"
MANDATORY_JVM_ARGS="$DEFAULT_MANDATORY_JVM_ARGS"

# Settings for the MDCS Server.
########################################
# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
DEFAULT_MDCS_SERVER_ARGS=""
DEFAULT_MDCS_JVM_ARGS="-Xms32M -Xmx1024M -Dsun.rmi.dgc.client.gcInterval=36000000 -Dsun.rmi.dgc.server.gcInterval=36000000"
if [ "$OS_TYPE" = "SunOS" ]; then
   DEFAULT_MDCS_JVM_ARGS="-server $DEFAULT_MDCS_JVM_ARGS"
fi
MDCS_SERVER_ARGS="$DEFAULT_MDCS_SERVER_ARGS"
MDCS_JVM_ARGS="$DEFAULT_MDCS_JVM_ARGS"
MXJ_MDCS_LOGGER_FILE=public.mxres.loggers.mxcontrib_logger.mxres

# Settings for the MDRS Server.
########################################
# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
DEFAULT_MDRS_SERVER_ARGS=""
DEFAULT_MDRS_JVM_ARGS="-Dsun.rmi.dgc.client.gcInterval=36000000 -Dsun.rmi.dgc.server.gcInterval=36000000"
if [ "$OS_TYPE" = "SunOS" ]; then
   DEFAULT_MDRS_JVM_ARGS="-server -Xms32M -Xmx512M $DEFAULT_MDRS_JVM_ARGS"
fi
MDRS_SERVER_ARGS="$DEFAULT_MDRS_SERVER_ARGS"
MDRS_JVM_ARGS="$DEFAULT_MDRS_JVM_ARGS"

# Settings for RTBS Server.
########################################
# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
DEFAULT_RTBS_SERVER_ARGS=""
DEFAULT_RTBS_JVM_ARGS="-Xmx256m -Dsun.rmi.dgc.client.gcInterval=36000000 -Dsun.rmi.dgc.server.gcInterval=36000000 -Dorg.xml.sax.driver=org.apache.crimson.parser.XMLReaderImpl"
if [ "$OS_TYPE" = "SunOS" ]; then
   DEFAULT_RTBS_JVM_ARGS="-server $DEFAULT_RTBS_JVM_ARGS"
fi
RTBS_SERVER_ARGS="$DEFAULT_RTBS_SERVER_ARGS"
RTBS_JVM_ARGS="$DEFAULT_RTBS_JVM_ARGS"
MXJ_RTBS_LOGGER_FILE=public.mxres.loggers.rtbs_logger.mxres

# Settings for Federation Server.
########################################
# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
DEFAULT_FEDERATION_SERVER_ARGS=""
DEFAULT_FEDERATION_JVM_ARGS="-Xmx256m"
if [ "$OS_TYPE" = "SunOS" ]; then
   DEFAULT_FEDERATION_JVM_ARGS="-server $DEFAULT_FEDERATION_JVM_ARGS"
fi
FEDERATION_SERVER_ARGS="$DEFAULT_FEDERATION_SERVER_ARGS"
FEDERATION_JVM_ARGS="$DEFAULT_FEDERATION_JVM_ARGS"
MXJ_FEDERATION_LOGGER_FILE=public.mxres.loggers.rtms_logger.mxres

# Settings for Entitlement Service.
########################################
# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
DEFAULT_ENTITLEMENT_ARGS=""
DEFAULT_ENTITLEMENT_JVM_ARGS="-Xms32M -Xmx256m -Dsun.rmi.dgc.client.gcInterval=36000000 -Dsun.rmi.dgc.server.gcInterval=36000000"
if [ "$OS_TYPE" = "SunOS" ]; then
   DEFAULT_ENTITLEMENT_JVM_ARGS="-server $DEFAULT_ENTITLEMENT_JVM_ARGS"
fi
ENTITLEMENT_ARGS="$DEFAULT_ENTITLEMENT_ARGS"
ENTITLEMENT_JVM_ARGS="$DEFAULT_ENTITLEMENT_JVM_ARGS"
# The file contains the complete path to the .jar, and .so files that are required by the entitlement service
if [ "$OS_TYPE" = "SunOS" ]; then
MXJ_ENTITLEMENT_JAR_FILE="murex.download.interfaces_srv_sol.download"
elif [ "$OS_TYPE" = "Linux" ]; then
MXJ_ENTITLEMENT_JAR_FILE="murex.download.interfaces_srv_linux.download"
fi

# Settings for the MXHIBERNATE Server.
########################################
# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
DEFAULT_MXHIBERNATE_SERVER_ARGS=""
DEFAULT_MXHIBERNATE_JVM_ARGS="-Xms32M -Xmx512M -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000"
if ([ "$OS_TYPE" = "SunOS" ] || [ "$OS_TYPE" = "Linux" ]); then
   DEFAULT_MXHIBERNATE_JVM_ARGS="-server -XX:MaxPermSize=128M $DEFAULT_MXHIBERNATE_JVM_ARGS"
fi
MXHIBERNATE_SERVER_ARGS="$DEFAULT_MXHIBERNATE_SERVER_ARGS"
MXHIBERNATE_JVM_ARGS="$DEFAULT_MXHIBERNATE_JVM_ARGS"

# Settings for the PRINTSRV Service.
########################################
# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
DEFAULT_PRINTSRV_ARGS=""
DEFAULT_PRINTSRV_JVM_ARGS="-Xms32M -Xmx1024M -Xbootclasspath/p:jar/xercesImpl-2.9.1.jar:jar/xml-apis-1.3.04.jar:jar/xalan-2.7.1m1.jar:jar/serializer-2.7.1.jar -Djava.awt.headless=true -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000"
if ([ "$OS_TYPE" = "SunOS" ] || [ "$OS_TYPE" = "Linux" ]); then
   DEFAULT_PRINTSRV_JVM_ARGS="-server -XX:MaxPermSize=128M $DEFAULT_PRINTSRV_JVM_ARGS"
fi
PRINTSRV_ARGS="$DEFAULT_PRINTSRV_ARGS"
PRINTSRV_JVM_ARGS="$DEFAULT_PRINTSRV_JVM_ARGS"

# Settings for the MXDATAPUBLISHER Service.
########################################
# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
DEFAULT_MXDATAPUBLISHER_ARGS=""
DEFAULT_MXDATAPUBLISHER_JVM_ARGS="-Xms32M -Xmx512M -Xbootclasspath/p:jar/xercesImpl-2.9.1.jar:jar/xml-apis-1.3.04.jar:jar/xalan-2.7.1m1.jar:jar/serializer-2.7.1.jar -Djava.awt.headless=true -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000"
if ([ "$OS_TYPE" = "SunOS" ] || [ "$OS_TYPE" = "Linux" ]); then
   DEFAULT_MXDATAPUBLISHER_JVM_ARGS="-server -XX:MaxPermSize=128M $DEFAULT_MXDATAPUBLISHER_JVM_ARGS"
fi
MXDATAPUBLISHER_ARGS="$DEFAULT_MXDATAPUBLISHER_ARGS"
MXDATAPUBLISHER_JVM_ARGS="$DEFAULT_MXDATAPUBLISHER_JVM_ARGS"


# Settings for interfaces services launchers.
#######################
# Common settings for interfaces services
COMMON_INTERFACES_JVM_ARGS="-Xbootclasspath/p:jar/xercesImpl-2.9.1.jar:jar/xml-apis-1.3.04.jar:jar/xalan-2.7.1m1.jar:jar/serializer-2.7.1.jar"
if [ "$OS_TYPE" = "AIX" ]; then
        COMMON_INTERFACES_JVM_ARGS="-Xbootclasspath/p:jar/xml-apis-1.3.04.jar:jar/xalan-2.7.1m1.jar:jar/serializer-2.7.1.jar"
fi
INTERFACES_SRV_JVM_ARGS=""

# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
# Configuration for Bloomberg Security Import service launcher
BBG_SEC_IMPORT_CONFIG_FILE=public.mxres.common.launcherbbgsecurityimport.mxres
DEFAULT_BSIS_ARGS=""
DEFAULT_BSIS_JVM_ARGS="-Xms64M -Xmx128M"
BSIS_ARGS="$DEFAULT_BSIS_ARGS"
BSIS_JVM_ARGS="$DEFAULT_BSIS_JVM_ARGS"
if ([ "$OS_TYPE" = "SunOS" ] || [ "$OS_TYPE" = "Linux" ]); then
   BSIS_JVM_ARGS="-server $BSIS_JVM_ARGS"
fi

# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
# Configuration for Markit Credit service launcher
MARKIT_CREDIT_CONFIG_FILE=public.mxres.common.launchermarkitcredit.mxres
DEFAULT_MARKIT_CREDIT_ARGS=""
DEFAULT_MARKIT_CREDIT_JVM_ARGS="-Xms64M -Xmx128M"
MARKIT_CREDIT_ARGS="$DEFAULT_MARKIT_CREDIT_ARGS"
MARKIT_CREDIT_JVM_ARGS="$DEFAULT_MARKIT_CREDIT_JVM_ARGS"
if ([ "$OS_TYPE" = "SunOS" ] || [ "$OS_TYPE" = "Linux" ]); then
   MARKIT_CREDIT_JVM_ARGS="-server $MARKIT_CREDIT_JVM_ARGS"
fi

# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
# Configuration for RTBSBBG service launcher
RTBSBBG_CONFIG_FILE=public.mxres.common.launcherrtbsbbg.mxres
DEFAULT_RTBSBBG_ARGS=""
DEFAULT_RTBSBBG_JVM_ARGS="-Xms64M -Xmx256M"
RTBSBBG_ARGS="$DEFAULT_RTBSBBG_ARGS"
RTBSBBG_JVM_ARGS="$DEFAULT_RTBSBBG_JVM_ARGS"
if ([ "$OS_TYPE" = "SunOS" ] || [ "$OS_TYPE" = "Linux" ]); then
   RTBSBBG_CREDIT_JVM_ARGS="-server $RTBSBBG_JVM_ARGS"
fi

# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
# Configuration for RTBSRFA service launcher
RTBSRFA_CONFIG_FILE=public.mxres.common.launcherrtbsrfa.mxres
DEFAULT_RTBSRFA_ARGS=""
DEFAULT_RTBSRFA_JVM_ARGS="-Xms64M -Xmx256M"
RTBSRFA_ARGS="$DEFAULT_RTBSRFA_ARGS"
RTBSRFA_JVM_ARGS="$DEFAULT_RTBSRFA_JVM_ARGS"
if ([ "$OS_TYPE" = "SunOS" ] || [ "$OS_TYPE" = "Linux" ]); then
   RTBSRFA_CREDIT_JVM_ARGS="-server $RTBSRFA_JVM_ARGS"
fi

# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
# Configuration for Markit Equity service launcher
MARKIT_EQUITY_CONFIG_FILE=public.mxres.common.launchermarkitequity.mxres
FIX_CONFIG_FILE=public.mxres.common.launchermxfix.mxres
DEFAULT_MARKIT_EQUITY_ARGS=""
DEFAULT_MARKIT_EQUITY_JVM_ARGS="-Xms64M -Xmx128M"
MARKIT_EQUITY_ARGS="$DEFAULT_MARKIT_EQUITY_ARGS"
MARKIT_EQUITY_JVM_ARGS="$DEFAULT_MARKIT_EQUITY_JVM_ARGS"
if ([ "$OS_TYPE" = "SunOS" ] || [ "$OS_TYPE" = "Linux" ]); then
   MARKIT_EQUITY_JVM_ARGS="-server $MARKIT_EQUITY_JVM_ARGS"
fi

# Settings for the XATransactionLogger.
########################################
# The following setting is overrwitten by the one defined in mxg2000_settings, if exists.
MXJ_DBSOURCE=public/mxres/common/dbconfig/dbsource.mxres
# Period expressed in minutes
XA_CHECK_PERIOD=5

# Settings for all applications.
################################
# Default setting file.
SETTINGS_FILE=mxg2000_settings.sh

# Warning the MXJ_BOOT_JAR file MUST be on the same directory as the executable.
MXJ_BOOT_JAR=mxjboot.jar
MXJ_BOOT_JAR_FILE=murex.download.mxjboot.download

# Define your default Launcher environement
# The launcherall.mxres descibe the flags you use to launch the application itself.
MXJ_CONFIG_FILE=public.mxres.common.launcherall.mxres

# Define your default Mandatory environement
# The launchermandatory.mxres descibes the mandatory services.
MXJ_MANDATORY_CONFIG_FILE=murex.mxres.common.launchermandatory.mxres

# Define your site name
# The site.mxres descibe the site itself.
MXJ_SITE_NAME=site1

# Define your hub name
# The site.mxres descibe the site itself.
MXJ_HUB_NAME=hub1

# Define your default MxMlExchange environement
# The file launchermxmlexchangeall.mxres describe the flags you use to launch the application itself.
MXJ_MXMLEX_CONFIG_FILE=public.mxres.common.launchermxmlexchangeall.mxres
MXJ_MXMLEX_CONFIG_FILE_SECONDARY=public.mxres.common.launchermxmlexchangesecondary.mxres
MXJ_MXMLEX_CONFIG_FILE_SPACES=public.mxres.common.launchermxmlexchangespaces.mxres
MXJ_MXMLEX_CONFIG_FILE_WORKER=public.mxres.common.launchermxmlworker.mxres

#Define your default Alert Engine environment
MXJ_MXMLEX_CONFIG_FILE_ALERT=public.mxres.common.launcheralert.mxres

#Define your default Statistics Engine environment
MXJ_MXMLEX_CONFIG_FILE_STATISTICS=public.mxres.common.launcherstatistics.mxres

# Define your default AmendmentAgent environment
# The file launcheraagent.mxres describe the flags you use to launch the application itself.
MXJ_AAGENT_CONFIG_FILE=public.mxres.common.launcheraagent.mxres

# Define your default Warehouse environement
# The file launcherwarehouse.mxres describe the flags you use to launch the application itself.
MXJ_WAREHOUSE_CONFIG_FILE=public.mxres.common.launcherwarehouse.mxres

# Define your default MxRepository environement
# The file launchermxrepository.mxres describe the flags you use to launch the application itself.
MXJ_MXREPOSITORY_CONFIG_FILE=public.mxres.common.launchermxrepository.mxres

# Define your default Mx Contribution environement
MXJ_CONTRIBUTION_CONFIG_FILE=public.mxres.common.launchermxcontribution.mxres

# Define your default MDCS environement
# The file launcherwarehouse.mxres describe the flags you use to launch the application itself.
MXJ_MDCS_CONFIG_FILE=public.mxres.common.launchermxcache.mxres

# Define your default MDRS environement
# The file launchermxmarketdatarepository.mxres describe the flags you use to launch the application itself.
MXJ_MDRS_CONFIG_FILE=public.mxres.common.launchermxmarketdatarepository.mxres

#Define your default ActivityFeeder environment
# The file launchermxactivityfeeders.mxres describe the flags you use to launch the application itself.
MXJ_ACTIVITY_FEEDER_CONFIG_FILE=public.mxres.common.launchermxactivityfeeders.mxres
MXJ_ACTIVITY_FEEDER_LOGGER_FILE=public.mxres.loggers.mxcontrib_logger.mxres

# Define your default RTBS environement
# The file launcherrtbs.mxres describe the flags you use to launch the application itself.
MXJ_RTBS_CONFIG_FILE=public.mxres.common.launcherrtbs.mxres

# Define your default FEDERATION environement
# The file launchermxfederation.mxres describe the flags you use to launch the application itself.
MXJ_FEDERATION_CONFIG_FILE=public.mxres.common.launchermxfederation.mxres

# Define your default Entitlement Service environement
# The file launchermxentitlement.mxres describe the flags you use to launch the application itself.
MXJ_ENTITLEMENT_CONFIG_FILE=public.mxres.common.launchermxentitlement.mxres

# Define your default MxHibernate environement
# The file launchermxhibernate.mxres describe the flags you use to launch the application itself.
MXJ_MXHIBERNATE_CONFIG_FILE=public.mxres.common.launchermxhibernate.mxres

# Define your default PrintSrv environement
# The file launcherprintsrv.mxres describe the flags you use to launch the application itself.
MXJ_PRINTSRV_CONFIG_FILE=public.mxres.common.launcherprintsrv.mxres
MXJ_PRINTSRV_JAR_FILE=murex.download.printsrv.download

# Define your default MxDataPublisher environement
# The file launchermxdatapublisher.mxres describe the flags you use to launch the application itself.
MXJ_MXDATAPUBLISHER_CONFIG_FILE=public.mxres.common.launchermxdatapublisher.mxres

# Define your default MLC environement
# The file launchermxmlc.mxres describe the flags you use to launch the application itself.
MXJ_MXMLC_CONFIG_FILE=public.mxres.common.launchermxmlc.mxres
MXJ_MXLRB_CONFIG_FILE=public.mxres.common.launchermxlrb.mxres
MXJ_MXMLC_ANT_BUILD_FILE=public.mxres.mxmlc.mlc_ant_tasks.mxres
MXJ_MXMLC_ANT_TARGET=startup-mlc
MXJ_LRB_ANT_TARGET=startup-lrb

# Define your default script ant environement
MXJ_ANT_BUILD_FILE=public.mxres.script.middleware.tasks.mxres
MXJ_ANT_TARGET=sample

# Define the timeout in second used to stop a process launcher
# This setting can be overwritten by the one defined in mxg2000_settings, if exists,
# or by the one passed as a flag parameter.
if [ "$MXJ_LAUNCHER_MAX_KILL_TIME" = "" ]; then
   MXJ_LAUNCHER_MAX_KILL_TIME=20
fi

# Setting for murexnet.
#######################
#Port used by the murexnet, defined here if not setted in mxg2000_settings file
#(backward compatibility)
MUREXNET_PORT=8000

# In case of no optional flags from the setting file
# set the var to null. Do not modify here.
MUREXNET_ARGS=

# Settings for clients.
#######################
# Define your default client  environement
MXJ_PLATFORM_NAME=MX
MXJ_PROCESS_NICK_NAME=MX
# Define your default Client macro XML file
MXJ_SCRIPT=key.xml

# Settings for ECN tasks launchers.
#######################
# The file launcherubs.mxres describes the configuration for the UBS task launcher
MXJ_UBS_CONFIG_FILE=public.mxres.common.launcherubs.mxres
# The file launcherlbn.mxres describes the configuration for the LBN task launcher
MXJ_LBN_CONFIG_FILE=public.mxres.common.launcherlbn.mxres
# The file launcherfixlistener.mxres describes the configuration for the FIXListener task launcher
MXJ_FIXLISTENER_CONFIG_FILE=public.mxres.common.launcherfixlistener.mxres

###################################
# End of user definables settings #
###################################

######################################################################
# Sourcing Setting File and Setting env.
######################################################################
Setting_Env() {
# Java and DATABASE SERVER settings file sourced.
# Can be overwritten by option -i:setting_file

if [ ! -f `dirname $0`/$SETTINGS_FILE ] ; then
   $_ECHO "    Mx 3.1: Fatal ERROR: "
   $_ECHO "          Environnement settings file: $SETTINGS_FILE not found !"
   $_ECHO "          Or : forget, -i:setting_file."
   exit 1
fi

. `dirname $0`/$SETTINGS_FILE

RTISESSION_XWIN_DISP=$DISPLAY
RTICACHESESSION_XWIN_DISP=$DISPLAY
# Default log4j logger configuration files
#
if [ "$MXJ_DEFAULT_LOGGER_FILE" = "" ]; then
  MXJ_DEFAULT_LOGGER_FILE=public.mxres.loggers.default_logger.mxres
fi
MXJ_LOGGER_FILE=$MXJ_DEFAULT_LOGGER_FILE

#--- Third Party LIBRARY environment.
#####################################
# Path to third party Libraries.
if [ "$OS_TYPE" = "AIX" ]; then
   LIBPATH=3pl:$LIBPATH
else
LD_LIBRARY_PATH=3pl:$LD_LIBRARY_PATH
fi

#--- bin.mx path
#####################################
# Path to bin.mx libraries
if [ "$OS_TYPE" = "AIX" ]; then
   LIBPATH=bin.mx:$LIBPATH
else
LD_LIBRARY_PATH=bin.mx:$LD_LIBRARY_PATH
fi

#--- Third Party Path.
#####################################
# Add third party folder to the Path.
PATH=3pl:$PATH

#--- OS LIBARY environment.
###########################
# Path to OS Library.
if [ "$OS_TYPE" = "SunOS" ]; then
   if [ "$MX_BITNESS" = "64" ]; then
     LD_LIBRARY_PATH=/usr/lib/lwp/amd64:$LD_LIBRARY_PATH
   else
     LD_LIBRARY_PATH=/usr/lib/lwp:$LD_LIBRARY_PATH
   fi   
   export LD_LIBRARY_PATH
fi

#--- 64 bit path.
###########################
# Path to 64 bit libraries.
if [ "$OS_TYPE" = "SunOS" ]; then
   if [ "$MX_BITNESS" = "64" ]; then
     LD_LIBRARY_PATH=/usr/lib/amd64:$LD_LIBRARY_PATH
   fi   
   export LD_LIBRARY_PATH
fi

#--- Java environment.
######################
# Path to the Java binaries, the 'libjvm.so' dynamic library
# Set it up here: Uncomment and/or modify the following lines according to your setup.

if [ "$JAVAHOME" = "" ] ; then
   $_ECHO "    Mx 3.1: Fatal ERROR: "
   $_ECHO "          Please specify the Java environment "
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ "$OS_TYPE" = "SunOS" ]; then
   if [ -d $JAVAHOME/jre ]; then
   case $PLATFORM_TYPE in
        sparc )
      JAVA_LIBRARY_PATH=$JAVAHOME/jre/lib/sparc
        ;;
        i386 )
      if [ "$MX_BITNESS" = "64" ]; then
         JAVA_LIBRARY_PATH=$JAVAHOME/jre/lib/amd64/server
      else
         JAVA_LIBRARY_PATH=$JAVAHOME/jre/lib/i386
      fi
        ;;
   esac
   else
   case $PLATFORM_TYPE in
        sparc )
      JAVA_LIBRARY_PATH=$JAVAHOME/lib/sparc
        ;;
        i386 )
        JAVA_LIBRARY_PATH=$JAVAHOME/lib/i386
        ;;
   esac
   fi
   PATH=$JAVAHOME/bin:$PATH
   LD_LIBRARY_PATH=$JAVA_LIBRARY_PATH:$LD_LIBRARY_PATH
   LIB_EXT=so
   export LD_LIBRARY_PATH
   # Set Numeric format for SUN
   LC_NUMERIC=en_US
   export LC_NUMERIC
fi
if [ "$OS_TYPE" = "AIX" ]; then
   JAVA_LIBRARY_PATH=$JAVAHOME/jre/bin/classic
   PATH=$JAVAHOME/jre/bin:$JAVAHOME/bin:$PATH
   LIBPATH=$JAVA_LIBRARY_PATH:$JAVAHOME/jre/bin:$LIBPATH
   LIB_EXT=a
   export LIBPATH
   # Set Numeric format for IBM
   LANG=en_US
   export LANG
   export AIXTHREAD_SCOPE=S
   export AIXTHREAD_MUTEX_DEBUG=OFF
   export AIXTHREAD_RWLOCK_DEBUG=OFF
   export AIXTHREAD_COND_DEBUG=OFF
   if [ "$LDR_CNTRL" != "" ] ; then
      LDR_CNTRL_MAXDATA=`echo $LDR_CNTRL | grep "MAXDATA"`
          $_ECHO "WARNING: LDR_CNTRL is set with MAXDATA value:"$LDR_CNTRL
   fi
   # Settings to force JAVA to go through ipv4 stack instead of ipv6.
   export IBM_JAVA_OPTIONS="-Djava.net.preferIPv4Stack=true  ${IBM_JAVA_OPTIONS}"
fi
if [ "$OS_TYPE" = "HP-UX" ]; then
   JAVA_LIBRARY_PATH=$JAVAHOME/jre/lib/PA_RISC2.0/hotspot
   PATH=$JAVAHOME/bin:$PATH
   SHLIB_PATH=$JAVA_LIBRARY_PATH:$SHLIB_PATH
   LIB_EXT=sl
   export SHLIB_PATH
fi
if [ "$OS_TYPE" = "Linux" ]; then
   JAVA_VENDOR=`$JAVAHOME/jre/bin/java -version 2>&1 | grep IBM`
   if [ $? -ne 0 ] ; then
      #Assume we are using SUN JVM
      JAVA_LIBRARY_PATH=$JAVAHOME/jre/lib/i386/client
   else
      #Assume we are using IBM JVM
      JAVA_LIBRARY_PATH=$JAVAHOME/jre/bin/server
   fi
   LD_LIBRARY_PATH=$JAVA_LIBRARY_PATH:$LD_LIBRARY_PATH
   PATH=$JAVAHOME/bin:$PATH
   LIB_EXT=so
   LC_NUMERIC=en_US
   export LIB_EXT LC_NUMERIC LD_LIBRARY_PATH
fi

export PATH

#---  MX Bin library configuration

################################################

case $OS_TYPE in
        SunOS )
        LD_LIBRARY_PATH=./bin:$LD_LIBRARY_PATH
        export LD_LIBRARY_PATH
        PATH=./bin:$PATH
        export PATH
        ;;
        AIX )
        LIBPATH=./bin:$LIBPATH
        export LIBPATH
        ;;
        HP-UX )
        SHLIB_PATH=./bin:$SHLIB_PATH
        export SHLIB_PATH
        ;;
        Linux )
        LD_LIBRARY_PATH=./bin:$LD_LIBRARY_PATH
        export LD_LIBRARY_PATH
        ;;
        * )
        $_ECHO "Warning : Do not know how to handle this OS type $OS_TYPE."
        ;;
esac


#--- Sybase environment used only by the launcher.
##################################################

if [ "$SYBASE" != "" ] ; then
case $OS_TYPE in
        SunOS )
        SYBASE_OCS=OCS-15_0
        LD_LIBRARY_PATH=$SYBASE/$SYBASE_OCS/lib:$SYBASE/lib:.:$LD_LIBRARY_PATH
        export LD_LIBRARY_PATH
        ;;
        AIX )
        SYBASE_OCS=OCS-15_0
        LIBPATH=$SYBASE/$SYBASE_OCS/lib:.:$LIBPATH
        export LIBPATH
        ;;
        HP-UX )
        SYBASE_OCS=OCS-15_0
        SHLIB_PATH=$SYBASE/$SYBASE_OCS/lib:$SYBASE/lib:.:$SHLIB_PATH
        export SHLIB_PATH
        ;;
        Linux )
        SYBASE_OCS=OCS-15_0
        LD_LIBRARY_PATH=$SYBASE/$SYBASE_OCS/lib:$SYBASE/lib:.:$LD_LIBRARY_PATH
        export LD_LIBRARY_PATH
        ;;
        * )
        $_ECHO "Warning : Do not know how to handle this OS type $OS_TYPE."
        ;;
esac
if [ "$SYBASE_OCS" != "" ] ; then
        PATH=$SYBASE/$SYBASE_OCS/bin:$PATH
        export PATH
fi
export SYBASE_OCS
fi

#--- Oracle environment.
##################################################

if [ "$ORACLE_HOME" != "" ] ; then
case $OS_TYPE in
        SunOS )
        if [ "$MX_BITNESS" = "64" ]; then
            LD_LIBRARY_PATH=$ORACLE_HOME/lib:/usr/ccs/lib/amd64:.:$LD_LIBRARY_PATH
        else
            # Keep LD_LIBRARY_PATH_64 for compatibility with SunOS 64bit JVM (java -d64), which concatenates it with LD_LIBRARY_PATH
            LD_LIBRARY_PATH_64=$ORACLE_HOME/lib:$LD_LIBRARY_PATH_64
            export LD_LIBRARY_PATH_64
            LD_LIBRARY_PATH=$ORACLE_HOME/lib32:$ORACLE_HOME/lib:/usr/ccs/lib:.:$LD_LIBRARY_PATH
        fi
        export LD_LIBRARY_PATH
        PATH=$ORACLE_HOME/bin:$PATH
        export PATH
        ;;
        AIX )
        LIBPATH=$ORACLE_HOME/lib32:$ORACLE_HOME/lib:.:$LIBPATH
        export LIBPATH
        ;;
        HP-UX )
        SHLIB_PATH=$ORACLE_HOME/lib32:$ORACLE_HOME/lib:.:$SHLIB_PATH
        export SHLIB_PATH
        ;;
        Linux )
        LD_LIBRARY_PATH=$ORACLE_HOME/lib32:$ORACLE_HOME/lib:/usr/ccs/lib:.:$LD_LIBRARY_PATH
        export LD_LIBRARY_PATH
        ;;
        * )
        $_ECHO "Warning : Do not know how to handle this OS type $OS_TYPE."
        ;;
esac
fi

#--- Datasynpase GridServer environment.
##################################################
if [ "$DS_CLIENTLIB_PATH" != "" ] ; then
case $OS_TYPE in
        SunOS )
        if [ "$MX_BITNESS" != "64" ]; then
           LD_LIBRARY_PATH=$DS_CLIENTLIB_PATH:$LD_LIBRARY_PATH
           export LD_LIBRARY_PATH
        fi
        ;;
        AIX )
        LIBPATH=$DS_CLIENTLIB_PATH:$LIBPATH
        export LIBPATH
        ;;
        HP-UX )
        SHLIB_PATH=$DS_CLIENTLIB_PATH:$SHLIB_PATH
        export SHLIB_PATH
        ;;
        Linux )
        LD_LIBRARY_PATH=$DS_CLIENTLIB_PATH:$LD_LIBRARY_PATH
        export LD_LIBRARY_PATH
        ;;
        * )
        $_ECHO "Warning : Do not know how to handle this OS type $OS_TYPE."
        ;;
esac
fi

#--- Platform Computing Symphony 3.1 environment.
##################################################
if [ "$SYM31_CLIENTLIB_PATH" != "" ] ; then
case $OS_TYPE in
        SunOS )
        if [ "$MX_BITNESS" != "64" ]; then
           LD_LIBRARY_PATH=$SYM31_CLIENTLIB_PATH:$LD_LIBRARY_PATH
           export LD_LIBRARY_PATH
        fi
        ;;
        AIX )
        LIBPATH=$SYM31_CLIENTLIB_PATH:$LIBPATH
        export LIBPATH
        ;;
        HP-UX )
        SHLIB_PATH=$SYM31_CLIENTLIB_PATH:$SHLIB_PATH
        export SHLIB_PATH
        ;;
        Linux )
        LD_LIBRARY_PATH=$SYM31_CLIENTLIB_PATH:$LD_LIBRARY_PATH
        export LD_LIBRARY_PATH
        ;;
        * )
        $_ECHO "Warning : Do not know how to handle this OS type $OS_TYPE."
        ;;
esac
fi


#--- File descriptors configuration.
################################################
ulimit -n $FD_LIMIT

FILE_DESC=`ulimit -n`

if [ $FILE_DESC -lt $FD_LIMIT ]; then
   $_ECHO "    Mx 3.1: Fatal ERROR: "
   $_ECHO "          Can not set file descriptors to $FD_LIMIT for current shell."
   exit 1
fi
} # End of Setting_Env

# End of configuration, nothing to modify below.

#--- Copying latest mxjboot.jar if needed, using the fileserver.
################################################################

Copy_mxjboot() {

JAVA_CMD="java -Xms8M -Xmx8M $JVM_OPTION -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_BOOT_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.rmi.loader.start.FileServerAutomaticDownload"

if [ ! -f `dirname $0`/jar/$MXJ_BOOT_JAR ] ; then
    # $_ECHO $JAVA_CMD 
    $JAVA_CMD > /dev/null 2>&1
fi

if [ -f `dirname $0`/jar/$MXJ_BOOT_JAR ] ; then
   diff ./$MXJ_BOOT_JAR jar/$MXJ_BOOT_JAR >/dev/null
   if [ $? -ne 0 ] ; then
      cp jar/$MXJ_BOOT_JAR .
   fi
fi

}

######################################################################
#     Mx Synchronous Startup 
######################################################################
SynchronousStartup() {

COMPONENT="$2"
if [ "$COMPONENT" = "-l" ]; then
   CFG_FILE=/MXJ_CONFIG_FILE:$MXJ_CONFIG_FILE;
fi

$_ECHO "Synchronous Startup $COMPONENT $CFG_FILE $EXTRA_ARGS"

JAVA_CMD="java -Xms32M -Xmx64M -cp fs/murex/code/kernel/jar/common.jar murex.middleware.system.SynchronousStartup $COMPONENT $CFG_FILE $EXTRA_ARGS"

exec $JAVA_CMD

exit 0
}

######################################################################
#     Mx 3.1 File server
######################################################################
Fileserver() {

Define_Log_File_Name fileserver
Init_Log_File

if [ "$FILESERVER_ARGS" != "" ];then
   $_ECHO "Using specific args:$FILESERVER_ARGS"
fi

FSXmx="-Xmx48M"

if [ "$OS_TYPE" = "SunOS" ] && [ "$PLATFORM_TYPE" = "sparc" ]; then
   FSXmx="-Xmx64M"
fi

cd $FILESERVER_PATH

JAVA_CMD="java -Xms32M $FSXmx $JVM_OPTION $FILESERVER_ARGS -cp $FILESERVER_CLASSPATH murex.http.fileserver.FileServerJar /MXJ_PORT:$MXJ_FILESERVER_PORT /MXJ_HOST:$MXJ_FILESERVER_HOST /MXJ_JAR_FILE:$MXJ_JAR_FILE /MXJ_CONFIG_FILE:$MXJ_FILESERVER_CONFIG_FILE /MXJ_TLS_PORT:$MXJ_FILESERVER_TLS_PORT /MXJ_TLS_CLIENT_AUTH:$MXJ_FILESERVER_TLS_CLIENT_AUTH $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" ".."
cd ..
Update_Log_Pid_Files $! 0

}

######################################################################
# MXJXmlserver
######################################################################
Xmlserver() {

Define_Log_File_Name xmlserver
Init_Log_File

if [ "$XML_SERVER_ARGS" != "" ];then
   $_ECHO "Using specific args:$XML_SERVER_ARGS"
fi
if [ "$OS_TYPE" = "SunOS" ]; then
   JVM_OPTION=" -server $JVM_OPTION"
fi

if [ "$MXJ_XMLSERVER_LOGGER_FILE" = "" ]; then
   MXJ_XMLSERVER_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_XMLSERVER_LOGGER_FILE"

JAVA_CMD="java -Xms32M -Xmx64M $JVM_OPTION $XML_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.home.XmlHomeStartAll /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_XMLSERVER_LOGGER_FILE /MXJ_HUB_NAME:$MXJ_HUB_NAME.$MXJ_SITE_NAME  $EXTRA_ARGS "

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# HubHome
######################################################################
HubHome() {
#$_ECHO "hub home:/MXJ_HUB_NAME:$MXJ_HUB_NAME.$MXJ_SITE_NAME"
Define_Log_File_Name hubhome
Init_Log_File

if [ "$XML_SERVER_ARGS" != "" ];then
   $_ECHO "Using specific args:$HUB_HOME_ARGS"
fi

if [ "$MXJ_XMLSERVER_LOGGER_FILE" = "" ]; then
   MXJ_XMLSERVER_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_XMLSERVER_LOGGER_FILE"

JAVA_CMD="java -Xms32M -Xmx64M $JVM_OPTION $HUB_HOME_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.hub.HubHome /MXJ_LOGGER_FILE:$MXJ_XMLSERVER_LOGGER_FILE /MXJ_HUB_NAME:$MXJ_HUB_NAME.$MXJ_SITE_NAME $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# MXJXMLserver  XMLSNOHUB
######################################################################
XmlserverNoHub(){

Define_Log_File_Name xmlservernohub
Init_Log_File

if [ "$XML_SERVER_ARGS" != "" ];then
   $_ECHO "Using specific args:$XML_SERVER_ARGS"
fi
if [ "$OS_TYPE" = "SunOS" ]; then
   JVM_OPTION=" -server $JVM_OPTION"
fi

if [ "$MXJ_XMLSERVER_LOGGER_FILE" = "" ]; then
   MXJ_XMLSERVER_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_XMLSERVER_LOGGER_FILE"

JAVA_CMD="java  -Xms32M -Xmx64M $JVM_OPTION $XML_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.home.XmlHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_XMLSERVER_LOGGER_FILE $EXTRA_ARGS "

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# MXJTransactionManager
######################################################################
TransactionManager() {

Define_Log_File_Name transactionmanager
Init_Log_File

if [ "$MXJ_OTHERS_LOGGER_FILE" = "" ]; then
   MXJ_OTHERS_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_OTHERS_LOGGER_FILE"

JAVA_CMD="java -server -Xms32M -Xmx64M $JVM_OPTION $XML_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.xml.server.tm.TransactionManagerHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_OTHERS_LOGGER_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}


######################################################################
# Launcher
######################################################################
Launcher(){

if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

JAVA_CLASSIC=
#ldd mx

Define_Log_File_Name launcher
Init_Log_File

if [ "$LAUNCHER_ARGS" != "" ];then
   $_ECHO "Using specific args:$LAUNCHER_ARGS"
fi

if [ "$MXJ_LAUNCHER_LOGGER_FILE" = "" ]; then
   MXJ_LAUNCHER_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_LAUNCHER_LOGGER_FILE"

JAVA_CMD="java $JAVA_CLASSIC -Xms32M -Xmx64M $LAUNCHER_ARGS $JVM_OPTION -Xbootclasspath/p:jar/xercesImpl-2.9.1.jar:jar/xml-apis-1.3.04.jar:jar/xalan-2.7.1m1.jar:jar/serializer-2.7.1.jar -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_LAUNCHER_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# Mandatory
######################################################################
Mandatory(){

if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: Mandatory Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

JAVA_CLASSIC=
#ldd mx

Define_Log_File_Name mandatory
Init_Log_File

if [ "$MANDATORY_SERVER_ARGS" != "$DEFAULT_MANDATORY_SERVER_ARGS" ];then
   $_ECHO "Using specific MANDATORY_SERVER_ARGS args: $MANDATORY_SERVER_ARGS"
else
   $_ECHO "Using default MANDATORY_SERVER_ARGS args: $MANDATORY_SERVER_ARGS"
fi

if [ "$MANDATORY_JVM_ARGS" != "$DEFAULT_MANDATORY_JVM_ARGS" ];then
   $_ECHO "Using specific MANDATORY_JVM_ARGS args: $MANDATORY_JVM_ARGS"
else
   $_ECHO "Using default MANDATORY_JVM_ARGS args: $MANDATORY_JVM_ARGS"
fi

if [ "$MXJ_MANDATORY_LOGGER_FILE" = "" ]; then
   MXJ_MANDATORY_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_MANDATORY_LOGGER_FILE"

JAVA_CMD="java $MANDATORY_JVM_ARGS $JVM_OPTION $JAVA_CLASSIC $MANDATORY_SERVER_ARGS -Xbootclasspath/p:jar/xercesImpl-2.9.1.jar:jar/xml-apis-1.3.04.jar:jar/xalan-2.7.1m1.jar:jar/serializer-2.7.1.jar -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_MANDATORY_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_MANDATORY_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}


######################################################################
# MxmlexchangeSettings
######################################################################
MxmlexchangeSettings(){

if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: MxMlExchange Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

JAVA_CLASSIC=

if [ "$MXML_SERVER_ARGS" != "$DEFAULT_MXML_SERVER_ARGS" ];then
   $_ECHO "Using specific MXML_SERVER_ARGS args: $MXML_SERVER_ARGS"
else
   $_ECHO "Using default MXML_SERVER_ARGS args: $MXML_SERVER_ARGS"
fi

if [ "$MXJ_MXMLEXCHANGE_LOGGER_FILE" = "" ]; then
   MXJ_MXMLEXCHANGE_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_MXMLEXCHANGE_LOGGER_FILE"

if [ "$MXML_PING_TIME" != "" ];then
   $_ECHO "Using specific MXML_PING_TIME args: $MXML_PING_TIME"
else
   MXML_PING_TIME="$DEFAULT_MXML_PING_TIME"
   $_ECHO "Using default MXML_PING_TIME args: $MXML_PING_TIME"
fi

}

######################################################################
# MxmlexchangePrimary
######################################################################
MxmlexchangePrimary(){

Define_Log_File_Name mxmlexchange
Init_Log_File

if [ "$MXML_JVM_ARGS" != "$DEFAULT_MXML_JVM_ARGS" ];then
   $_ECHO "Using specific MXML_JVM_ARGS args: $MXML_JVM_ARGS"
else
   $_ECHO "Using default MXML_JVM_ARGS args: $MXML_JVM_ARGS"
fi

JAVA_CMD="java $MXML_JVM_ARGS $JVM_OPTION -Xbootclasspath/p:jar/xercesImpl-2.9.1.jar:jar/xml-apis-1.3.04.jar:jar/xalan-2.7.1m1.jar:jar/serializer-2.7.1.jar $JAVA_CLASSIC $MXML_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_MXMLEXCHANGE_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_MXMLEX_CONFIG_FILE $MXML_PING_TIME $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

Define_Log_File_Name mxmlexchangespaces
Init_Log_File

if [ "$MXMLSPACES_JVM_ARGS" != "$DEFAULT_MXMLSPACES_JVM_ARGS" ];then
   $_ECHO "Using specific MXMLSPACES_JVM_ARGS args: $MXMLSPACES_JVM_ARGS"
else
   $_ECHO "Using default MXMLSPACES_JVM_ARGS args: $MXMLSPACES_JVM_ARGS"
fi

JAVA_CMD="java $MXMLSPACES_JVM_ARGS $JVM_OPTION -Xbootclasspath/p:jar/xercesImpl-2.9.1.jar:jar/xml-apis-1.3.04.jar:jar/xalan-2.7.1m1.jar:jar/serializer-2.7.1.jar $JAVA_CLASSIC $MXML_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_MXMLEXCHANGE_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_MXMLEX_CONFIG_FILE_SPACES $MXML_PING_TIME $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# MxmlexchangeSecondary
######################################################################
MxmlexchangeSecondary(){

Define_Log_File_Name mxmlexchangesecondary
Init_Log_File

if [ "$MXMLSECONDARY_JVM_ARGS" != "$DEFAULT_MXMLSECONDARY_JVM_ARGS" ];then
   $_ECHO "Using specific MXMLSECONDARY_JVM_ARGS args: $MXMLSECONDARY_JVM_ARGS"
else
   $_ECHO "Using default MXMLSECONDARY_JVM_ARGS args: $MXMLSECONDARY_JVM_ARGS"
fi

JAVA_CMD="java $MXMLSECONDARY_JVM_ARGS $JVM_OPTION -Xbootclasspath/p:jar/xercesImpl-2.9.1.jar:jar/xml-apis-1.3.04.jar:jar/xalan-2.7.1m1.jar:jar/serializer-2.7.1.jar $JAVA_CLASSIC $MXML_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_MXMLEXCHANGE_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_MXMLEX_CONFIG_FILE_SECONDARY $MXML_PING_TIME $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# MxmlexchangeWorker
######################################################################
MxmlexchangeWorker(){

Define_Log_File_Name mxmlworker
Init_Log_File

if [ "$MXMLWORKER_JVM_ARGS" != "$DEFAULT_MXMLWORKER_JVM_ARGS" ];then
   $_ECHO "Using specific MXMLWORKER_JVM_ARGS args: $MXMLWORKER_JVM_ARGS"
else
   $_ECHO "Using default MXMLWORKER_JVM_ARGS args: $MXMLWORKER_JVM_ARGS"
fi

JAVA_CMD="java $MXMLWORKER_JVM_ARGS $JVM_OPTION -Xbootclasspath/p:jar/xercesImpl-2.9.1.jar:jar/xml-apis-1.3.04.jar:jar/xalan-2.7.1m1.jar:jar/serializer-2.7.1.jar $JAVA_CLASSIC $MXML_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_MXMLEXCHANGE_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_MXMLEX_CONFIG_FILE_WORKER $MXML_PING_TIME $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# AlertEngine
######################################################################
AlertEngine(){

if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: Aagent Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

Define_Log_File_Name alert
Init_Log_File

if [ "$ALERT_JVM_ARGS" != "$DEFAULT_ALERT_JVM_ARGS" ];then
   $_ECHO "Using specific ALERT_JVM_ARGS args: $ALERT_JVM_ARGS"
else
   $_ECHO "Using default ALERT_JVM_ARGS args: $ALERT_JVM_ARGS"
fi

JAVA_CMD="java $ALERT_JVM_ARGS $JVM_OPTION -Xbootclasspath/p:jar/xercesImpl-2.9.1.jar:jar/xml-apis-1.3.04.jar:jar/xalan-2.7.1m.jar:jar/serializer-2.7.1.jar $JAVA_CLASSIC $MXML_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_CONFIG_FILE:$MXJ_MXMLEX_CONFIG_FILE_ALERT $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# StatisticsEngine
######################################################################
StatisticsEngine(){

if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: Aagent Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

Define_Log_File_Name statistics
Init_Log_File

if [ "$STATISTICS_JVM_ARGS" != "$DEFAULT_STATISTICS_JVM_ARGS" ];then
   $_ECHO "Using specific STATISTICS_JVM_ARGS args: $STATISTICS_JVM_ARGS"
else
   $_ECHO "Using default STATISTICS_JVM_ARGS args: $STATISTICS_JVM_ARGS"
fi

JAVA_CMD="java $STATISTICS_JVM_ARGS $JVM_OPTION -Xbootclasspath/p:jar/xercesImpl-2.9.1.jar:jar/xml-apis-1.3.04.jar:jar/xalan-2.7.1m.jar:jar/serializer-2.7.1.jar $JAVA_CLASSIC $MXML_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_CONFIG_FILE:$MXJ_MXMLEX_CONFIG_FILE_STATISTICS $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}
######################################################################
# AmendmentAgent
######################################################################
Aagent(){

if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: Aagent Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

if [ "$AAGENT_SERVER_ARGS" != "$DEFAULT_AAGENT_SERVER_ARGS" ];then
   $_ECHO "Using specific AAGENT_SERVER_ARGS args: $AAGENT_SERVER_ARGS"
else
   $_ECHO "Using default AAGENT_SERVER_ARGS args: $AAGENT_SERVER_ARGS"
fi

if [ "$AAGENT_JVM_ARGS" != "$DEFAULT_AAGENT_JVM_ARGS" ];then
   $_ECHO "Using specific AAGENT_JVM_ARGS args: $AAGENT_JVM_ARGS"
else
   $_ECHO "Using default AAGENT_JVM_ARGS args: $AAGENT_JVM_ARGS"
fi

if [ "$MXJ_AAGENT_LOGGER_FILE" = "" ]; then
   MXJ_AAGENT_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_AAGENT_LOGGER_FILE"

Define_Log_File_Name aagent
Init_Log_File

JAVA_CMD="java $AAGENT_JVM_ARGS $JVM_OPTION -Xbootclasspath/p:jar/xercesImpl-2.9.1.jar:jar/xml-apis-1.3.04.jar:jar/xalan-2.7.1m1.jar:jar/serializer-2.7.1.jar $AAGENT_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_AAGENT_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_AAGENT_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# MxHibernate
######################################################################
Mxhibernate(){
if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: MxHibernate Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

JAVA_CLASSIC=

Define_Log_File_Name mxhibernate
Init_Log_File

if [ "$MXHIBERNATE_SERVER_ARGS" != "$DEFAULT_MXHIBERNATE_SERVER_ARGS" ];then
   $_ECHO "Using specific MXHIBERNATE_SERVER_ARGS args: $MXHIBERNATE_SERVER_ARGS"
else
   $_ECHO "Using default MXHIBERNATE_SERVER_ARGS args: $MXHIBERNATE_SERVER_ARGS"
fi

if [ "$MXHIBERNATE_JVM_ARGS" != "$DEFAULT_MXHIBERNATE_JVM_ARGS" ];then
   $_ECHO "Using specific MXHIBERNATE_JVM_ARGS args: $MXHIBERNATE_JVM_ARGS"
else
   $_ECHO "Using default MXHIBERNATE_JVM_ARGS args: $MXHIBERNATE_JVM_ARGS"
fi

if [ "$MXJ_OTHERS_LOGGER_FILE" = "" ]; then
   MXJ_OTHERS_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_OTHERS_LOGGER_FILE"

JAVA_CMD="java $MXHIBERNATE_JVM_ARGS $JVM_OPTION -Xbootclasspath/p:jar/xercesImpl-2.9.1.jar:jar/xml-apis-1.3.04.jar:jar/xalan-2.7.1m1.jar:jar/serializer-2.7.1.jar $JAVA_CLASSIC $MXHIBERNATE_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_OTHERS_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_MXHIBERNATE_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# PrintSrv
######################################################################
PrintSrv(){
if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: PrintSrv Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

JAVA_CLASSIC=

Define_Log_File_Name printsrv
Init_Log_File

if [ "$PRINTSRV_ARGS" != "$DEFAULT_PRINTSRV_ARGS" ];then
   $_ECHO "Using specific PRINTSRV_ARGS args: $PRINTSRV_ARGS"
else
   $_ECHO "Using default PRINTSRV_ARGS args: $PRINTSRV_ARGS"
fi

if [ "$PRINTSRV_JVM_ARGS" != "$DEFAULT_PRINTSRV_JVM_ARGS" ];then
   $_ECHO "Using specific PRINTSRV_JVM_ARGS args: $PRINTSRV_JVM_ARGS"
else
   $_ECHO "Using default PRINTSRV_JVM_ARGS args: $PRINTSRV_JVM_ARGS"
fi

if [ "$MXJ_OTHERS_LOGGER_FILE" = "" ]; then
   MXJ_OTHERS_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_OTHERS_LOGGER_FILE"

JAVA_CMD="java $PRINTSRV_JVM_ARGS $JVM_OPTION $JAVA_CLASSIC $PRINTSRV_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_PRINTSRV_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_OTHERS_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_PRINTSRV_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# MxDataPublisher
######################################################################
MxDataPublisher(){
if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: MxDataPublisher Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

JAVA_CLASSIC=

Define_Log_File_Name mxdatapublisher
Init_Log_File

if [ "$MXDATAPUBLISHER_ARGS" != "$DEFAULT_MXDATAPUBLISHER_ARGS" ];then
   $_ECHO "Using specific MXDATAPUBLISHER_ARGS args: $MXDATAPUBLISHER_ARGS"
else
   $_ECHO "Using default MXDATAPUBLISHER_ARGS args: $MXDATAPUBLISHER_ARGS"
fi

if [ "$MXDATAPUBLISHER_JVM_ARGS" != "$DEFAULT_MXDATAPUBLISHER_JVM_ARGS" ];then
   $_ECHO "Using specific MXDATAPUBLISHER_JVM_ARGS args: $MXDATAPUBLISHER_JVM_ARGS"
else
   $_ECHO "Using default MXDATAPUBLISHER_JVM_ARGS args: $MXDATAPUBLISHER_JVM_ARGS"
fi

if [ "$MXJ_OTHERS_LOGGER_FILE" = "" ]; then
   MXJ_OTHERS_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_OTHERS_LOGGER_FILE"

JAVA_CMD="java $MXDATAPUBLISHER_JVM_ARGS $JVM_OPTION $JAVA_CLASSIC $MXDATAPUBLISHER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_OTHERS_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_MXDATAPUBLISHER_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# Warehouse
######################################################################
Warehouse(){
if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: Warehouse Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

JAVA_CLASSIC=

Define_Log_File_Name warehouse
Init_Log_File

if [ "$WAREHOUSE_SERVER_ARGS" != "$DEFAULT_WAREHOUSE_SERVER_ARGS" ];then
   $_ECHO "Using specific WAREHOUSE_SERVER_ARGS args: $WAREHOUSE_SERVER_ARGS"
else
   $_ECHO "Using default WAREHOUSE_SERVER_ARGS args: $WAREHOUSE_SERVER_ARGS"
fi

if [ "$WAREHOUSE_JVM_ARGS" != "$DEFAULT_WAREHOUSE_JVM_ARGS" ];then
   $_ECHO "Using specific WAREHOUSE_JVM_ARGS args: $WAREHOUSE_JVM_ARGS"
else
   $_ECHO "Using default WAREHOUSE_JVM_ARGS args: $WAREHOUSE_JVM_ARGS"
fi

if [ "$MXJ_WAREHOUSE_LOGGER_FILE" = "" ]; then
   MXJ_WAREHOUSE_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_WAREHOUSE_LOGGER_FILE"

JAVA_CMD="java $WAREHOUSE_JVM_ARGS $JVM_OPTION $JAVA_CLASSIC $WAREHOUSE_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_WAREHOUSE_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_WAREHOUSE_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}


######################################################################
# MLC
######################################################################
MXMLC(){

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

if [ "$MXMLC_SERVER_ARGS" != "$DEFAULT_MXMLC_SERVER_ARGS" ];then
   $_ECHO "Using specific MXMLC_SERVER_ARGS args: $MXMLC_SERVER_ARGS"
else
   $_ECHO "Using default MXMLC_SERVER_ARGS args: $MXMLC_SERVER_ARGS"
fi

if [ "$MXMLC_JVM_ARGS" != "$DEFAULT_MXMLC_JVM_ARGS" ];then
   $_ECHO "Using specific MXMLC_JVM_ARGS args: $MXMLC_JVM_ARGS"
else
   $_ECHO "Using default MXMLC_JVM_ARGS args: $MXMLC_JVM_ARGS"
fi

JAVA_CLASSIC=

Define_Log_File_Name mxmlc
Init_Log_File

if [ "$MXJ_OTHERS_LOGGER_FILE" = "" ]; then
   MXJ_OTHERS_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_OTHERS_LOGGER_FILE"


#####################
#MLC POLICY FILE    #
#####################
MLC_POLICY_FILE="http://${MXJ_FILESERVER_HOST}:${MXJ_FILESERVER_PORT}/murex/mxres/mxmlc/mlc.policy"

MLC_POLICY_PROPERTY=-Djava.security.policy=${MLC_POLICY_FILE}

JAVA_CMD="java $MXMLC_JVM_ARGS $JVM_OPTION -Xbootclasspath/p:jar/xercesImpl-2.9.1.jar:jar/xml-apis-1.3.04.jar:jar/xalan-2.7.1m1.jar:jar/serializer-2.7.1.jar $MLC_POLICY_PROPERTY $JAVA_CLASSIC $MXMLC_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_MLC_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_MXMLC_CONFIG_FILE /MXJ_ANT_BUILD_FILE:$MXJ_MXMLC_ANT_BUILD_FILE /MXJ_ANT_TARGET:$MXJ_MXMLC_ANT_TARGET $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# LRB another part of the MLC
######################################################################
MXLRB(){

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "Mx G2000: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi


if [ "$LRB_SERVER_ARGS" != "$DEFAULT_LRB_SERVER_ARGS" ];then
   $_ECHO "Using specific LRB_SERVER_ARGS args: $LRB_SERVER_ARGS"
else
   $_ECHO "Using default LRB_SERVER_ARGS args: $LRB_SERVER_ARGS"
fi

if [ "$LRB_JVM_ARGS" != "$DEFAULT_LRB_JVM_ARGS" ];then
   $_ECHO "Using specific LRB_JVM_ARGS args: $LRB_JVM_ARGS"
else
   $_ECHO "Using default LRB_JVM_ARGS args: $LRB_JVM_ARGS"
fi

   JAVA_CLASSIC=

Define_Log_File_Name lrb
Init_Log_File


#####################
#MLC POLICY FILE    #
#####################
MLC_POLICY_FILE="http://${MXJ_FILESERVER_HOST}:${MXJ_FILESERVER_PORT}/murex/mxres/mxmlc/mlc.policy"

MLC_POLICY_PROPERTY=-Djava.security.policy=${MLC_POLICY_FILE}

JAVA_CMD="java $LRB_JVM_ARGS $JVM_OPTION -Xbootclasspath/p:jar/xercesImpl-2.9.1.jar:jar/xml-apis-1.3.04.jar:jar/xalan-2.7.1m1.jar:jar/serializer-2.7.1.jar $JAVA_CLASSIC $LRB_SERVER_ARGS -cp $MXJ_BOOT_JAR $MLC_POLICY_PROPERTY -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_MLC_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_MXLRB_CONFIG_FILE /MXJ_ANT_BUILD_FILE:$MXJ_MXMLC_ANT_BUILD_FILE /MXJ_ANT_TARGET:$MXJ_LRB_ANT_TARGET $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# MxRepository
######################################################################
MxRepository(){

if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: MxRepository Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

JAVA_CLASSIC=

Define_Log_File_Name mxrepository
Init_Log_File

if [ "$MXREPOSITORY_SERVER_ARGS" != "" ];then
   $_ECHO "Using specific args:$MXREPOSITORY_SERVER_ARGS"
fi

if [ "$MXJ_OTHERS_LOGGER_FILE" = "" ]; then
   MXJ_OTHERS_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_OTHERS_LOGGER_FILE"

JAVA_CMD="java -Xms32M -Xmx64m $JVM_OPTION $JAVA_CLASSIC $MXREPOSITORY_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_OTHERS_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_MXREPOSITORY_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# MDCS
######################################################################
MDCS_CACHE(){

if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: MDCS Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

JAVA_CLASSIC=

Define_Log_File_Name mdcs
Init_Log_File

if [ "$MDCS_SERVER_ARGS" != "$DEFAULT_MDCS_SERVER_ARGS" ];then
   $_ECHO "Using specific MDCS_SERVER_ARGS args: $MDCS_SERVER_ARGS"
else
   $_ECHO "Using default MDCS_SERVER_ARGS args: $MDCS_SERVER_ARGS"

fi
if [ "$MDCS_JVM_ARGS" != "$DEFAULT_MDCS_JVM_ARGS" ];then
   $_ECHO "Using specific MDCS_JVM_ARGS args: $MDCS_JVM_ARGS"
else
   $_ECHO "Using default MDCS_JVM_ARGS args: $MDCS_JVM_ARGS"
fi

if [ "$MXJ_MDCS_LOGGER_FILE" = "" ]; then
   MXJ_MDCS_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_MDCS_LOGGER_FILE"

JAVA_CMD="java $MDCS_JVM_ARGS $JVM_OPTION $JAVA_CLASSIC $MDCS_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_MDCS_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_MDCS_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# MDRS
######################################################################
MDRS_ENGINE(){

if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: MDRS Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

JAVA_CLASSIC=

Define_Log_File_Name mdrs
Init_Log_File

if [ "$MDRS_SERVER_ARGS" != "$DEFAULT_MDRS_SERVER_ARGS" ];then
   $_ECHO "Using specific MDRS_SERVER_ARGS args: $MDRS_SERVER_ARGS"
else
   $_ECHO "Using default MDRS_SERVER_ARGS args: $MDRS_SERVER_ARGS"

fi
if [ "$MDRS_JVM_ARGS" != "$DEFAULT_MDRS_JVM_ARGS" ];then
   $_ECHO "Using specific MDRS_JVM_ARGS args: $MDRS_JVM_ARGS"
else
   $_ECHO "Using default MDRS_JVM_ARGS args: $MDRS_JVM_ARGS"
fi

if [ "$MXJ_MDRS_LOGGER_FILE" = "" ]; then
   MXJ_MDRS_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_MDRS_LOGGER_FILE"

JAVA_CMD="java $MDRS_JVM_ARGS $JVM_OPTION $JAVA_CLASSIC $MDRS_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_MDRS_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_MDRS_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# Interface launcher
######################################################################
InterfaceLauncher(){

if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

if [ "$MXJ_CONFIG_FILE" = "public.mxres.common.launcherall.mxres" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: please specify a configuration file of an interface"
   exit 1
fi

# The file contains the complete path to the .jar, and .so files that are required by the interfaces service
MXJ_INTERFACES_SRV_JAR_FILE="murex.download.interfaces_srv.download"
if [ "$OS_TYPE" = "SunOS" ]; then
MXJ_INTERFACES_SRV_JAR_FILE="murex.download.interfaces_srv_sol.download"
elif [ "$OS_TYPE" = "Linux" ]; then
MXJ_INTERFACES_SRV_JAR_FILE="murex.download.interfaces_srv_linux.download"
fi

JAVA_CLASSIC=
#ldd mx

#use same log filename rules as normal launcher
Define_Log_File_Name launcher
Init_Log_File

if [ "$LAUNCHER_ARGS" != "" ];then
   $_ECHO "Using specific args:$LAUNCHER_ARGS"
fi

if [ "$MXJ_LAUNCHER_LOGGER_FILE" = "" ]; then
   MXJ_LAUNCHER_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_LAUNCHER_LOGGER_FILE"

JAVA_CMD="java $INTERFACES_SRV_JVM_ARGS $COMMON_INTERFACES_JVM_ARGS $JAVA_CLASSIC $JVM_OPTION $LAUNCHER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_INTERFACES_SRV_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_LAUNCHER_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# RealTimeBridgingService
######################################################################
RealTimeBridgingService(){

if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: RTBS Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

Define_Log_File_Name rtbs
Init_Log_File

if [ "$MXJ_RTBS_LOGGER_FILE" = "" ]; then
   MXJ_RTBS_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_RTBS_LOGGER_FILE"
$_ECHO "Using default RTBS_JVM_ARGS args: $RTBS_JVM_ARGS"


JAVA_CMD="java $RTBS_JVM_ARGS $JVM_OPTION $RTBS_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_RTBS_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_RTBS_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# FederationService
######################################################################
FederationService(){

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

# FEDERATION_MXRES_NAME is used as a propertie within rtms_looger.xml
FEDERATION_MXRES_NAME=`echo $MXJ_FEDERATION_CONFIG_FILE | cut -d"." -f4`
FEDERATION_JVM_ARGS="$FEDERATION_JVM_ARGS -DFEDERATION_MXRES_NAME=$FEDERATION_MXRES_NAME"

Define_Log_File_Name federation
Init_Log_File

if [ "$MXJ_FEDERATION_LOGGER_FILE" = "" ]; then
   MXJ_FEDERATION_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_FEDERATION_LOGGER_FILE"

JAVA_CMD="java $FEDERATION_JVM_ARGS $JVM_OPTION $FEDERATION_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_FEDERATION_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_FEDERATION_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# EntitlementService
######################################################################
EntitlementService(){

if [ "$MXJ_LOGGER_FILE" = "" ] ; then
   MXJ_LOGGER_FILE="public.mxres.loggers.mxentitlement_logger.mxres"
fi

LD_LIBRARY_PATH=./bin:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH

Define_Log_File_Name entitlement
Init_Log_File

$_ECHO "Using logger:$MXJ_LOGGER_FILE"

JAVA_CMD="java $ENTITLEMENT_JVM_ARGS $JVM_OPTION $ENTITLEMENT_SERVER_ARGS -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_ENTITLEMENT_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_ENTITLEMENT_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}


######################################################################
# KillFeeder
######################################################################
KillFeeder() {
 $_ECHO "Target: $EXTRA_ARGS"
java $JVM_OPTION -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.ant.ScriptAnt /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_ANT_BUILD_FILE:public.mxres.mxcontribution.killfeedertask.mxres /MXJ_ANT_TARGET:$MXJ_FEEDER_VALUE
exit $?

}

######################################################################
# Olk
######################################################################
Olk(){

if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: Olk Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

OLK_EXEC_FILE=olk_exec.sh

if [ ! -f `dirname $0`/$OLK_EXEC_FILE ] ; then
   $_ECHO "    Mx 3.1: Fatal ERROR: "
   $_ECHO "          Executable olk command file: $OLK_EXEC_FILE not found !"
   exit 1
fi
if [ ! -x `dirname $0`/$OLK_EXEC_FILE ] ; then
   $_ECHO "    Mx 3.1: Fatal ERROR: "
   $_ECHO "          Olk command file: $OLK_EXEC_FILE not executable, change rights !"
   exit 1
fi

Define_Log_File_Name olk
Init_Log_File
. `dirname $0`/$OLK_EXEC_FILE $EXTRA_ARGS \
2>&1 | $_TEE -a $LOG_PATH/$LOG_FILE.log &
Update_Log_Pid_Files $! 1

}

######################################################################
# Volume Import Tool (VIT) Launcher
######################################################################
VitLauncher(){

if [ "$MXJ_JAR_FILE" = "" ] ; then
   MXJ_JAR_FILE="murex.download.vit.download"
fi

if [ "$MXJ_LOGGER_FILE" = "" ] ; then
   MXJ_LOGGER_FILE="public.mxres.loggers.mxvit_logger.mxres"
fi

Define_Log_File_Name vit
Init_Log_File

$_ECHO "Using logger:$MXJ_LOGGER_FILE"

JAVA_CMD="java -Xms64M -Xmx512M $JVM_OPTION -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# Pgop sequencer Launcher
######################################################################
PgopLauncher(){

if [ "$MXJ_JAR_FILE" = "" ] ; then
   MXJ_JAR_FILE="murex.download.pgop-service.download"
fi

if [ "$MXJ_LOGGER_FILE" = "" ] ; then
   MXJ_LOGGER_FILE="public.mxres.loggers.pgop_logger.mxres"
fi

Define_Log_File_Name pgop
Init_Log_File

$_ECHO "Using logger:$MXJ_LOGGER_FILE"

JAVA_CMD="java -Xms32M -Xmx64M $JVM_OPTION -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}	
	
######################################################################
# Pgop Task Manager Launcher
######################################################################
PgopLauncherTaskManager(){

if [ "$MXJ_JAR_FILE" = "" ] ; then
   MXJ_JAR_FILE="murex.download.pgop-tm-service.download"
fi

if [ "$MXJ_LOGGER_FILE" = "" ] ; then
   MXJ_LOGGER_FILE="public.mxres.loggers.pgop-tm_logger.mxres"
fi

Define_Log_File_Name pgop-tm
Init_Log_File

$_ECHO "Using logger:$MXJ_LOGGER_FILE"

JAVA_CMD="java -Xms32M -Xmx64M $JVM_OPTION -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}	

######################################################################
# PFE evaluator launcher (pfe)
######################################################################
# this only starts the launcher of the service. variables defined
# here may be overriden using the orchestration mechanics.
PfeLauncher(){

# may be overriden by orchestration configuration
if [ "$MXJ_JAR_FILE" = "" ] ; then
   MXJ_JAR_FILE="murex.download.pfe-engine.download"
fi

# may be overriden by orchestration configuration
if [ "$MXJ_LOGGER_FILE" = "" ] ; then
   MXJ_LOGGER_FILE="public.mxres.loggers.pfe_logger.mxres"
fi

Define_Log_File_Name pfe
Init_Log_File

$_ECHO "Using logger:$MXJ_LOGGER_FILE. This configuration may have been overriden in orchestration."

JAVA_CMD="java -Xms64M -Xmx512M $JVM_OPTION -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}	
######################################################################
# PFE evaluator launcher (pfe-tm)
######################################################################
# this only starts the launcher of the service. variables defined
# here may be overriden using the orchestration mechanics.
PfeEvaluatorLauncher(){

# for use of an external set of MACS libraries (dynamic libs)
if [ "$PFE_MACS_LIB_PATH" != "" ]
then
   LD_LIBRARY_PATH="$PFE_MACS_LIB_PATH:$LD_LIBRARY_PATH"
   export LD_LIBRARY_PATH
fi

# for use of an external set of MACS libraries (python script root)
if [ "$PFE_MACS_PYPATH" != "" ]
then
   MACS_PYPATH="$PFE_MACS_PYPATH"
   export MACS_PYPATH
fi

# may be overriden by orchestration configuration
if [ "$MXJ_JAR_FILE" = "" ] ; then
   MXJ_JAR_FILE="murex.download.pfe-engine.download"
fi

# may be overriden by orchestration configuration
if [ "$MXJ_LOGGER_FILE" = "" ] ; then
   MXJ_LOGGER_FILE="public.mxres.loggers.pfe_logger.mxres"
fi

Define_Log_File_Name pfe-tm
Init_Log_File

$_ECHO "Using logger:$MXJ_LOGGER_FILE. This configuration may have been overriden in orchestration."

JAVA_CMD="java -Xms64M -Xmx512M $JVM_OPTION -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}	
	
######################################################################
# RtImport
######################################################################
RtImport(){
#Params : session or start or stop or rtifxg
MXJ_RTIMPORT_CONFIG_PATH=public.mxres.mxcontribution.

case "$1" in
'session')

#Used to set the display value
$_ECHO $RTISESSION_XWIN_DISP >./RTISESSION_XWIN_DISP.tmp
        java -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.monitor.script.Monitor /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_PASSWORD:$MXJ_PASSWORD \
/MXJ_CONFIG_FILE:"$MXJ_RTIMPORT_CONFIG_PATH"rtimportsession.mxres $EXTRA_ARGS

        ;;
'start')
        java -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.monitor.script.Monitor /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_PASSWORD:$MXJ_PASSWORD \
/MXJ_CONFIG_FILE:"$MXJ_RTIMPORT_CONFIG_PATH"rtimportstart.mxres $EXTRA_ARGS

        ;;
'stop')
        java -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.monitor.script.Monitor /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_PASSWORD:$MXJ_PASSWORD \
/MXJ_CONFIG_FILE:"$MXJ_RTIMPORT_CONFIG_PATH"rtimportstop.mxres $EXTRA_ARGS

        ;;
'rticachesession')
#set -x
#Used to set the display value
$_ECHO $RTICACHESESSION_XWIN_DISP >./RTICACHESESSION_XWIN_DISP.tmp
#        java -cp $MXJ_BOOT_JAR \
#-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
#/MXJ_CLASS_NAME:murex.apps.middleware.client.monitor.script.Monitor /MXJ_SITE_NAME:$MXJ_SITE_NAME \
#/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_PASSWORD:$MXJ_PASSWORD \
#/MXJ_CONFIG_FILE:"$MXJ_RTIMPORT_CONFIG_PATH"rtimportcachesession.mxres $EXTRA_ARGS
        java $JVM_OPTION -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.ant.ScriptAnt /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_ANT_BUILD_FILE:public.mxres.mxcontribution.rtiantcachesession.mxres /MXJ_ANT_TARGET:rti $EXTRA_ARGS
exit $?

 ;;

'rticachestart')
        java -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.monitor.script.Monitor /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_PASSWORD:$MXJ_PASSWORD \
/MXJ_CONFIG_FILE:"$MXJ_RTIMPORT_CONFIG_PATH"rtimportcachestart.mxres $EXTRA_ARGS

        ;;
'rticachestop')
        java -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.monitor.script.Monitor /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_PASSWORD:$MXJ_PASSWORD \
/MXJ_CONFIG_FILE:"$MXJ_RTIMPORT_CONFIG_PATH"rtimportcachestop.mxres $EXTRA_ARGS

        ;;

'fxgsession')
$_ECHO $RTICACHESESSION_XWIN_DISP >./RTICACHESESSION_XWIN_DISP.tmp
#        java -cp $MXJ_BOOT_JAR \
#-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
#/MXJ_CLASS_NAME:murex.apps.middleware.client.monitor.script.Monitor /MXJ_SITE_NAME:$MXJ_SITE_NAME \
#/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_PASSWORD:$MXJ_PASSWORD \
#/MXJ_CONFIG_FILE:"$MXJ_RTIMPORT_CONFIG_PATH"rtimportfixingsession.mxres $EXTRA_ARGS
         java $JVM_OPTION -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.ant.ScriptAnt /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_ANT_BUILD_FILE:public.mxres.mxcontribution.rtifxgantcachesession.mxres /MXJ_ANT_TARGET:rtifxg $EXTRA_ARGS
exit $?
        ;;
'fxgstart')
        java -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.monitor.script.Monitor /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_PASSWORD:$MXJ_PASSWORD \
/MXJ_CONFIG_FILE:"$MXJ_RTIMPORT_CONFIG_PATH"rtimportfixingstart.mxres $EXTRA_ARGS

        ;;
'fxgstop')
        java -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.monitor.script.Monitor /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_PASSWORD:$MXJ_PASSWORD \
/MXJ_CONFIG_FILE:"$MXJ_RTIMPORT_CONFIG_PATH"rtimportfixingstop.mxres $EXTRA_ARGS

        ;;
esac

}

######################################################################
# MxParam
######################################################################
MxParam(){
#Params : start or stop
MXJ_MXPARAM_CONFIG_PATH=public.mxres.mxcontribution.
if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: Mxparam Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

case "$1" in
'start')
        java -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.monitor.script.Monitor /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_PASSWORD:$MXJ_PASSWORD \
/MXJ_CONFIG_FILE:"$MXJ_MXPARAM_CONFIG_PATH"mxparamstop.mxres $EXTRA_ARGS

        sleep 15

        java -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.monitor.script.Monitor /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_PASSWORD:$MXJ_PASSWORD \
/MXJ_CONFIG_FILE:"$MXJ_MXPARAM_CONFIG_PATH"mxpmanagementstop.mxres $EXTRA_ARGS

        java -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.monitor.script.Monitor /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_PASSWORD:$MXJ_PASSWORD \
/MXJ_CONFIG_FILE:"$MXJ_MXPARAM_CONFIG_PATH"mxpmanagementstart.mxres $EXTRA_ARGS


        java -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.home.script.XmlRequestScript /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_PLATFORM_NAME:$MXJ_PLATFORM_NAME /MXJ_PROCESS_NICK_NAME:$MXJ_PROCESS_NICK_NAME /MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE \
/MXJ_CONFIG_FILE:"$MXJ_MXPARAM_CONFIG_PATH"mxparamstart.mxres $EXTRA_ARGS &

        ;;
'stop')
        java -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.monitor.script.Monitor /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_PASSWORD:$MXJ_PASSWORD \
/MXJ_CONFIG_FILE:"$MXJ_MXPARAM_CONFIG_PATH"mxparamstop.mxres $EXTRA_ARGS

        sleep 15

        java -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.monitor.script.Monitor /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_PASSWORD:$MXJ_PASSWORD \
/MXJ_CONFIG_FILE:"$MXJ_MXPARAM_CONFIG_PATH"mxpmanagementstop.mxres $EXTRA_ARGS

        ;;
esac

}

######################################################################
# Murexnet
######################################################################
Murexnet() {

Define_Log_File_Name murexnet
Init_Log_File

if [ "$MUREXNET_ARGS" != "" ];then
   $_ECHO "Using specific args:$MUREXNET_ARGS"
fi

MXNET_CMD="./murexnet /ipaddr:$MUREXNET_PORT /stdout:stdout /stderr:stderr $MUREXNET_ARGS $EXTRA_ARGS"

Java_Launch "$MXNET_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# MxContribution
######################################################################
MxContribution(){

if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: MxContribution Launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

JAVA_CLASSIC=

Define_Log_File_Name mxcontrib
Init_Log_File

if [ "$MXJ_OTHERS_LOGGER_FILE" = "" ]; then
   MXJ_OTHERS_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_OTHERS_LOGGER_FILE"

JAVA_CMD="java -Xms32M -Xmx64M $JVM_OPTION $JAVA_CLASSIC -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_OTHERS_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_CONTRIBUTION_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# MxActivityFeeder
######################################################################
MxActivityFeeder(){

if [ "$SYBASE" = "" ] && [ "$ORACLE_HOME" = "" ] ; then
   $_ECHO "    Mx 3.1: MxActivityFeeder launcher Fatal ERROR: please specify the SYBASE or ORACLE environment variable"
   $_ECHO "          in the $SETTINGS_FILE script file"
   exit 1
fi

if [ ! -f "$JAVA_LIBRARY_PATH/libjvm.$LIB_EXT" ] ; then
   $_ECHO "    Mx 3.1: Launcher Fatal ERROR: "
   $_ECHO "          $JAVA_LIBRARY_PATH/libjvm.$LIB_EXT not found "
   $_ECHO "          file libjvm.$LIB_EXT not found, please check your $SETTINGS_FILE file !"
   exit 1
fi

JAVA_CLASSIC=
#ldd mx

Define_Log_File_Name feeder
Init_Log_File

if [ "$MXJ_ACTIVITY_FEEDER_LOGGER_FILE" = "" ]; then
   MXJ_ACTIVITY_FEEDER_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_ACTIVITY_FEEDER_LOGGER_FILE"

JAVA_CMD="java $JAVA_CLASSIC -Xms32M -Xmx64M $JVM_OPTION -cp $MXJ_BOOT_JAR -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader /MXJ_CLASS_NAME:murex.apps.middleware.server.launcher.LauncherHome /MXJ_SITE_NAME:$MXJ_SITE_NAME /MXJ_LOGGER_FILE:$MXJ_ACTIVITY_FEEDER_LOGGER_FILE /MXJ_CONFIG_FILE:$MXJ_ACTIVITY_FEEDER_CONFIG_FILE $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
Update_Log_Pid_Files $! 0

}

######################################################################
# Client
######################################################################
Client() {
if [ "$MXJ_CLIENT_LOGGER_FILE" = "" ]; then
   MXJ_CLIENT_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_CLIENT_LOGGER_FILE"

MXJ_BOOT_JAR=$MXJ_BOOT_JAR
java $JVM_OPTION -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.gui.xml.XmlGuiClientBoot /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_PLATFORM_NAME:$MXJ_PLATFORM_NAME /MXJ_PROCESS_NICK_NAME:$MXJ_PROCESS_NICK_NAME \
/MXJ_LOGGER_FILE:$MXJ_CLIENT_LOGGER_FILE $EXTRA_ARGS
exit $?

}

######################################################################
# Client with macro
######################################################################
ClientMacro() {

if [ "$MXJ_CLIENT_LOGGER_FILE" = "" ]; then
   MXJ_CLIENT_LOGGER_FILE=$MXJ_LOGGER_FILE
fi
$_ECHO "Using logger:$MXJ_CLIENT_LOGGER_FILE"

MXJ_BOOT_JAR=$MXJ_BOOT_JAR
java $JVM_OPTION -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE -Djava.awt.headless=true murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.gui.api.ScriptReader /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_PLATFORM_NAME:$MXJ_PLATFORM_NAME /MXJ_PROCESS_NICK_NAME:$MXJ_PROCESS_NICK_NAME \
/MXJ_SCRIPT_READ_FROM:$MXJ_SCRIPT /MXJ_LOGGER_FILE:$MXJ_CLIENT_LOGGER_FILE $EXTRA_ARGS
exit $?

}

######################################################################
# Monitor
######################################################################
Monitor() {

java $JVM_OPTION -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_MONITOR_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.gui.monitor.Monitor /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_PASSWORD:$MXJ_PASSWORD  $EXTRA_ARGS
exit $?

}

######################################################################
# Script Monitor
######################################################################
Script_Monitor() {

java $JVM_OPTION -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.monitor.script.Monitor /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE /MXJ_PASSWORD:$MXJ_PASSWORD /MXJ_CONFIG_FILE:$MXJ_CONFIG_FILE $EXTRA_ARGS
exit $?

}

######################################################################
# Script Ant
######################################################################
Script_Ant() {

java $JVM_OPTION -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_MONITOR_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.ant.ScriptAnt /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_LOGGER_FILE:public.mxres.loggers.anttasks_logger.mxres /MXJ_ANT_BUILD_FILE:$MXJ_ANT_BUILD_FILE /MXJ_ANT_TARGET:$MXJ_ANT_TARGET $EXTRA_ARGS
exit $?

}

######################################################################
# Remote Diagnostic Tool
######################################################################
MxRdt() {
  OutputDir=$LOG_PATH/mxrdt
  export OutputDir
  MxRDT_LogFile=${OutputDir}/MxRDT_log.html

  if [ ! -d "$OutputDir" ]; then
    mkdir "$OutputDir"
    Result=$?
    if [ "$Result" != "0" ]; then
      echo "Error creating output directory. Exit."
      exit $Result
    fi
  else
    touch $MxRDT_LogFile
    Result=$?
    if [ "$Result" != "0" ]; then
      echo "Could not write in output directory. Exit. "
      exit $Result
    fi
  fi

  MXRDT_OPERATING_ENV_SETTINGS_FILE=docs.MxRDBMSSettingsAndConfiguration.xml
  
  echo Running MxRDT. Please wait...
  echo
  java -cp jar/mxrdt.jar:fs/murex/code/kernel/jar/mxrdt.jar:fs/murex/code/kernel/jar/mxjclient.jar:fs/murex/code/kernel/jar/middleware-client.jar:fs/murex/code/kernel/jar/fileserver-client.jar:fs/murex/code/kernel/jar/common-client.jar:fs/murex/code/repository/commons-logging/commons-logging/1.0.4/commons-logging-1.0.4.jar:fs/murex/code/repository/com/oracle/ojdbc6/11.2.0.1.0/ojdbc6-11.2.0.1.0.jar:fs/murex/code/repository/sybase/jconn2/5.5/jconn2-5.5.jar:fs/murex/code/repository/log4j/log4j/1.2.13/log4j-1.2.13.jar  \
      -Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE \
      murex.apps.shared.rdt.MxRDT \
     /MXRDT_OUTPUT_FILENAME:${MXRDT_OUTPUT_FILENAME} /MXRDT_OPERATING_ENV_SETTINGS_FILE:${MXRDT_OPERATING_ENV_SETTINGS_FILE} $1 $2 $3
  Result=$?
  echo Done.
  echo
  exit $Result
}

######################################################################
# XmlRequestScript
######################################################################
XmlRequestScript() {

java $JVM_OPTION -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.apps.middleware.client.home.script.XmlRequestScript /MXJ_SITE_NAME:$MXJ_SITE_NAME \
/MXJ_PLATFORM_NAME:$MXJ_PLATFORM_NAME /MXJ_PROCESS_NICK_NAME:$MXJ_PROCESS_NICK_NAME /MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE \
/MXJ_CONFIG_FILE:$MXJ_CONFIG_FILE $EXTRA_ARGS
exit $?
}
######################################################################
# PasswordEncryption
######################################################################
PasswordEncryption() {

java $JVM_OPTION -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/$MXJ_JAR_FILE murex.rmi.loader.RmiLoader \
/MXJ_CLASS_NAME:murex.shared.cryptography.GuiPassword  $EXTRA_ARGS
exit $?
}

######################################################################
# XATransactionLogger
######################################################################
XATransactionLogger() {

Define_Log_File_Name xatransactionlogger
Init_Log_File

MXJ_BOOT_JAR=jar/middleware-client.jar:jar/common-client.jar:jar/fileserver-client.jar:jar/jconn2-5.5.jar:jar/commons-logging-1.0.4.jar:jar/log4j-1.2.13.jar

JAVA_CMD="java -Xms32M -Xmx64M $JVM_OPTION -cp $MXJ_BOOT_JAR \
-Djava.rmi.server.codebase=http://$MXJ_FILESERVER_HOST:$MXJ_FILESERVER_PORT/ murex.apps.shared.jdbc.XATransactionLogger $MXJ_DBSOURCE $XA_CHECK_PERIOD $EXTRA_ARGS"

Java_Launch "$JAVA_CMD" "."
exit $?

}

######################################################################
#
# Beginning of script
#
######################################################################
error(){
        $_ECHO "$0: Error: $*"
}

Java_Launch() {
# Params : Command line of Service
JAVA_CMD=$1
ROOT_DIR=$2

JAVA_CMD=`echo $JAVA_CMD | sed "s/__LOG_FILE__/$LOG_FILE/"`

$_ECHO "Java cmd:\n$JAVA_CMD\n" >> $ROOT_DIR/$LOG_PATH/$LOG_FILE.log
if [ $SILENT = 1 ] ; then
   nohup $JAVA_CMD >> $ROOT_DIR/$LOG_PATH/$LOG_FILE.log 2>&1 &
else
   $JAVA_CMD 2>&1 | $_TEE -a $ROOT_DIR/$LOG_PATH/$LOG_FILE.log &
fi
}

Define_Log_File_Name() {
# Params : ID of Service
ID=$1
LOG_FILE=

case $ID in
        fileserver )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_FILESERVER_PORT
        ;;
        xmlserver )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_HUB_NAME.$MXJ_SITE_NAME
        ;;
        xmlservernohub )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME
        ;;
        hubhome )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_HUB_NAME.$MXJ_SITE_NAME
        ;;
        transactionmanager )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_PORT.$MXJ_SITE_NAME
        ;;
        launcher )
                if [ "$MXJ_INSTALLATION_CODE" = "" ] ; then
                   LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_CONFIG_FILE
                else
                   LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_CONFIG_FILE.$MXJ_INSTALLATION_CODE
                fi
        ;;
        mxmlexchange )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_MXMLEX_CONFIG_FILE
        ;;
        mxmlexchangesecondary )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_MXMLEX_CONFIG_FILE_SECONDARY
        ;;
        mxmlexchangespaces )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_MXMLEX_CONFIG_FILE_SPACES
        ;;
        mxmlworker )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_MXMLEX_CONFIG_FILE_WORKER
        ;;
        alert )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_MXMLEX_CONFIG_FILE_ALERT
        ;;
        statistics )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_MXMLEX_CONFIG_FILE_STATISTICS
        ;;
        aagent )
                if [ "$MXJ_INSTALLATION_CODE" = "" ] ; then
                   LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_AAGENT_CONFIG_FILE
                else
                   LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_AAGENT_CONFIG_FILE.$MXJ_INSTALLATION_CODE
                fi
        ;;
        mxhibernate )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_MXHIBERNATE_CONFIG_FILE
        ;;
        printsrv )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_PRINTSRV_CONFIG_FILE
        ;;
        mxdatapublisher )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_MXDATAPUBLISHER_CONFIG_FILE
        ;;
        warehouse )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_WAREHOUSE_CONFIG_FILE
        ;;
        mxrepository )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_MXREPOSITORY_CONFIG_FILE
        ;;
        mdcs )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_MDCS_CONFIG_FILE
        ;;
        mdrs )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_MDRS_CONFIG_FILE
        ;;
        rtbs )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_RTBS_CONFIG_FILE
        ;;
        federation )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_FEDERATION_CONFIG_FILE
        ;;
        entitlement )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_ENTITLEMENT_CONFIG_FILE
        ;;
        mandatory )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_MANDATORY_CONFIG_FILE
        ;;
        murexnet )
                LOG_FILE=$MACHINE_NAME.$ID.$MUREXNET_PORT
        ;;
        mxmlc )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_MXMLC_CONFIG_FILE
        ;;
        lrb )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_MXLRB_CONFIG_FILE
        ;;
        olk )
                LOG_FILE=$MACHINE_NAME.$ID
        ;;
        mxparam )
                LOG_FILE=$MACHINE_NAME.$ID
        ;;
        rtimport )
                LOG_FILE=$MACHINE_NAME.$ID
        ;;
        mxcontrib )
                LOG_FILE=$MACHINE_NAME.$ID
         ;;
                xatransactionlogger )
                LOG_FILE=$MACHINE_NAME.$ID
         ;;
        feeder )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_ACTIVITY_FEEDER_CONFIG_FILE
         ;;
        vit )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_CONFIG_FILE
         ;;
        pgop )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_CONFIG_FILE
         ;;
        pgop-tm )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_CONFIG_FILE
         ;;
        pfe )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_CONFIG_FILE
         ;;
        pfe-tm )
                LOG_FILE=$MACHINE_NAME.$ID.$MXJ_SITE_NAME.$MXJ_CONFIG_FILE
         ;;
        * )
                $_ECHO "Warning : Do not know how to handle this service."
                $_ECHO "          No way to stop it except manually."
        ;;
esac

}

Init_Log_File() {
#Params : None

if [ ! -d $LOG_PATH ] ; then
   mkdir $LOG_PATH
fi
if [ ! -d $LOG_PATH ] ; then
   $_ECHO "    Mx 3.1: Error : "
   $_ECHO "          Log directory :$LOG_PATH does not exist !"
   $_ECHO "          Please create it."
   exit 1
fi
if [ ! -w $LOG_PATH ] ; then
   $_ECHO "    Mx 3.1: Error : "
   $_ECHO "          Log directory :$LOG_PATH does not have good rights !"
   $_ECHO "          Please add write permission."
   exit 1
fi
if [ -f $LOG_PATH/$LOG_FILE.pid ] ; then
  $_ECHO "The service may already run, please check below."
  Process_Status
#  exit 1
  if [ -f $LOG_PATH/$LOG_FILE.pid ] ; then
        $_ECHO "\nThe service already run."
        exit 1
  else
        $_ECHO "\nCleanup done \nLaunching Process"
  fi
fi

if [ $APPEND_LOG = 1 ] ; then
        $_ECHO "---------------\n" >> $LOG_PATH/$LOG_FILE.log
else
        $_ECHO "---------------\n" > $LOG_PATH/$LOG_FILE.log
fi
$_ECHO "Start time `date` by $USER_NAME\n" >> $LOG_PATH/$LOG_FILE.log
$_ECHO "File descriptors raised to `ulimit -n` for current cmd.\n" >> $LOG_PATH/$LOG_FILE.log
$_ECHO "Java option used : $JVM_OPTION " >>$LOG_PATH/$LOG_FILE.log
if [ $SILENT = 1 ] ; then
   java $JVM_OPTION -version >> $LOG_PATH/$LOG_FILE.log 2>&1
else
java $JVM_OPTION -version 2>&1 | $_TEE -a $LOG_PATH/$LOG_FILE.log
fi
$_ECHO "" >>$LOG_PATH/$LOG_FILE.log
$_ECHO ""
}

Update_Log_Pid_Files() {
#Param 1 : The process ID number  $!
#Param 2 : If the process is a shell exec 1 else 0

sleep 1 #Needed to give time to the process to defunct.

PID_NB=
if [ "$OS_TYPE" = "Linux" ]; then
   _PID_NB=
   PTEE_PID_NB=
   PTEE_PID_NB=`$_PS -eaf | $_AWK ' \$2 == '$!' ' | $_AWK '{ print \$3 }'`
# DSLECOMTE-DEF0023546-REMOTE_SHELL_LINUX
   _PID_NB=`$_PS -eaf | $_AWK ' \$3 == '$PTEE_PID_NB' ' | $_AWK ' \$2 != '$!' '`
# FSLECOMTE-DEF0023546-REMOTE_SHELL_LINUX
   PID_NB=`echo $_PID_NB | $_AWK '{ print \$2 }'`
else
   PID_NB=`$_PS -eaf | $_AWK ' \$3 == '$!' ' | $_AWK '{ print \$2 }'`
fi

if [ $2 = 1 ] ; then
   PID_NB=`$_PS -eaf | $_AWK ' \$3 == '$PID_NB' ' | $_AWK '{ print \$2 }'`
fi
#Overwrite the PID in case of silent mode.
if [ $SILENT = 1 ] ; then
   PID_NB=`$_PS -eaf | $_AWK ' \$2 == '$!' ' | $_AWK '{ print \$2 }'`
fi
if [ "$PID_NB" = "" ] ; then
   $_ECHO "\n"
   $_ECHO "    Mx 3.1: Fatal ERROR: "
   $_ECHO "          The service did not start."
   $_ECHO "          See messages on your screen or on $LOG_PATH/$LOG_FILE.log file."
   $_ECHO "\nAt `date`\n" >> $LOG_PATH/$LOG_FILE.log
   $_ECHO "  Service failed to start (message above)\n" >> $LOG_PATH/$LOG_FILE.log
   $_ECHO "\n---------------\n" >> $LOG_PATH/$LOG_FILE.log
   if [ -f $LOG_PATH/$LOG_FILE.pid ] ; then
      if [ $SILENT = 1 ] ; then
         $_ECHO "WARNING !!\n The service may be already launched.\n" >> $LOG_PATH/$LOG_FILE.log
      else
      $_ECHO "WARNING !!\n The service may be already launched.\n"  | $_TEE -a $LOG_PATH/$LOG_FILE.log
   fi
   fi
else
   if [ $SILENT = 1 ] ; then
      $_ECHO "\n***\nPID:$PID_NB\n***\n" >> $LOG_PATH/$LOG_FILE.log
else
   $_ECHO "\n***\nPID:$PID_NB\n***\n" | $_TEE -a $LOG_PATH/$LOG_FILE.log
   fi
   $_ECHO "Logging stdout and stderr to $LOG_PATH/$LOG_FILE.log\n\n"
   $_ECHO $PID_NB > $LOG_PATH/$LOG_FILE.pid
fi
}

Stop_Service() {
# Params : ID of Service
Define_Log_File_Name $1
if [ ! -f $LOG_PATH/$LOG_FILE.pid ] ; then
   $_ECHO "Service $1 doesn't seem's to run !"
   exit 1
fi
for file in  `$_LS $LOG_PATH/$LOG_FILE.pid`
do
        FILE_OWNER=`$_LS_L $file | $_AWK '{print $3}'`
        if [ "$FILE_OWNER" != "$USER_NAME" ]; then
           $_ECHO " Not owner of $LOG_PATH/$LOG_FILE.pid"
           $_ECHO " Service not Stopped."
        else
           KILL_PID=`cat $file`
           $_ECHO "Found process pid $KILL_PID file `basename $file` "
           if [ ! -f $MXJ_COMMON_JAR ] ; then
              kill -9 $KILL_PID >/dev/null
              if [ $? -eq 0 ] ; then
                 $_ECHO "***************" >> $LOG_PATH/$LOG_FILE.log
                 $_ECHO "Service stopped at `date` by $USER_NAME" >> $LOG_PATH/$LOG_FILE.log
                 $_ECHO "***************\n" >> $LOG_PATH/$LOG_FILE.log
                 rm $file
              else
                 $_ECHO "Process ID not found"
                 rm $file
              fi
           else
              KILLED=`java -Xmx8m -cp $MXJ_COMMON_JAR murex.middleware.system.ShutDownProcess $KILL_PID $MXJ_LAUNCHER_MAX_KILL_TIME`
              if [ $? -eq 0 ] ; then
                 $_ECHO "***************" >> $LOG_PATH/$LOG_FILE.log
                 $_ECHO $KILLED           >> $LOG_PATH/$LOG_FILE.log
                 $_ECHO "Service stopped at `date` by $USER_NAME" >> $LOG_PATH/$LOG_FILE.log
                 $_ECHO "***************\n" >> $LOG_PATH/$LOG_FILE.log
                 rm $file
              fi
              $_ECHO $KILLED
           fi
        fi
done

}

Kill_All() {
if [ -z "`$_LS $LOG_PATH/*.pid 2> /dev/null`" ] ; then
   $_ECHO "No Service running."
   exit 0
else
   for file in `$_LS $LOG_PATH/${MACHINE_NAME}.*.pid`
      do
        FILE_OWNER=`$_LS_L $file | $_AWK '{print $3}'`
        if [ "$FILE_OWNER" != "$USER_NAME" ]; then
           $_ECHO " Not owner of $LOG_PATH/$file"
           $_ECHO " Service not Stopped."
        else
           LOG_FILE=`$_LS $file | sed 's/.pid//'`
           SERVICE=`echo $file | cut -d"." -f2`
           KILL_PID=`cat $file`
           $_ECHO "Found process pid $KILL_PID file `basename $file` "
           if [ ! -f $MXJ_COMMON_JAR ] ; then
              kill -9 $KILL_PID >/dev/null
              if [ $? -eq 0 ] ; then
                 $_ECHO "***************" >> $LOG_FILE.log
                 $_ECHO "Service stopped at `date` by $USER_NAME" >> $LOG_FILE.log
                 $_ECHO "***************\n" >> $LOG_FILE.log
                 rm $file
              else
                 $_ECHO "Process ID not found, assuming process is dead"
                 rm $file
              fi
           else
              KILLED=`java -Xmx8m -cp $MXJ_COMMON_JAR murex.middleware.system.ShutDownProcess $KILL_PID $MXJ_LAUNCHER_MAX_KILL_TIME`
              if [ $? -eq 0 ] ; then
                 $_ECHO "***************" >> $LOG_FILE.log
                 $_ECHO $KILLED           >> $LOG_FILE.log
                 $_ECHO "Service stopped at `date` by $USER_NAME" >> $LOG_FILE.log
                 $_ECHO "***************\n" >> $LOG_FILE.log
                 rm $file
              fi
              $_ECHO $KILLED
           fi
        fi
      done
fi
}

Process_Status() {
# Params : None

if [ -z "`$_LS $LOG_PATH/*.pid 2> /dev/null`" ] ; then
   $_ECHO "No Service running."
   exit 0
fi

$_ECHO "\nFound running service(s) :"
for files in `$_LS $LOG_PATH/*.pid`
do
        SERVICE=`echo $files | sed s/\.pid//`
        SERVICE=`basename $SERVICE`
        SERVICE_LOCATION=`echo  $SERVICE | cut -d"." -f1`
        if [  "$SERVICE_LOCATION" = "$MACHINE_NAME" ] ; then
            PID_NB=`cat $files`
            FOUND=`$_PS -fp $PID_NB | grep $PID_NB`
            if [ ! "$FOUND" = "" ] ; then
            INFOS=`echo $FOUND | $_AWK '{ if ( \$5 ~ /:/ ) {  print " UID: "\$1 " PID: "\$2  " CPUTIME: "\$7 " STIME: "\$5 } else { print " UID: "\$1 " PID: "\$2  " CPUTIME: "\$8 " STIME: "\$5" " \$6 } }'`
                   $_ECHO " $SERVICE infos : \n\t$INFOS"
            else
                   $_ECHO " $SERVICE not running, removing PID file."
                   rm $files
                fi
        else
            $_ECHO " $SERVICE infos : \n\tService located on $SERVICE_LOCATION\n\tRun status from $SERVICE_LOCATION"
        fi
done

}

help() {
# Params : None
        cat <<END_OF_HELP | more

$0 usage:
Version : $MAJOR_VERSION.$MINOR_VERSION

`basename $0` [ -option ] [ Param ]* [ -k | -killall ]

Options:  -i:file               : use file as the setting file.
          -fs | -filserver      : launch file server service.
          -xmls | -xmlserver    : launch xmlserver server service.
          -xmlsnh | -xmlsnohub  : launch xmlserver server service without a hub.
          -hub                  : launch hub service.
          -tm                   : launch transactionmanager server service.
          -l | -launcher        : launch launcher server service.
          -mxml | -mxmlex       : launch mxmlexchange server service.
          -mxmlworker           : launch mxmlworker server service.
          -aagent               : launch amendment agent service.
          -alert                : launch alert engine service.
          -statistics           : launch mxmlexchange statistics service 
          -mxhibernate          : launch mxhibernate server service.
          -printsrv             : launch print server service.
          -warehouse            : launch warehouse server service.
          -mxrepository         : launch mxrepository server service.
          -mxnet | -murexnet    : launch murexnet server service.
          -olk | -import        : launch olk import server service.
          -mxp | -mxparam       : launch mxparam server service.
          -rtisession | -rtimportsession :
                                  launch a session of rtimport server service.
          -rticachesession | -rtimportcachesession :
                                  launch a session of rtimport-cache server service.
          -rticache | -rtimportcache :
                                  launch rtimport cache server service
          -rtifxgsession | -rtimportfixingsession :
                                  launch a session of rtimport fixing server service.
          -rti | -rtimport      : launch rtimport server service
          -rtifxg | -rtimportfixing : launch rtifixing import server service.
          -mlc                  : launch murex limits server service
          -lrb                  : launch Limits Request Browser.
          -mxcontrib | -mpcs    : launch mxcontribution server service.
          -feeder               : launch activity feeder server service.
          -mdcs | -cache        : launch MDCS cache service.
          -mdrs                 : launch MDRS service.
          -rtbs                 : launch Real Time Bridging Service.
          -rtbsbbg              : launch Real Time Bloomberg Connector Service.
          -rtbsrfa              : launch Real Time Reuters Connector Service.
          -federation           : launch Federation Service.
          -interfacelauncher    : launch a specific interface.
          -bbgsecurityimport    : launch Bloomberg Security Import service.
          -markitcredit         : launch Markit Credit service.
          -markitequity         : launch Markit Equity service. 
          -fix                  : launch FIX service. 
          -entitlement          : launch Mx Entitlement Service.
          -mandatory            : launch mandatory services.
          -client | -mx         : launch mx client.
          -clientmacro | -mxmacro : launch mx client in macro mode, use
                                    /MXJ_SCRIPT_READ_FROM:script.xml to
                                    change default script file.
          -monit | -monitor     : launch monitor.
          -smonit | -smonitor   : launch monitor in script mode (need
                                  extra arg /MXJ_CONFIG_FILE:script_file.xml).
          -scriptant            : launch script ant
                                  (need /MXJ_ANT_BUILD_FILE:build.xml and /MXJ_ANT_TARGET:target).
          -mxrdt                : remote diagnostic tool
          -ubslauncher          : launch the launcher for the UBS task.
          -lbnlauncher          : launch the launcher for the LBN task.
          -fixlistener          : launch the launcher for the FIXListener task.
          -vit                  : launch the launcher for the Volume Import Tool.
          -pgop                 : launch the launcher for the pgop sequencer.
          -pgop-tm              : launch the launcher for the pgop Task Manager.
          -mxdatapublisher      : launch MxDataPublisher service.
          -pfe                  : launch the launcher for the PFE service
          -pfe-tm               : launch the launcher for the PFE evaluators
          -xmlreq | -xmlrequest : launch xmlRequestScript class (need
                                  extra arg /MXJ_CONFIG_FILE:xmlRequestScript.xml).
          -p | -password        : launch password encryption.

          -k | -kill            : option to stop service.
          -killall              : stop all running services.
          -xatransactionlogger | -xalog : run the XATransactionLogger tool.
          -s | -status [-loop]  : show services status [every $LOOP_TIME sec].

          -j:[java option] | -jopt:[java option]  :
                                 add a JVM option, can be used as many times as options needed.
           -silent              : do not echo messages on console, log file only.
          -nosilent             : do echo messages on console.
          -h | -help            : this help.

        To stop a service use the same param as the start cmd and add -k
          ex :  to stop $0 -fs
                   use  $0 -fs -k
                to stop $0 -l /MXJ_CONFIG_FILE:mylauncher.mxres
                   use  $0 -l -k /MXJ_CONFIG_FILE:mylauncher.mxres
                use $0 -s to see running services.
                use $0 -killall to stop all running services.
Param used :
        Setting File:$SETTINGS_FILE
        /MXJ_FILESERVER_HOST:$MXJ_FILESERVER_HOST
        /MXJ_FILESERVER_PORT:$MXJ_FILESERVER_PORT
        /MXJ_JAR_FILE:$MXJ_JAR_FILE
        /MXJ_PORT:$MXJ_PORT (set for backward comatibility)
        /MXJ_HOST:$MXJ_HOST (set for backward comatibility)
        /MXJ_SITE_NAME:$MXJ_SITE_NAME
        /MXJ_HUB_NAME:$MXJ_HUB_NAME
        /MXJ_PLATFORM_NAME:$MXJ_PLATFORM_NAME
        /MXJ_PROCESS_NICK_NAME:$MXJ_PROCESS_NICK_NAME
        /MXJ_CONFIG_FILE:$MXJ_CONFIG_FILE
        /MXJ_MXMLEX_CONFIG_FILE:$MXJ_MXMLEX_CONFIG_FILE
        /MXJ_MXMLEX_CONFIG_FILE_SECONDARY:$MXJ_MXMLEX_CONFIG_FILE_SECONDARY
        /MXJ_MXMLEX_CONFIG_FILE_SPACES:$MXJ_MXMLEX_CONFIG_FILE_SPACES
        /MXJ_MXMLEX_CONFIG_FILE_WORKER:$MXJ_MXMLEX_CONFIG_FILE_WORKER
        /MXJ_MXMLEX_CONFIG_FILE_ALERT:$MXJ_MXMLEX_CONFIG_FILE_ALERT
        /MXJ_MXMLEX_CONFIG_FILE_STATISTICS:$MXJ_MXMLEX_CONFIG_FILE_STATISTICS
        /MXJ_AAGENT_CONFIG_FILE:$MXJ_AAGENT_CONFIG_FILE
        /MXJ_MXHIBERNATE_CONFIG_FILE:$MXJ_MXHIBERNATE_CONFIG_FILE
        /MXJ_PRINTSRV_CONFIG_FILE:$MXJ_PRINTSRV_CONFIG_FILE
        /MXJ_MXDATAPUBLISHER_CONFIG_FILE:$MXJ_MXDATAPUBLISHER_CONFIG_FILE
        /MXJ_WAREHOUSE_CONFIG_FILE:$MXJ_WAREHOUSE_CONFIG_FILE
        /MXJ_MXREPOSITORY_CONFIG_FILE:$MXJ_MXREPOSITORY_CONFIG_FILE
        /MXJ_CONTRIBUTION_CONFIG_FILE:$MXJ_CONTRIBUTION_CONFIG_FILE
        /MXJ_RTBS_CONFIG_FILE:$MXJ_RTBS_CONFIG_FILE
        /MXJ_FEDERATION_CONFIG_FILE:$MXJ_FEDERATION_CONFIG_FILE
        /MXJ_ENTITLEMENT_CONFIG_FILE:$MXJ_ENTITLEMENT_CONFIG_FILE
        /MXJ_ENTITLEMENT_JAR_FILE:$MXJ_ENTITLEMENT_JAR_FILE
        /MXJ_LOGGER_FILE:$MXJ_LOGGER_FILE
        /MXJ_SCRIPT_READ_FROM:$MXJ_SCRIPT
        MUREXNET_PORT:$MUREXNET_PORT
Specific $SETTINGS_FILE settings:
        File Server            :$FILESERVER_ARGS
        XmlServer args         :$XML_SERVER_ARGS $XML_JVM_ARGS
        Hub args               :$HUB_HOME_ARGS
        MxMlExchange all       :$MXML_JVM_ARGS $MXML_SERVER_ARGS
        MxMlExchange secondary :$MXMLSECONDARY_JVM_ARGS $MXML_SERVER_ARGS
        MxMlExchange spaces    :$MXMLSPACES_JVM_ARGS $MXML_SERVER_ARGS
        MxMlExchange worker    :$MXMLWORKER_JVM_ARGS $MXML_SERVER_ARGS
        AmendmentAgent args    :$AAGENT_SERVER_ARGS $AAGENT_JVM_ARGS
        MxHibernate args       :$MXHIBERNATE_SERVER_ARGS $MXHIBERNATE_JVM_ARGS
        PrintSrv args          :$PRINTSRV_ARGS $PRINTSRV_JVM_ARGS
        Warehouse args         :$WAREHOUSE_SERVER_ARGS $WAREHOUSE_JVM_ARGS
        Mandatory args         :$MANDATORY_SERVER_ARGS $MANDATORY_JVM_ARGS
        MxRepository args      :$MXREPOSITORY_SERVER_ARGS
        MDCS args              :$MDCS_SERVER_ARGS $MDCS_JVM_ARGS
        MDRS args              :$MDRS_SERVER_ARGS $MDRS_JVM_ARGS
        RTBS args              :$RTBS_SERVER_ARGS $RTBS_JVM_ARGS
        FEDERATION args        :$FEDERATION_SERVER_ARGS $FEDERATION_JVM_ARGS
        Entitlement args       :$ENTITLEMENT_ARGS $ENTITLEMENT_JVM_ARGS
        MLC args               :$MXMLC_SERVER_ARGS $MXMLC_JVM_ARGS
        Launcher args          :$LAUNCHER_ARGS
        Murexnet args          :$MUREXNET_ARGS
        Real Time host display :$RTISESSION_XWIN_DISP
        MxDataPublisher args   :$MXDATAPUBLISHER_ARGS $MXDATAPUBLISHER_JVM_ARGS
Environment:
        LOG_PATH:$LOG_PATH
        APPEND_LOG:$APPEND_LOG
        JAVAHOME:$JAVAHOME
        XA_CHECK_PERIOD:$XA_CHECK_PERIOD(min)
        SYBASE:$SYBASE
        SYBASE_OCS:$SYBASE_OCS
        ORACLE_HOME:$ORACLE_HOME

END_OF_HELP
$_ECHO "\nFile descriptors raised to `ulimit -n` for current shell.\n"
case $OS_TYPE in
        SunOS )
        $_ECHO "\nLD_LIBRARY_PATH=$LD_LIBRARY_PATH\n"
        ;;
        AIX )
        $_ECHO "\nLIBPATH=$LIBPATH\n"
        ;;
        HP-UX )
        $_ECHO "\nSHLIB_PATH=$SHLIB_PATH\n"
        ;;
        Linux )
        $_ECHO "\nLD_LIBRARY_PATH=$LD_LIBRARY_PATH\n"
        ;;
        * )
        $_ECHO "Warning : Do not know how to handle this OS type $OS_TYPE."
        ;;
esac

$_ECHO `java -version`
if [ "$SYBASE" != "" ] ; then
   if [ ! -f $SYBASE/$SYBASE_OCS/bin/isql ] ; then
      $_ECHO "    Mx 3.1: isql not found, please check the SYBASE environment variable"
      $_ECHO "          in the $SETTINGS_FILE script file"
   else
      $SYBASE/$SYBASE_OCS/bin/isql -v
   fi
fi
if [ "$ORACLE_HOME" != "" ] ; then
   if [ ! -f $ORACLE_HOME/bin/sqlplus ] ; then
      $_ECHO "    Mx 3.1: sqlplus not found, please check the ORACLE_HOME environment variable"
      $_ECHO "          in the $SETTINGS_FILE script file"
   else
      $ORACLE_HOME/bin/sqlplus -V
   fi
fi
$_ECHO Mx version
./mx
cat ./logs/mxversion.log
exit 0
}

getParams() {
while [ $# != 0 ]
        do
        ARG0=$1

        PARAM=`echo $ARG0 | cut -f1 -d":"`
        VALUE=`echo $ARG0 | cut -f2,3 -d":"`

        if [ "$VALUE" = "" ] ; then
           help
           exit 0
        fi
        case $PARAM in
            -help | /help | -h | /h | -env | /env)
                help
                exit 0
                ;;
            -i )
                SETTINGS_FILE=$VALUE
                if [ $# -eq 1  ] ; then
                   help
                   exit 0
                fi
                ;;
			-sync )
                SYNC=1
                ;; 
            -xmls | -xmlserver )
                XMLS=1
                ;;
            -xmlsnohub | -xmlservernohub | -xmlsnh )
                XMLSNOHUB=1
                ;;
            -hub )
                HUB=1
                ;;
            -tm )
                TM=1
                ;;
           -fs | -filserver )
                FS=1
                ;;
            -l | -launcher )
                LAUNCHER=1
                ;;
            -mandatory )
                MANDATORY=1
                ;;
            -mxml | -mxmlex )
                MXMLEX=1
                ;;
            -mxmlworker )
                MXMLWORKER=1
                ;;
            -alert )
                ALERT=1
                ;;
            -statistics )
                STATISTICS=1
                ;;
            -aagent )
                AAGENT=1
                ;;
            -mxhibernate )
                MXHIBERNATE=1
                ;;
            -printsrv )
                PRINTSRV=1
                ;;
            -mxdatapublisher )
                MXDATAPUBLISHER=1
                ;;
            -warehouse )
                WAREHOUSE=1
                ;;
            -mxrepository )
                MXREPOSITORY=1
                ;;
            -mdcs | -cache )
                MDCS=1
                ;;
            -mdrs  )
                MDRS=1
                ;;
            -olk | -import )
                OLK=1
                ;;
            -interfacelauncher )
                INTERFACELAUNCHER=1
                ;;
            -bbgsecurityimport )
                BSIS=1
                ;;
            -markitcredit )
                MCS=1
                ;;
            -markitequity )
                MES=1
                ;;
            -fix )
                FIX=1
                ;;
            -mxp | -mxparam )
                MXPARAM=1
                ;;
            -rtbs )
                RTBS=1
                ;;
            -rtbsbbg )
                RTBSBBG=1
                ;;
            -rtbsrfa )
                RTBSRFA=1
                ;;
            -federation )
                FEDERATION=1
                ;;
            -entitlement )
                MXJ_LOGGER_FILE=""
                export MXJ_LOGGER_FILE
                ENTITLEMENT=1
                ;;
            -rtisession | -rtimportsession )
                RTISESSION=1
                ;;
                        -rticachesession | -rtimportcachesession )
                RTICACHESESSION=1
                ;;
            -rtifxgsession | -rtimportfixingsession )
                RTIFXGSESSION=1
                ;;
            -rti | -rtimport )
                RTIMPORT=1
                ;;
                        -rticache | -rtimportcache )
                RTIMPORTCACHE=1
                ;;
            -rtifxg | -rtimportfixing )
                RTIFXG=1
                ;;
            -mxcontrib | -mpcs )
                MXCONTRIB=1
                ;;
            -feeder )
                FEEDER=1
                ;;
            -killfeeder)
                MXJ_FEEDER_VALUE=$VALUE
                $_ECHO "Activityfeeder:$MXJ_FEEDER_VALUE"
                KILLFEEDER=1
                ;;
            -mxnet | -murexnet )
                MUREXNET=1
                ;;
            -client | -mx )
                CLIENT=1
                ;;
            -clientmacro | -mxmacro )
                CLIENTMACRO=1
                ;;
            -monit | -monitor )
                MONIT=1
                ;;
            -mlc | -jls )
                MLC=1
                ;;
            -lrb )
                LRB=1
                ;;
            -smonit | -smonitor )
                MXJ_CONFIG_FILE=""
                export MXJ_CONFIG_FILE
                S_MONIT=1
                ;;
            -scriptant )
                MXJ_ANT_BUILD_FILE=""
                export MXJ_ANT_BUILD_FILE
                MXJ_ANT_TARGET=""
                export MXJ_ANT_TARGET
                SCRIPT_ANT=1
                ;;
            -mxrdt)
                MXRDT=1
                break;
                ;;
            -ubslauncher )
                UBSLAUNCHER=1
                ;;
            -lbnlauncher )
                LBNLAUNCHER=1
                ;;
            -fixlistener )
                FIXLISTENER=1
                ;;
             -vit )
                MXJ_CONFIG_FILE=""
                export MXJ_CONFIG_FILE
                MXJ_JAR_FILE=""
                export MXJ_JAR_FILE
                MXJ_LOGGER_FILE=""
                export MXJ_LOGGER_FILE
                VIT=1
                ;;
             -pgop )
                MXJ_CONFIG_FILE=""
                export MXJ_CONFIG_FILE
                MXJ_JAR_FILE=""
                export MXJ_JAR_FILE
                MXJ_LOGGER_FILE=""
                export MXJ_LOGGER_FILE
                PGOP=1
                ;;
             -pgop-tm )
                MXJ_CONFIG_FILE=""
                export MXJ_CONFIG_FILE
                MXJ_JAR_FILE=""
                export MXJ_JAR_FILE
                MXJ_LOGGER_FILE=""
                export MXJ_LOGGER_FILE
                PGOPTM=1
                ;;
             -pfe )
                MXJ_CONFIG_FILE=""
                export MXJ_CONFIG_FILE
                MXJ_JAR_FILE=""
                export MXJ_JAR_FILE
                MXJ_LOGGER_FILE=""
                export MXJ_LOGGER_FILE
                PFE=1
                ;;
             -pfe-tm )
                MXJ_CONFIG_FILE=""
                export MXJ_CONFIG_FILE
                MXJ_JAR_FILE=""
                export MXJ_JAR_FILE
                MXJ_LOGGER_FILE=""
                export MXJ_LOGGER_FILE
                PFETM=1
                ;;
             -xmlreq | -xmlrequest )
                MXJ_CONFIG_FILE=""
                export MXJ_CONFIG_FILE
                XMLREQ=1
                ;;
            -p | -password )
                PASSWORD=1
                ;;
            -stop | stop | -kill | kill | -k | k )
                STOP=1
                ;;
            -stopall | stopall | -killall | killall )
                STOPALL=1
                ;;
            -status | status | -s | s )
                STATUS=1
                ;;
            -loop )
                LOOP=1
                ;;
            -j | j | -jopt | jopt )
                JVM_OPTION=$JVM_OPTION" "$VALUE
                $_ECHO "Using JVM option:$VALUE "
                ;;
            -silent )
                SILENT=1
                ;;
                        -nosilent )
                SILENT=0
                ;;
            -XATransactionLogger | -xatransactionlogger | -XALOG | -xalog )
                XALOGGER=1
                ;;
            /MXJ_PORT | -MXJ_PORT )
                MXJ_PORT=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_HOST | -MXJ_HOST )
                MXJ_HOST=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_SITE_NAME | -MXJ_SITE_NAME )
                MXJ_SITE_NAME=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_HUB_NAME | -MXJ_HUB_NAME )
                MXJ_HUB_NAME=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_FILESERVER_HOST | -MXJ_FILESERVER_HOST )
                MXJ_FILESERVER_HOST=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_FILESERVER_PORT | -MXJ_FILESERVER_PORT )
                MXJ_FILESERVER_PORT=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_JAR_FILE | -MXJ_JAR_FILE )
                MXJ_JAR_FILE=$VALUE
				MXJ_MONITOR_JAR_FILE=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_CONFIG_FILE | -MXJ_CONFIG_FILE )
                NBP=`echo $VALUE | $_AWK -F. '{ print NF }'`
                if ( [ "$LAUNCHER" = "1" ] || [ "$RTBS" = "1" ] ); then
                        if [ "$NBP" = "2" ] ; then
                                VALUE=`echo $MXJ_CONFIG_FILE | $_AWK  -F. '{ print \$1"."\$2"."\$3"." }'`$VALUE
                                echo "Guessing config file is $VALUE"
                        fi
                        if [ "$NBP" = "1" ] ; then
                                VALUE=`echo $MXJ_CONFIG_FILE | $_AWK  -F. '{ print \$1"."\$2"."\$3"." }'`${VALUE}.mxres
                                echo "Guessing config file is $VALUE"
                        fi
                fi
                MXJ_CONFIG_FILE=$VALUE
                MXJ_MXMLEX_CONFIG_FILE=$VALUE
                MXJ_MXHIBERNATE_CONFIG_FILE=$VALUE
                MXJ_PRINTSRV_CONFIG_FILE=$VALUE
                                         MXJ_MXDATAPUBLISHER_CONFIG_FILE=$VALUE
                MXJ_CONTRIBUTION_CONFIG_FILE=$VALUE
                MXJ_RTBS_CONFIG_FILE=$VALUE
                MXJ_FEDERATION_CONFIG_FILE=$VALUE
                MXJ_ENTITLEMENT_CONFIG_FILE=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_MANDATORY_CONFIG_FILE | -MXJ_MANDATORY_CONFIG_FILE )
                MXJ_MANDATORY_CONFIG_FILE=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_MXMLEX_CONFIG_FILE | -MXJ_MXMLEX_CONFIG_FILE )
                MXJ_MXMLEX_CONFIG_FILE=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_MXMLEX_CONFIG_FILE_SECONDARY | -MXJ_MXMLEX_CONFIG_FILE_SECONDARY )
                MXJ_MXMLEX_CONFIG_FILE_SECONDARY=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_MXMLEX_CONFIG_FILE_SPACES | -MXJ_MXMLEX_CONFIG_FILE_SPACES )
                MXJ_MXMLEX_CONFIG_FILE_SPACES=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_MXMLEX_CONFIG_FILE_WORKER | -MXJ_MXMLEX_CONFIG_FILE_WORKER )
                MXJ_MXMLEX_CONFIG_FILE_WORKER=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_MXMLEX_CONFIG_FILE_ALERT | -MXJ_MXMLEX_CONFIG_FILE_ALERT )
                MXJ_MXMLEX_CONFIG_FILE_ALERT=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_MXMLEX_CONFIG_FILE_STATISTICS | -MXJ_MXMLEX_CONFIG_FILE_STATISTICS )
                MXJ_MXMLEX_CONFIG_FILE_STATISTICS=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_AAGENT_CONFIG_FILE | -MXJ_AAGENT_CONFIG_FILE )
                MXJ_AAGENT_CONFIG_FILE=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_MXHIBERNATE_CONFIG_FILE | -MXJ_MXHIBERNATE_CONFIG_FILE )
                MXJ_MXHIBERNATE_CONFIG_FILE=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_PRINTSRV_CONFIG_FILE | -MXJ_PRINTSRV_CONFIG_FILE )
                MXJ_PRINTSRV_CONFIG_FILE=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_MXDATAPUBLISHER_CONFIG_FILE | -MXJ_MXDATAPUBLISHER_CONFIG_FILE )
                MXJ_MXDATAPUBLISHER_CONFIG_FILE=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_WAREHOUSE_CONFIG_FILE | -MXJ_WAREHOUSE_CONFIG_FILE )
                MXJ_WAREHOUSE_CONFIG_FILE=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_MXREPOSITORY_CONFIG_FILE | -MXJ_MXREPOSITORY_CONFIG_FILE )
                MXJ_MXREPOSITORY_CONFIG_FILE=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_MDCS_CONFIG_FILE | -MXJ_MDCS_CONFIG_FILE )
                MXJ_MDCS_CONFIG_FILE=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_MDRS_CONFIG_FILE | -MXJ_MDRS_CONFIG_FILE )
                MXJ_MDRS_CONFIG_FILE=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_CONTRIBUTION_CONFIG_FILE | MXJ_CONTRIBUTION_CONFIG_FILE )
                MXJ_CONTRIBUTION_CONFIG_FILE=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_ACTIVITY_FEEDER_CONFIG_FILE | MXJ_ACTIVITY_FEEDER_CONFIG_FILE )
                MXJ_ACTIVITY_FEEDER_CONFIG_FILE=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_PLATFORM_NAME | -MXJ_PLATFORM_NAME )
                MXJ_PLATFORM_NAME=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_PROCESS_NICK_NAME | -MXJ_PROCESS_NICK_NAME )
                MXJ_PROCESS_NICK_NAME=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_LOGGER_FILE | -MXJ_LOGGER_FILE)
                MXJ_LOGGER_FILE=$VALUE
                MXJ_RTBS_LOGGER_FILE=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_POLICY_FILE | -MXJ_POLICY_FILE )
                MXJ_POLICY_FILE=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_SCRIPT_READ_FROM| -MXJ_SCRIPT_READ_FROM)
                MXJ_SCRIPT=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_INSTALLATION_CODE| -MXJ_INSTALLATION_CODE )
                 MXJ_INSTALLATION_CODE=$VALUE
                 $_ECHO "Using $PARAM:$VALUE"
                 EXTRA_ARGS="$EXTRA_ARGS $ARG0"
                 ;;
            /MUREXNET_PORT| -MUREXNET_PORT| MUREXNET_PORT)
                MUREXNET_PORT=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXRDT_OUTPUT_FILENAME| -MXRDT_OUTPUT_FILENAME)
                MXRDT_OUTPUT_FILENAME=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            /MXJ_LAUNCHER_MAX_KILL_TIME| -MXJ_LAUNCHER_MAX_KILL_TIME)
                MXJ_LAUNCHER_MAX_KILL_TIME=$VALUE
                $_ECHO "Using $PARAM:$VALUE"
                ;;
            * )
                EXTRA_ARGS="$EXTRA_ARGS $ARG0"
                ;;
        esac
        shift
done
}

#Main

XMLS=0
XMLSNOHUB=0
HUB=0
TM=0
FS=0
SYNC=0
LAUNCHER=0
MANDATORY=0
MXMLEX=0
MXMLWORKER=0
AAGENT=0
MLC=0
LRB=0
MXHIBERNATE=0
PRINTSRV=0
MXDATAPUBLISHER=0
WAREHOUSE=0
MXREPOSITORY=0
MDCS=0
MDRS=0
RTBS=0
RTBSBBG=0
RTBSRFA=0
FEDERATION=0
ENTITLEMENT=0
OLK=0
INTERFACELAUNCHER=0
BSIS=0
MCS=0
MES=0
FIX=0
MXPARAM=0
RTISESSION=0
RTICACHESESSION=0
RTIFXGSESSION=0
RTIMPORT=0
RTIMPORTCACHE=0
KILLFEEDER=0
RTIFXG=0
MXCONTRIB=0
FEEDER=0
MUREXNET=0
CLIENT=0
CLIENTMACRO=0
MONIT=0
S_MONIT=0
SCRIPT_ANT=0
MXRDT=0
UBSLAUNCHER=0
LBNLAUNCHER=0
FIXLISTENER=0
VIT=0
PGOP=0
PGOPTM=0
PFE=0
PFETM=0
PASSWORD=0
STOP=0
STOPALL=0
STATUS=0
LOOP=0
XMLREQ=0
ALERT=0
STATISTICS=0
JVM_OPTION=" -showversion "

# StAX Configuration Platform independent with WoodStox
JVM_OPTION=$JVM_OPTION" -Djavax.xml.stream.XMLEventFactory=com.ctc.wstx.stax.WstxEventFactory"
JVM_OPTION=$JVM_OPTION" -Djavax.xml.stream.XMLInputFactory=com.ctc.wstx.stax.WstxInputFactory"
JVM_OPTION=$JVM_OPTION" -Djavax.xml.stream.XMLOutputFactory=com.ctc.wstx.stax.WstxOutputFactory"

if [ "$OS_TYPE" = "AIX" ]; then
  JVM_OPTION=$JVM_OPTION" -Djavax.xml.parsers.SAXParserFactory=org.apache.xerces.jaxp.SAXParserFactoryImpl "
  JVM_OPTION=$JVM_OPTION" -Djavax.xml.parsers.DocumentBuilderFactory=org.apache.xerces.jaxp.DocumentBuilderFactoryImpl "
  JVM_OPTION=$JVM_OPTION" -Djavax.xml.transform.TransformerFactory=org.apache.xalan.processor.TransformerFactoryImpl "
fi
MXJ_INSTALLATION_CODE=""
SILENT=1
XALOGGER=0
EXTRA_ARGS=

Setting_Env
if [ $# = 0 ] ; then
        help;
        exit 0 ;
fi

getParams $*

Copy_mxjboot

if [ "$EXTRA_ARGS" != "" ] ; then
        $_ECHO "Extra arguments used: $EXTRA_ARGS"
fi
if [ $SYNC = 1 ] ; then
        SynchronousStartup $*;
fi
if [ $FS = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service fileserver
        else
                Fileserver $*;
        fi
fi
if [ $TM = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service transactionmanager
        else
                TransactionManager $*;
        fi
fi
if [ $XMLS = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service xmlserver
        else
                Xmlserver $*;
        fi
fi
if [ $XMLSNOHUB = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service xmlservernohub
        else
                XmlserverNoHub $*;
        fi
fi

if [ $HUB = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service hubhome
        else
                HubHome $*;
        fi
fi

if [ $LAUNCHER = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service launcher
        else
                Launcher $*;
        fi
fi
if [ $MANDATORY = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service mandatory
        else
                Mandatory $*;
        fi
fi
if [ $MXMLEX = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service mxmlexchange
                Stop_Service mxmlexchangesecondary
                Stop_Service mxmlexchangespaces
                Stop_Service mxmlworker
        else
                MxmlexchangeSettings
                MxmlexchangePrimary
                MxmlexchangeSecondary
                MxmlexchangeWorker
        fi
fi
if [ $MXMLWORKER = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service mxmlworker
        else
                MxmlexchangeSettings
                MxmlexchangeWorker
        fi
fi
if [ $ALERT = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service alert
        else
                AlertEngine
        fi
fi

if [ $STATISTICS = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service statistics
        else
                StatisticsEngine
        fi
fi

if [ $AAGENT = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service aagent
        else
                Aagent $*;
        fi
fi
if [ $MLC = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service mxmlc
        else
                MXMLC $*;
        fi
fi
if [ $LRB = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service lrb
        else
                MXLRB $*;
        fi
fi
if [ $MXHIBERNATE = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service mxhibernate
        else
                Mxhibernate $*;
        fi
fi
if [ $PRINTSRV = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service printsrv
        else
                PrintSrv $*;
        fi
fi
if [ $MXDATAPUBLISHER = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service mxdatapublisher
        else
                MxDataPublisher $*;
        fi
fi
if [ $WAREHOUSE = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service warehouse
        else
                Warehouse $*;
        fi
fi
if [ $MXREPOSITORY = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service mxrepository
        else
                MxRepository $*;
        fi
fi
if [ $MDCS = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service mdcs
        else
                MDCS_CACHE $*;
        fi
fi
if [ $MDRS = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service mdrs
        else
                MDRS_ENGINE $*;
        fi
fi
if [ $INTERFACELAUNCHER = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service launcher
        else
                InterfaceLauncher $*;
        fi
fi
if [ $BSIS = 1 ] ; then
        MXJ_CONFIG_FILE=$BBG_SEC_IMPORT_CONFIG_FILE
                MXJ_LOGGER_FILE="public.mxres.loggers.mxinterfaces_logger.mxres"
                if [ $STOP = 1 ] ; then
                Stop_Service launcher
        else
                LAUNCHER_ARGS=$BSIS_ARGS
                                INTERFACES_SRV_JVM_ARGS=$BSIS_JVM_ARGS
                                InterfaceLauncher $*;
        fi
fi
if [ $MCS = 1 ] ; then
        MXJ_CONFIG_FILE=$MARKIT_CREDIT_CONFIG_FILE
                MXJ_LOGGER_FILE="public.mxres.loggers.mxinterfaces_logger.mxres"
                if [ $STOP = 1 ] ; then
                Stop_Service launcher
        else
                LAUNCHER_ARGS=$MARKIT_CREDIT_ARGS
                                INTERFACES_SRV_JVM_ARGS=$MARKIT_CREDIT_JVM_ARGS
                                InterfaceLauncher $*;
        fi
fi
if [ $MES = 1 ] ; then
        MXJ_CONFIG_FILE=$MARKIT_EQUITY_CONFIG_FILE
        MXJ_LOGGER_FILE="public.mxres.loggers.mxinterfaces_logger.mxres"
        if [ $STOP = 1 ] ; then
                Stop_Service launcher
        else
                LAUNCHER_ARGS=$MARKIT_EQUITY_ARGS
				INTERFACES_SRV_JVM_ARGS=$MARKIT_EQUITY_JVM_ARGS
				InterfaceLauncher $*;
        fi
fi
if [ $FIX = 1 ] ; then
        MXJ_CONFIG_FILE=$FIX_CONFIG_FILE
		MXJ_LOGGER_FILE="public.mxres.loggers.mxinterfaces_logger.mxres"
		if [ $STOP = 1 ] ; then
                Stop_Service launcher
        else
                LAUNCHER_ARGS=$FIX_ARGS
				INTERFACES_SRV_JVM_ARGS=$FIX_JVM_ARGS
				InterfaceLauncher $*;
        fi
fi

if [ $OLK = 1 ] ; then
        if [ $STOP = 1 ] ; then
               Stop_Service olk
        else
                Olk $*;
        fi
fi
if [ $MXPARAM = 1 ] ; then
        if [ $STOP = 1 ] ; then
                #Stop_Service mxparam
                MxParam stop $*;
        else
                MxParam start $*;
        fi
fi

if [ $RTBS = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service rtbs
        else
                RealTimeBridgingService $*;
        fi
fi
if [ $RTBSBBG = 1 ] ; then
        MXJ_CONFIG_FILE=$RTBSBBG_CONFIG_FILE
        MXJ_LOGGER_FILE="public.mxres.loggers.mxinterfaces_rtbsbbg_logger.mxres"
        if [ $STOP = 1 ] ; then
                Stop_Service launcher
        else
                LAUNCHER_ARGS=$RTBSBBG_ARGS
                INTERFACES_SRV_JVM_ARGS=$RTBSBBG_JVM_ARGS
                InterfaceLauncher $*;
        fi
fi
if [ $RTBSRFA = 1 ] ; then
        MXJ_CONFIG_FILE=$RTBSRFA_CONFIG_FILE
        MXJ_LOGGER_FILE="public.mxres.loggers.mxinterfaces_rtbsrfa_logger.mxres"
        if [ $STOP = 1 ] ; then
                Stop_Service launcher
        else
                LAUNCHER_ARGS=$RTBSRFA_ARGS
                INTERFACES_SRV_JVM_ARGS=$RTBSRFA_JVM_ARGS
                InterfaceLauncher $*;
        fi
fi
if [ $FEDERATION = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service federation
        else
                FederationService $*;
        fi
fi
if [ $ENTITLEMENT = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service entitlement
        else
                EntitlementService $*;
        fi
fi
if [ $KILLFEEDER = 1 ] ; then
        KillFeeder $*;
fi
if [ $RTISESSION = 1 ] ; then
                RtImport session $*;
fi
if [ $RTIFXGSESSION = 1 ] ; then
                RtImport fxgsession $*;
fi
if [ $RTICACHESESSION = 1 ] ; then
                RtImport rticachesession $*;
fi

if [ $RTIMPORT = 1 ] ; then
        if [ $STOP = 1 ] ; then
                #Stop_Service rtimport
                RtImport stop $*;
        else
                RtImport start $*;
        fi
fi

if [ $RTIMPORTCACHE = 1 ] ; then
        if [ $STOP = 1 ] ; then
                #Stop_Service rtimportcache
                RtImport rticachestop $*;
        else
                RtImport rticachestart $*;
        fi
fi
if [ $RTIFXG = 1 ] ; then
        if [ $STOP = 1 ] ; then
                #Stop_Service rtimport
                RtImport fxgstop $*;
        else
                RtImport fxgstart $*;
        fi
fi
if [ $MXCONTRIB = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service mxcontrib
        else
                MxContribution $*;
        fi
fi
if [ $FEEDER = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service feeder
        else
                MxActivityFeeder $*;
        fi
fi
if [ $MUREXNET = 1 ] ; then
        if [ $STOP = 1 ] ; then
                Stop_Service murexnet
        else
                Murexnet $*;
        fi
fi
if [ $CLIENT = 1 ] ; then
        Client $*;
fi
if [ $CLIENTMACRO = 1 ] ; then
        ClientMacro $*;
fi
if [ $MONIT = 1 ] ; then
        Monitor $*;
fi
if [ $S_MONIT = 1 ] ; then
        Script_Monitor $*;
fi
if [ $SCRIPT_ANT = 1 ] ; then
        Script_Ant $*;
fi
if [ $MXRDT = 1 ] ; then
        MxRdt $*
fi
if [ $UBSLAUNCHER = 1 ] ; then
                MXJ_CONFIG_FILE=$MXJ_UBS_CONFIG_FILE
                if [ $STOP = 1 ] ; then
                        Stop_Service launcher
                else
                        LAUNCHER_ARGS=$UBS_LAUNCHER_ARGS
                        Launcher $*;
                fi
fi
if [ $LBNLAUNCHER = 1 ] ; then
                MXJ_CONFIG_FILE=$MXJ_LBN_CONFIG_FILE
                if [ $STOP = 1 ] ; then
                        Stop_Service launcher
                else
                        Launcher $*;
                fi
fi
if [ $FIXLISTENER = 1 ] ; then
                MXJ_CONFIG_FILE=$MXJ_FIXLISTENER_CONFIG_FILE
                if [ $STOP = 1 ] ; then
                        Stop_Service launcher
                else
                        Launcher $*;
                fi
fi
if [ $XMLREQ = 1 ] ; then
        XmlRequestScript $*;
fi
if [ $PASSWORD = 1 ] ; then
        PasswordEncryption $*;
fi
if [ $XALOGGER = 1 ] ; then
        XATransactionLogger $*;
fi
if [ $STATUS = 1 ] ; then

        Process_Status $*;
        while [ $LOOP = 1 ]
        do
                $_ECHO "\nSleeping $LOOP_TIME sec"
                sleep $LOOP_TIME
                Process_Status $*
        done
fi
if [ $VIT = 1 ] ; then
        if [ "$MXJ_CONFIG_FILE" = "" ]  ; then
                MXJ_CONFIG_FILE="public.mxres.common.launchermxvit.mxres"
        fi
        if [ $STOP = 1 ] ; then
                Stop_Service vit
        else
                VitLauncher $*;
        fi
fi
if [ $PGOP = 1 ] ; then
        if [ "$MXJ_CONFIG_FILE" = "" ]  ; then
                MXJ_CONFIG_FILE="public.mxres.common.launchermxpgop.mxres"
        fi
        if [ $STOP = 1 ] ; then
                Stop_Service pgop
        else
                PgopLauncher $*;
        fi
fi
if [ $PGOPTM = 1 ] ; then
        if [ "$MXJ_CONFIG_FILE" = "" ]  ; then
                MXJ_CONFIG_FILE="public.mxres.common.launchermxpgop-tm.mxres"
        fi
        if [ $STOP = 1 ] ; then
                Stop_Service pgop-tm
        else
                PgopLauncherTaskManager $*;
        fi
fi
if [ $PFE = 1 ] ; then
        if [ "$MXJ_CONFIG_FILE" = "" ]  ; then
                MXJ_CONFIG_FILE="public.mxres.common.launcherpfe.mxres"
        fi
        if [ $STOP = 1 ] ; then
                Stop_Service pfe
        else
                PfeLauncher $*;
        fi
fi
if [ $PFETM = 1 ] ; then
        if [ "$MXJ_CONFIG_FILE" = "" ]  ; then
                MXJ_CONFIG_FILE="public.mxres.common.launcherpfe-tm.mxres"
        fi
        if [ $STOP = 1 ] ; then
                Stop_Service pfe-tm
        else
                PfeEvaluatorLauncher $*;
        fi
fi
if [ $STOPALL = 1 ] ; then
        Kill_All
fi
#END of SCRIPT
