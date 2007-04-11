#!/bin/bash
PROFILER_ARGS=
PROFILE=$1
shift
# sets up CP env var
. ./setupclasspath.sh

thehosts=$1
shift
echo $thehosts
$JAVA_HOME/bin/java -server -Xmx1024m -Xms1024m -XX:NewSize=300m -cp $CP $PROFILER_ARGS -Damqj.logging.level="INFO" org.openamq.requestreply1.ServiceRequestingClient $thehosts guest guest /test serviceQ "$@"