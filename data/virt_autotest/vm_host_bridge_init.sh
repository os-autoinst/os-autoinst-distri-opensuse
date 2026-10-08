#!/bin/bash

BRIDGE_INF=$1
. /etc/os-release
ACTIVE_NET=$(ip a|awk -F': ' '/state UP/ {print $2}'|head -n1)
interface="BOOTPROTO='none'\nSTARTMODE='auto'"
bridge="BOOTPROTO='dhcp'\nBRIDGE='yes'\nBRIDGE_FORWARDDELAY='0'\nBRIDGE_PORTS='$ACTIVE_NET'\nBRIDGE_STP='off'\nSTARTMODE='auto'"
> /etc/sysconfig/network/ifcfg-$BRIDGE_INF.new
echo -e $bridge >/etc/sysconfig/network/ifcfg-$BRIDGE_INF
echo -e $interface >/etc/sysconfig/network/ifcfg-$ACTIVE_NET
cat /etc/sysconfig/network/ifcfg-$BRIDGE_INF
cat /etc/sysconfig/network/ifcfg-$ACTIVE_NET
if [[ $VERSION_ID =~ '11' ]]; then
    service network restart
else
    systemctl restart network
fi
