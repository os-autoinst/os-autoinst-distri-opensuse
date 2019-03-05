# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

#!/bin/bash

source lib/auxx.sh || exit 1
source lib/env.sh || exit 1
source lib/dasd.sh || exit 1
source lib/dasd_1.sh || exit 1
source lib/net_setup.sh || exit 1
source lib/net_ifup.sh || exit 1
source lib/net_ping.sh || exit 1
source lib/net_vlan.sh || exit 1
source ./00_config-file_TOOL_s390_qetharp || exit 1

CLEANUPTESTCASE_PROCEDURE="cleanup"

###########################################################################################
cleanup(){
 true;
}

###########################################################################################
# procedure for setting up this testcase

setup_testcase(){

   echo "(INIT) Check preconditions"
   $CLEANUPTESTCASE_PROCEDURE

   # Set ifname to $sE1 (SERVER):
     sE1="$(cat /sys/bus/ccwgroup/drivers/qeth/$sE1a/if_name)"
     echo "sE1 = $sE1"
     assert_warn $? 0 "NULL"

   # Set ifname to $sE2 (SERVER):
     sE2="$(cat /sys/bus/ccwgroup/drivers/qeth/$sE2a/if_name)"
     echo "sE2 = $sE2"
     assert_warn $? 0 "NULL"

   # Set ifname to $sE3 (SERVER):
     sE3="$(cat /sys/bus/ccwgroup/drivers/qeth/$sE3a/if_name)"
     echo "sE3 = $sE3"
     assert_warn $? 0 "NULL"


   dmesg -c &> /dev/null
}

###########################################################################################
part_a(){
   echo "(a) PING from Server to client <Real OSA : ipv4>"

   ### net_uping   $1       $2      $3      $4    $5         $6                 $7
   ### net_uping   $sE1     $sE1ip  "1"     "10"  "40b_c2s"  "-f -s 65507 ..."  $cHOST
   ### net_uping   $IFNAME  $IP     $START  $END  $LOGNAME   $OPTION            $REMOTE
   net_uping  $sE1      $cE1ip "$x40SaSTART" "$x40SaEND" "40a_s2c" "$x40SaOPTION"
   sleep 5

   dmesg -c &> /dev/null
}



###########################################################################################

part_b(){
   echo "(b) PING from Server to client <Real HSI : ipv4>"

   ### net_uping   $1       $2      $3      $4    $5         $6                 $7
   ### net_uping   $sE1     $sE1ip  "1"     "10"  "40b_c2s"  "-f -s 65507 ..."  $cHOST
   ### net_uping   $IFNAME  $IP     $START  $END  $LOGNAME   $OPTION            $REMOTE
   net_uping  $sE2      $cE2ip "$x40SbSTART" "$x40SbEND" "40b_s2c" "$x40SbOPTION"
   sleep 5

   dmesg -c &> /dev/null
}


###########################################################################################
part_c(){
   echo "(c) PING from Server to client <Real HSI : ipv6>"

   ### net_uping6   $sE1     $sE1ip   "1"            "10"         "31b_c2s"  "-f -s 65507 ..."  $cHOST
   ### net_uping6   $IFNAME  $IP          $START         $END         $LOGNAME   $OPTION            $REMOTE
   #net_uping6       $sE3     $cE3ip6   "$x40ScSTART"  "$x40ScEND"  "40c_s2c"  "$x40ScOPTION" $cHOST
   net_uping6       $sE3     $cE3ip6   "$x40ScSTART"  "$x40ScEND"  "40c_s2c"  "$x40ScOPTION"
   sleep 5


   dmesg -c &> /dev/null
}

###########################################################################################
part_x(){
  echo "(x) tbd"

   # tbd ...

   dmesg -c &> /dev/null
}

######################################################################################
###
### MAIN

# default testcases
# TESTCASES="a" ./<name of script>
# only executes testcase in "part_a"
#
#TESTCASES="${TESTCASES:-a b}"
TESTCASES="${TESTCASES:-$x40STEST}"


echo "START: $0"
init_tests
setup_testcase

echo "Executing the testscript ($0) with the following sections: $TESTCASES"
echo
echo "Run dedicated testcases with TESTCASE = $0"

for i in $TESTCASES;
do
   echo
   dmesg -c &> /dev/null
   part_$i
   echo
done

show_test_results

#
#
#
# - - - - - - - - - - - - - - - - - - - - -
#      <<<<<<<<<< ENTE >>>>>>>>>>
# - - - - - - - - - - - - - - - - - - - - -
#
# vim: ai et ts=2 shiftwidth=2 expandtab tabstop=3 bg=dark
