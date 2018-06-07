# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash


########################################################
###
### This function start Unicast-PINGs in a LOOP and send the output to a local logfile
###
### $1 : Ifname of the outgoing interface
### $2 : Ping IP-Adress - IPv6
### $3 : Start Loop
### $4 : End Loop (Iteration = $END - $START)
### $5 : Name of the LOG and PID
### $6 : Options (-f for floodping or -s 65507 for packetsize)
###    Remark: '-c' is already defined with $i of the loop
### $7 : RemoteHost (start ping via SSH from another host) - optional -
###    Remark: $SSH = the command to use for ssh
###
### Example:
###
### net_uping6  $1       $2      $3      $4    $5         $6                 $7
### net_uping6  $sE1     $sE1ip  "1"     "10"  "40b_c2s"  "-f -s 65507 ..."  $cHOST
### net_uping6  $IFNAME  $IP     $START  $END  $LOGNAME   $OPTION            $REMOTE
###

net_uping6(){
 local IFNAME="$1"
 local IP="$2"
 local START="$3"
 local END="$4"
 local LOGNAME="$5"
 local OPTION="${6}"
 local REMOTE="${7}"
 local XMOTE=""
 local MYPID=""
 local RET=""
 local i=""
 local xDATE=""
 local SSH=${SSH:-"ssh -i /root/.ssh/id_dsa.autotest -o StrictHostKeyChecking=no -oProtocol=2 -q -n -oBatchMode=yes "}

if [ -z "$REMOTE" ];then
 echo "--->>>>>>>>>> Local PING <<<<<<<<<<---"
 XMOTE=""
else
 echo "<<<<<<<<<<=== Remote PING ===>>>>>>>>>>"
 XMOTE="$SSH $REMOTE "
fi

 echo
 #$XMOTE ifconfig $IFNAME
 $XMOTE ip addr show $IFNAME
 echo

for (( i = $START; i <= $END; i++ ))      ### Loop ###
 do
  echo
  echo '<<<<<<<<<< Loop-No.: ' $i ' >>>>>>>>>>>'
  echo
  echo '>->-> IPv6: Unicast PING <-<-<'
  echo
  xDATE=`date +%F_%T`
  echo $xDATE
  $XMOTE ping6 -I $IFNAME $IP -c 3        ### wake up ###
  echo
  (
   $XMOTE ping6 -I $IFNAME $IP -c $i $OPTION  >  $xDATE-$LOGNAME-uping6-$i.log  2>&1
   head -n1 $xDATE-$LOGNAME-uping6-$i.log && echo "[...]" &&  tail -n3 $xDATE-$LOGNAME-uping6-$i.log
  ) &
   MYPID=$!
   wait $MYPID
   RET=$?
   echo $MYPID > $xDATE-$LOGNAME-uping6-$i.PID
  sleep 1
   cat $xDATE-$LOGNAME-uping6-$i.log | grep ' 0% packet loss'
   assert_warn $? 0 "$xDATE-$LOGNAME-uping6-$i.log: no packet loss!"
  echo
  echo
  echo " >->-> End of Loop <-<-<"
  echo
done

 echo
 #$XMOTE ifconfig $IFNAME
 $XMOTE ip addr show $IFNAME
 echo
}



########################################################
###
### This function start Unicast-PINGs in a LOOP and send the output to a local logfile
###
### $1 : Ifname of the outgoing interface
### $2 : Ping IP-Adress
### $3 : Start Loop
### $4 : End Loop (Iteration = $END - $START)
### $5 : Name of the LOG and PID
### $6 : Options (-f for floodping or -s 65507 for packetsize)
###    Remark: '-c' is already defined with $i of the loop
### $7 : RemoteHost (start ping via SSH from another host) - optional -
###    Remark: $SSH = the command to use for ssh
###
### Example:
###
### net_uping   $1       $2      $3      $4    $5         $6                 $7
### net_uping   $sE1     $sE1ip  "1"     "10"  "40b_c2s"  "-f -s 65507 ..."  $cHOST
### net_uping   $IFNAME  $IP     $START  $END  $LOGNAME   $OPTION            $REMOTE
###

net_uping(){
 local IFNAME="$1"
 local IP="$2"
 local START="$3"
 local END="$4"
 local LOGNAME="$5"
 local OPTION="${6}"
 local REMOTE="${7}"
 local XMOTE=""
 local MYPID=""
 local RET=""
 local i=""
 local xDATE=""
 local SSH=${SSH:-"ssh -i /root/.ssh/id_dsa.autotest -o StrictHostKeyChecking=no -oProtocol=2 -q -n -oBatchMode=yes "}

if [ -z "$REMOTE" ];then
 echo "--->>>>>>>>>> Local PING <<<<<<<<<<---"
 XMOTE=""
else
 echo "<<<<<<<<<<=== Remote PING ===>>>>>>>>>>"
 XMOTE="$SSH $REMOTE "
fi

 echo
 #$XMOTE ifconfig $IFNAME
 $XMOTE ip addr show $IFNAME
 echo

for (( i = $START; i <= $END; i++ ))      ### Loop ###
 do
  echo
  echo '<<<<<<<<<< Loop-No.: ' $i ' >>>>>>>>>>>'
  echo
  echo '>->-> IPv4: Unicast PING <-<-<'
  echo
  xDATE=`date +%F_%T`
  echo $xDATE
  $XMOTE ping $IP -c 3                    ### wake up ###
  echo
  (
   $XMOTE ping $IP -c $i $OPTION  >  $xDATE-$LOGNAME-uping-$i.log  2>&1
   head -n1 $xDATE-$LOGNAME-uping-$i.log && echo "[...]" &&  tail -n3 $xDATE-$LOGNAME-uping-$i.log
  ) &
   MYPID=$!
   wait $MYPID
   RET=$?
   echo $MYPID > $xDATE-$LOGNAME-uping-$i.PID
  sleep 1
   cat $xDATE-$LOGNAME-uping-$i.log | grep ' 0% packet loss'
   assert_warn $? 0 "$xDATE-$LOGNAME-uping-$i.log: no packet loss!"
  echo
  echo
  echo " >->-> End of Loop <-<-<"
  echo
done

 echo
 #$XMOTE ifconfig $IFNAME
 $XMOTE ip addr show $IFNAME
 echo
}
