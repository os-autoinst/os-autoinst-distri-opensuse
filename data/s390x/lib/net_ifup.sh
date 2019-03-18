# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash


########################################################
###
### Setup new interface
###
### $1 : 1st DEVNO of the new interface
### $2 : IP-Adress [10.x.x.x]
### $3 : Netmask [255.255.0.0]
### $4 : Broadcast [10.x.255.255]
### $5 : MacAdress [02:40:01:87:08:15] - optional -
###
### Example:
###
### net_ifup_linux $1     $2         $3            $4             $5
### net_ifup_linux $cE1a  $cE1ip     $cE1mask      $cE1broad      $cE1mac
### net_ifup_linux "f600" "10.1.1.1" "255.255.0.0" "10.1.255.255" "02:50:03:87:08:15"
###

net_ifup_linux(){

 local P0="/sys/bus/ccwgroup/drivers/qeth/"
 local P1="/sys/bus/ccwgroup/drivers/qeth/group"
 local LANa="$1"
 local IP="$2"
 local MASK="$3"
 local BROAD="$4"
 local MAC="$5"
 local IFNAME=""
 local LAYER2=""

IFNAME="$(cat /sys/bus/ccwgroup/drivers/qeth/$LANa/if_name)"
if [ "" = "$IFNAME" ]; then
  echo
  echo "ERROR: <<< Interface with DEVNO $LANa not operational >>>"
  echo
  return
else
  echo
  echo "Interface with DEVNO $LANa ok"
  echo
fi

LAYER2="$(cat /sys/bus/ccwgroup/drivers/qeth/$LANa/layer2)"
if [ "1" = "$LAYER2" ]; then
  echo
  echo "Layer2 interface"
  echo
  #ifconfig $IFNAME hw ether $MAC
  ip link set $IFNAME address $MAC
  ip link set $IFNAME up
  echo
else
  echo
  echo "Layer3 interface"
  echo
fi

echo "Set IP-Adr"
echo
#ifconfig $IFNAME $IP netmask $MASK broadcast $BROAD
local ip_addr="$IP/$MASK"
ip addr add $ip_addr brd + dev $IFNAME
ip link set dev $IFNAME up

echo
#ifconfig $IFNAME
ip addr show $IFNAME
echo
}


########################################################
###
### Setup new interface
###
### $1 : 1st DEVNO of the new interface
### $2 : IP-Adress [10.x.x.x]
### $3 : Netmask [255.255.0.0]
### $4 : Broadcast [10.x.255.255]
### $5 : MacAdress [02:40:01:87:08:15] - optional -
###
### Example:
###
### net_ifup_linux_ip $1     $2         $3            $4             $5
### net_ifup_linux_ip $cE1a  $cE1ip     $cE1pref      $cE1broad      $cE1mac
### net_ifup_linux_ip "f600" "10.1.1.1" "16" "10.1.255.255" "02:50:03:87:08:15"
###

net_ifup_linux_ip(){

 local P0="/sys/bus/ccwgroup/drivers/qeth/"
 local P1="/sys/bus/ccwgroup/drivers/qeth/group"
 local LANa="$1"
 local IP="$2"
 local MASK="$3"
 local BROAD="$4"
 local MAC="$5"
 local IFNAME=""
 local LAYER2=""

IFNAME="$(cat /sys/bus/ccwgroup/drivers/qeth/$LANa/if_name)"
if [ "" = "$IFNAME" ]; then
  echo
  echo "ERROR: <<< Interface with DEVNO $LANa not operational >>>"
  echo
  return
else
  echo
  echo "Interface with DEVNO $LANa ok"
  echo
fi

LAYER2="$(cat /sys/bus/ccwgroup/drivers/qeth/$LANa/layer2)"
if [ "1" = "$LAYER2" ]; then
  echo
  echo "Layer2 interface"
  echo
  #ifconfig $IFNAME hw ether $MAC
  ip link set $IFNAME address $MAC
  sleep 1
  ip link set $IFNAME up
  echo
else
  echo
  echo "Layer3 interface"
  echo
fi

echo "Set IP-Adr"
echo
local ip_addr="$IP/$MASK"
#ifconfig $IFNAME $IP netmask $MASK broadcast $BROAD
ip addr add $ip_addr dev $IFNAME
  sleep 1
ip link set dev $IFNAME up
echo
#ifconfig $IFNAME
ip addr show $IFNAME
echo

}


net_ifup_linux_ip6(){

    local P0="/sys/bus/ccwgroup/drivers/qeth/"
    local P1="/sys/bus/ccwgroup/drivers/qeth/group"
    local LANa="$1"
    local IP="$2"
    local MASK="$3"
    local BROAD="$4"
    local MAC="$5"
    local IFNAME=""
    local LAYER2=""

    IFNAME="$(cat /sys/bus/ccwgroup/drivers/qeth/$LANa/if_name)"
    if [ "" = "$IFNAME" ]; then
      echo
      echo "ERROR: <<< Interface with DEVNO $LANa not operational >>>"
      echo
      return
    else
      echo
      echo "Interface with DEVNO $LANa ok"
      echo
    fi

    LAYER2="$(cat /sys/bus/ccwgroup/drivers/qeth/$LANa/layer2)"
    if [ "1" = "$LAYER2" ]; then
      echo
      echo "Layer2 interface"
      echo
      #ifconfig $IFNAME hw ether $MAC
      ip link set $IFNAME address $MAC
      sleep 1
      ip link set $IFNAME up
      echo
    else
      echo
      echo "Layer3 interface"
      echo
    fi

    echo "Set IP-Adr"
    echo
    local ip_addr="$IP/$MASK"
    #ifconfig $IFNAME $IP netmask $MASK broadcast $BROAD
    ip -6 addr add $ip_addr dev $IFNAME
      sleep 1
    ip link set dev $IFNAME up
    echo
    #ifconfig $IFNAME
    ip addr show $IFNAME
    echo
}
