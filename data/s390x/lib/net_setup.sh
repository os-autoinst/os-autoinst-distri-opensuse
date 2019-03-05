# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

########################################################
###
### This function attaches DEVNOs to the VM-guest
###
### $1 : DEVNO-list which should be attached to the vm-guest
###
### Example:
###
### net_att_devno_vm $1
### net_att_devno_vm "$cE1a $cE1b $cE1c"
### net_att_devno_vm "0.0.e000 0.0.e001 0.0.e002"
###

net_att_devno_vm(){
 local DEFAULT3="$1"

 load_vmcp

 echo
 vmcp 'q v osa'
 echo

 echo "DEVICEs which will be attached: $DEFAULT3"

 for i in $DEFAULT3
 do
    j="$(echo $i | sed 's/0\..\.//' )"
    echo "Attach DEVICE $j"
    vmcp "att $j *"
    sleep 1
 done

 echo
 vmcp 'q v osa'
 echo

 echo "Waiting for new attachements (1 sec.)"
 sleep 1
}

########################################################
###
### This function group 3 DEVNOs to a new qdio-interface
###
### $1 : 1st DEVNO of the LAN interface
### $2 : 2nd DEVNO of the LAN interface
### $3 : 3rd DEVNO of the LAN interface
### $4 : Layer 2 or 3 [1/0]
### $5 : Portno [0/1] only valid for 1GbE-OSA-Express3
### $6 : CHPID
###
### Example:
###
### net_group_linux $1         $2         $3         $4      $5		$6
### net_group_linux $cE1a      $cE1b      $cE1c      $cP1Lay $cP1No	$cE1Chp
### net_group_linux "0.0.f200" "0.0.f201" "0.0.f202" "0"     "0"	85
###

net_group_linux(){
 local P0="/sys/bus/ccwgroup/drivers/qeth"
 local P1="/sys/bus/ccwgroup/drivers/qeth/group"
 local LANa="$1"
 local LANb="$2"
 local LANc="$3"
 local LAYER="$4"
 local PORTNO="$5"
 local CHPID="$6"

 echo "Network devices before configuration";
 lsqeth -p
 echo

 echo
 echo "Set CHPID ON ..."
 echo chchp -c 1 $CHPID
 echo chchp -v 1 $CHPID
 echo

 echo "Configure device"
 printf "%-20s : %s\n" "Group device nodes" "$LANa,$LANb,$LANc";
 printf "intoooooo %s\n" "${P1}"
 echo "$LANa,$LANb,$LANc" > "${P1}" || return 1;
 printf "%-20s : %s\n" "Set network layer" "${LAYER}";
 echo "$LAYER" > "${P0}/${LANa}/layer2" || return 1;

 echo
 CardType="$( cat /sys/bus/ccwgroup/drivers/qeth/$LANa/card_type )"
 printf "%-20s : %s\n" "Set port number" "${PORTNO}";
 if [ "HiperSockets" = "$CardType" ];then
  echo "CardType=$CardType -- HiperSocket-Device has no port-number => nothing todo"
 else
  echo "CardType=$CardType -- OSA-Device => set port-number"
  echo "$PORTNO" > "${P0}/${LANa}/portno" || return 1;
 fi
 echo

 echo "Set device online '${P0}/${LANa}'"
 echo 1 > "${P0}/${LANa}/online" || return 1;
 echo

 echo "Network devices after configuration";
 lsqeth -p
 echo

 return 0;
}





########################################################
###
### This function remove all network interfaces except LAN eth0
###
### $1 : 1st DEVNO of the LAN interface which not to be delete
###
### Example with LAN-Device=0.0.f500,0.0.f501,0.0.f502:
###
### net_cleanup_linux $1
### net_cleanup_linux "$sLANa"
### net_cleanup_linux "0.0.f500"
###

net_cleanup_linux(){
 local P0="/sys/bus/ccwgroup/drivers/qeth/"
 local LAN="$1"
 local IFNAME=""
 local G1=""

 echo
 lsqeth -p
 echo

 DEFAULT1="$(ls -1 $P0 |grep 0. |grep -v $LAN )"
 echo "DEVICEs which will be delete: $DEFAULT1"

 for i in $DEFAULT1
 do
    IFNAME="$(cat /sys/bus/ccwgroup/drivers/qeth/$i/if_name)"
    echo "Delete interface $IFNAME with DEVICE $i"
    echo 0 > $P0$i/online
    echo 1 > $P0$i/ungroup
 done

 echo
 lsqeth -p
 echo

# LCS CleanUp:

 local P1="/sys/bus/ccwgroup/drivers/lcs/"

 DEFAULT2="$(ls -1 $P1 |grep 0. |grep -v $LAN )"

 if [ -z "$DEFAULT2" ]; then
  echo
  echo "No LCS Device"
  echo
  return
 else
  for j in $DEFAULT2
   do
    IFNAME="$(ls /sys/bus/ccwgroup/drivers/lcs/$j/net)"
    echo "Delete interface $IFNAME with DEVICE $j"
    echo 0 > $P1$j/online
    echo 1 > $P1$j/ungroup
   done
 echo "Waiting for Linux-cleanup (1 sec.)"
 sleep 1
 fi
}

########################################################
###
### This function remove all network interfaces expect LAN eth0
###
### $1 : DEVNOs of the LAN interface which not to be delete
###
### Example with LAN-Device=0.0.f5f0,0.0.f5f1,0.0.f5f2:
###
### net_cleanup_vm $1
### net_cleanup_vm "$cLANa $cLANb $cLANc"
### net_cleanup_vm "0.0.F5F0 0.0.F5F1 0.0.F5F2"
###

net_cleanup_vm(){
 local LAN="$1"
 local DEFAULT2=""

 load_vmcp

 LAN="$(echo ${LAN} | tr 'a-z' 'A-Z')"
 echo "Used LAN interfaces: $LAN"

 DEFAULT2="$( vmcp -b 20000 'q v osa' | awk '/^OSA ..* ON/{print $2}' )"
 echo "The following devices are attached at the moment: "$DEFAULT2

 for i in $LAN
  do LAN="$(echo $i | sed 's/0\..\.//' )"
     DEFAULT2="$(echo $DEFAULT2|sed s/$LAN//)"
  done

 echo "The following devices will be detached now: "$DEFAULT2

 for i in $DEFAULT2
 do
    echo "Delete DEVICE $i"
    vmcp "det $i"
    sleep 1
 done

 echo
 vmcp 'q v osa'
 echo

 echo "Waiting for VM-cleanup (1 sec.)"
 sleep 1
}
