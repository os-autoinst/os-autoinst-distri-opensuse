#!/bin/bash

# This script can operate shelly wifi switch plugs
# See https://shelly-api-docs.shelly.cloud/gen1/#shelly-plug-plugs-relay-0

# Check number of args
if [ "$#" -ne 2 ] ; then
	echo "Invalid number of arguments."
	echo "Usage: $0 IP/HOSTNAME on|off"
	exit 1
fi

shelly_ip=$1
state=$2

echo "$0: Setting shelly $shelly_ip output $state"
res=$(curl -s "http://${shelly_ip}/relay/0?turn=${state}")
if ! echo "$res" | grep -q "ison" ; then
	exit 1
fi
test "$state" == "on" && expected_ison="true"
test "$state" == "off" && expected_ison="false"
result_ison=$(echo "$res" | jq -c .ison)
if [ "$result_ison" != "$expected_ison" ] ; then
	echo "Error: $0 expected state $expected_ison but got $result_ison"
	exit 1
fi
