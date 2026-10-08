#!/bin/bash

BRIDGE_INF=$1
. /etc/os-release
ACTIVE_NET=$(ip a|awk -F': ' '/state UP/ {print $2}'|head -n1)
interface="BOOTPROTO='dhcp'\nSTARTMODE='auto'"
echo -e $interface >/etc/sysconfig/network/ifcfg-$ACTIVE_NET
cat /etc/sysconfig/network/ifcfg-$ACTIVE_NET
rm -rf /etc/sysconfig/network/ifcfg-$BRIDGE_INF*
if [[ $VERSION_ID =~ '11' ]]; then
    service network restart
else
    systemctl restart network.service
fi
