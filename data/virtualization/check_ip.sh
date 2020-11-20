#!/bin/bash

set -euo pipefail

ret=0
echo "${BOX_IP}"|grep -q ':' || ret=$?

if [[ $ret -eq 0 ]]; then
    INET="inet6 "
    LOCALHOST='\:\:1\/128'
else
    INET="inet "
    LOCALHOST='127\.0\.0\.1'
fi

IPS=$(ip addr|grep "${INET}"|awk '{print $2}'|sed "/${LOCALHOST}/d"|sed 's/\/.*//')

correct_ip=1

for ip in ${IPS}; do
    if [[ "${ip}" = "${BOX_IP}" ]]; then
        correct_ip=0
    fi
done

exit $correct_ip
