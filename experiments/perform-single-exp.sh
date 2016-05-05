#!/bin/bash

#
# Defaults
#
algo="brownout-diff"
scenario="scenarios/static-heterogeneous-88111-2.sh"
vms="vm-rubis-0 vm-rubis-1 vm-rubis-2 vm-rubis-3 vm-rubis-4 vm-rubis-5"
realexps_dir=`dirname $0`
httpmon="$realexps_dir/../httpmon/httpmon"
lighttpd_dir="$realexps_dir/../brownout-lb-lighttpd/src/"
lighttpd="$lighttpd_dir/lighttpd"
url="http://172.17.0.8:8080/PHP/RandomItem.php"

#
# Helper functions
#
function setCpus {
	echo [`date +%s`] vm=$1 cpus=$2 >&8
	curl -s -X POST -d "op=set%5fvcpus&vcpus=$2" http://localhost:8000/xend/domain/$1 >> actuator.log 2>&1
}
function setCount {
	echo [`date +%s`] count=$1 >&8
	echo "count=$1" >&9
}
function setOpen {
	echo [`date +%s`] open=$1 >&8
	echo "open=$1" >&9
}
function setThinkTime {
	echo [`date +%s`] thinktime=$1 >&8
	echo "thinktime=$1" >&9
}
function setConcurrency {
	echo [`date +%s`] concurrency=$1 >&8
	echo "concurrency=$1" >&9
}
function setTimeout {
	echo [`date +%s`] timeout=$1 >&8
	echo "timeout=$1" >&9
}
function setStart {
	echo [`date +%s`] start >&8
}
function setPause {
	echo [`date +%s`] fail vm=$1 >&8
	ssh $1 sudo killall -w -9 apache2 >> actuator.log 2>&1 &
	ssh $1 sudo service mysql stop >> actuator.log 2>&1 &
}
function setUnpause {
	echo [`date +%s`] restore vm=$1 >&8
	ssh $1 sudo service mysql start >> actuator.log 2>&1 &
	ssh $1 sudo service apache2 start >> actuator.log 2>&1 &
}
function cleanup {
	echo "*** Cleanup ***"
#	killall -w curl || true
	killall -w httpmon  || true
	killall -w lighttpd || true
#	killall -w ssh || true
#	killall -w tee || true
#	for vm in $vms; do
#		ssh $vm sudo killall -w -9 apache2 || true
#		ssh $vm 'sudo ipcs -s | grep "^0x" | cut -f2 -d" " | sudo xargs --max-args 1 --no-run-if-empty ipcrm -s'
#		ssh $vm sudo service mysql stop || true
#		ssh $vm "killall -w python || true"
#	done

#	docker kill $(docker ps -q)
	rm -f *.fifo
	rm -f *.csv *.log
}

#
# Main
#
echo "Main"
# Die on any error
set -e

# Parse command-line
usage() {
	echo "Usage: $0 [-a <algorithm>] [-s <scenario_file>]" >&2
	echo "where algorithm is 'brownout-diff', 'brownout-equal' or 'sqf'" >&2
	exit 1
}

while getopts "a:s:" o; do
	case "${o}" in
		a)
			algo=${OPTARG}
			;;
		s)
			scenario=${OPTARG}
			;;
		*)
			usage
			;;
	esac
done
shift $((OPTIND-1))

# Resolve relative paths
#httpmon=`readlink -f $httpmon`
#lighttpd=`readlink -f $lighttpd`
#lighttpd_dir=`readlink -f $lighttpd_dir`
#lighttpd_conf="$realexps_dir/lighttpd-$algo.conf"
#realexps_dir=`readlink -f $realexps_dir`

# Checks
if [ ! -e $lighttpd_conf ]; then
	echo "Cannot find lighttpd config: $lighttpd_conf" >&2
	exit 1
fi
if [ ! -e $scenario ]; then
	echo "Cannot find scenario file: $scenario" >&2
	exit 1
fi

#
# Cleanup
#

cleanup

#
# Startup
#
echo "*** Starting everything ***"

# start web servers and replica controllers
#for vm in $vms; do
#	ssh $vm sudo service mysql start
#	ssh $vm sudo service apache2 start
#	ssh $vm ./rubis/PHP/localController.py > exp-$vm.csv 2> exp-$vm.log &
#done

docker run  -d ens08jog/brownout:brownout-rubis-0.8
docker run  -d ens08jog/brownout:brownout-rubis-0.8
docker run  -d ens08jog/brownout:brownout-rubis-0.8
docker run  -d ens08jog/brownout:brownout-rubis-0.8
docker run  -d ens08jog/brownout:brownout-rubis-0.8
docker run  -d ens08jog/brownout:brownout-rubis-0.8


# load-balancer
docker run \
-v /home/jonas/brownout/experiments:/brownout-lb-lighttpd/config \
ens08jog/brownout:brownout-lb-lighttpd-0.2 \
-Df /brownout-lb-lighttpd/config/lighttpd-brownout-diff.conf \
-m /brownout-lb-lighttpd/src/.libs/ \
2> exp-lb.csv >&2 &


#$lighttpd -Df $lighttpd_conf -m $lighttpd_dir/.libs/ 2> exp-lb.csv >&2 &

# start (but do not activate) http client
mkfifo httpmon.fifo
#$httpmon --url $url --concurrency 0 --timeout 30 --deterministic --dump < httpmon.fifo &> httpmon.log &

docker run -i ens08jog/brownout:httpmon-0.2 --url $url --concurrency 0 --timeout 30 --deterministic --dump < httpmon.fifo &> httpmon.log &

#docker run -d ens08jog/brownout:httpmon-0.2 --url $url --concurrency 0 --timeout 30 --deterministic --dump 


exec 9> httpmon.fifo

# open log for experiment
mkfifo exp.fifo
tee exp.log < exp.fifo &
expLogPid=$!
exec 8> exp.fifo

# output starting parameters
( set -o posix ; set ) > params.log # XXX: perhaps too exhaustive
#git log -1 > version.log

#
# Protocol
#
. $scenario

# Gather post-experiment data
#for vm in $vms; do
#	ssh $vm 'ps -AFH' > ps-$vm.log
#done

# Stop experiment to make sure result files do not change
#killall -w curl || true
killall -w httpmon  || true
killall -w lighttpd || true
#killall -w ssh || true
#killall -w tee || true

#
# Send email to user
#
numRequests=`tail -1 exp-lb.csv | cut -d, -f22`
numRequestsWithOptional=`tail -1 exp-lb.csv | cut -d, -f23`
lastLinesOfHttpmon=`tail httpmon.log`

#echo "*** Sending results ***"
#mutt -s "LBB results: $algo $numRequestsWithOptional/$numRequests" -a *.csv *.log -- cristian.klein@cs.umu.se <<EOM
#Algo: $algo
#Requests: $numRequests
#Requests w/ optional: $numRequestsWithOptional
#Last lines of httpmon:
#$lastLinesOfHttpmon
#EOM

echo "*** Storing results ***"
OUTPUTFILE=`date +%Y%m%dT%H%M%S`.tgz
tar -czvf $OUTPUTFILE *.csv *.log

#
# Cleanup
#
cleanup

