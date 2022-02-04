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

res=$(curl -s "http://${shelly_ip}/relay/0?turn=${state}")
if ! echo "$res" | grep -q "ison" ; then
	exit 1
fi
