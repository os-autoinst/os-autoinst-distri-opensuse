# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash


####################################################
###
### This function set a VLAN interface
###
### $1 : Name of the LOG and PID
### $2 : Name of the base interface
### $3 : VLAN-ID
### $4 : IP-adress of the new VLAN-interface
### $5 : Netmask of the new VLAN-interface
### $6 : Broadcast-adress of the new VLAN-interface
###
### Example:
###
### net_vlan_up_ip "$1"       "$2"      "$3"      "$4"            "$5"          "$6"
### net_vlan_up_ip "$LOGNAME" "$IFNAME" "$VLANID" "$IP"           "$PREFIX"     "$BROAD"
### net_vlan_up_ip "31c"      "bond1"   "200"     "10.200.43.100" "16" "10.200.255.255"
###

net_vlan_up_ip(){
 local LOGNAME="$1"
 local IFNAME="$2"
 local VLANID="$3"
 local IP="$4"
 local MASK="$5"
 local BROAD="$6"
 local xDATE=""
 local NEW="$IFNAME.$VLANID"

 echo
 echo "<<< NEW-VLAN-Interface: $NEW >>>"
 echo
 echo
 xDATE=`date +%F_%T`
 echo $xDATE

 echo
 vconfig add $IFNAME $VLANID >  $xDATE-$LOGNAME.log  2>&1
 assert_warn $? 0 "Set VLAN ok?"
 echo
 cat /proc/net/vlan/config >  $xDATE-$LOGNAME.log  2>&1
 echo
 cat /proc/net/vlan/$NEW >  $xDATE-$LOGNAME.log  2>&1
 echo
 # ifconfig $NEW >   $xDATE-$LOGNAME.log  2>&1
 ip addr show $NEW  > $xDATE-$LOGNAME.log  2>&1
 local ip_addr="$IP/$MASK"

 ip addr add $ip_addr dev $NEW > $xDATE-$LOGNAME.log  2>&1
  sleep 1
 ip link set dev $NEW up > $xDATE-$LOGNAME.log  2>&1

 echo
# ifconfig $NEW $IP netmask $MASK broadcast $BROAD >  $xDATE-$LOGNAME.log  2>&1
 ip addr show $NEW  > $xDATE-$LOGNAME.log  2>&1
 echo
# ifconfig $NEW >  $xDATE-$LOGNAME.log  2>&1
 echo
 cat /proc/net/vlan/config >  $xDATE-$LOGNAME.log  2>&1
 echo
 cat /proc/net/vlan/$NEW >  $xDATE-$LOGNAME.log  2>&1
 echo
 cat  $xDATE-$LOGNAME.log
 echo

}



########################################################
###
### This function set a VLAN interface
###
### $1 : Name of the LOG and PID
### $2 : Name of the base interface
### $3 : VLAN-ID
### $4 : IP-adress of the new VLAN-interface
### $5 : Netmask of the new VLAN-interface
### $6 : Broadcast-adress of the new VLAN-interface
### $7 : New VLAN-interface-name
###
### Example:
###
### net_vlan_up "$1"       "$2"      "$3"      "$4"            "$5"          "$6"             "$7"
### net_vlan_up "$LOGNAME" "$IFNAME" "$VLANID" "$IP"           "$MASK"       "$BROAD"         "$VLANNAME"
### net_vlan_up "31c"      "bond1"   "200"     "10.200.43.100" "255.255.0.0" "10.200.255.255" "VLAN100"
###

net_vlan_up(){
 local LOGNAME="$1"
 local IFNAME="$2"
 local VLANID="$3"
 local IP="$4"
 local MASK="$5"
 local BROAD="$6"
 local VLANNAME="$7"
 local xDATE=""
 local NEW="$VLANNAME"

 echo
 echo "<<< NEW-VLAN-Interface: $NEW >>>"
 echo
 echo
 xDATE=`date +%F_%T`
 echo $xDATE

 echo
 #vconfig add $IFNAME $VLANID >  $xDATE-$LOGNAME.log  2>&1
 ip link add dev $IFNAME.$VLANID link $IFNAME name $VLANNAME type vlan id $VLANID > $xDATE-$LOGNAME.log  2>&1
 assert_warn $? 0 "Set VLAN ok?"
 echo
 cat /proc/net/vlan/config >  $xDATE-$LOGNAME.log  2>&1
 echo
 cat /proc/net/vlan/$NEW >  $xDATE-$LOGNAME.log  2>&1
 echo
 #ifconfig $NEW >   $xDATE-$LOGNAME.log  2>&1
 ip addr show $NEW >   $xDATE-$LOGNAME.log  2>&1
 echo
 #ifconfig $NEW $IP netmask $MASK broadcast $BROAD >  $xDATE-$LOGNAME.log  2>&1
 local ip_addr="$IP/$MASK"
 ip addr add $ip_addr brd + dev $NEW > $xDATE-$LOGNAME.log  2>&1
 ip link set dev $NEW up > $xDATE-$LOGNAME.log  2>&1
 echo
 #ifconfig $NEW >  $xDATE-$LOGNAME.log  2>&1
 ip addr show $NEW >  $xDATE-$LOGNAME.log  2>&1
 echo
 cat /proc/net/vlan/config >  $xDATE-$LOGNAME.log  2>&1
 echo
 cat /proc/net/vlan/$NEW >  $xDATE-$LOGNAME.log  2>&1
 echo
 cat  $xDATE-$LOGNAME.log
 echo

}
