#!/bin/sh
# Package dep: nodejs-common
# Also install codetheweb/tuyapi - npm install -g codetheweb/tuyapi (no rpm package yet)

# Do not echo, to not leak ID and key in the log
set -e

echo "Powering ON/OFF"

# Check number of args
if [ "$#" -ne 4 ]; then
    echo "Please provide tuya <ID>, tuya <key>, <index> of the plug to power on/off, <state> (on/off) as arguments"
    exit 1;
fi

# Get infos
tuya_ID=$1
tuya_key=$2
tuya_index=$3
tuya_state=$4

# Run JS script
node $(dirname $0)/tuya_sync.js $tuya_ID $tuya_key $tuya_index $tuya_state
