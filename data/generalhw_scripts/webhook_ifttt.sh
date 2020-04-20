#!/bin/sh
# You need to create:
#   a webhook key at https://ifttt.com/maker_webhooks
#   the applet itself on https://ifttt.com/create
# Package dep: curl
# TODO: Handle option values named: value1, value2, value3, in json format: { "value1" : "", "value2" : "", "value3" : "" }

# Do not echo, to not leak private event/key in log
set -e

echo "IFTTT webhook"

# Check number of args
if [ "$#" -ne 2 ]; then
    echo "Please provide <event_name> and <private_key> as arguments. (Optionnal values are not yet supported)"
    exit 1;
fi

# Get args
ifttt_event=$1
ifttt_key=$2

curl -X POST https://maker.ifttt.com/trigger/$ifttt_event/with/key/$ifttt_key
