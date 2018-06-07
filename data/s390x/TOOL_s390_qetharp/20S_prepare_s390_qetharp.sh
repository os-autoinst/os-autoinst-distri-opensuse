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

# the function which should be called for cleanups
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
   dmesg -c &> /dev/null
   assert_warn $? 0 "NULL"

}

###########################################################################################
part_a(){
   echo "(a) Allow Broadcast"

# - - - - - - - - - - - - - - - - - - - - -
# Enable Broadcast/Multicast
# - - - - - - - - - - - - - - - - - - - - -
   sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=0
   assert_warn $? 0 "Allow broadcast"

}

###########################################################################################
part_b(){
  echo "(b) Interface Defnition"

# - - - - - - - - - - - - - - - - - - - - -
# Define 1st interfaces: <Real OSA>
# - - - - - - - - - - - - - - - - - - - - -

echo "-------------------------------------------------"
echo " Define 1st interface:  <Real OSA> (Server side) "
echo "-------------------------------------------------"
echo

# START VM-Part (attach):
   isVM
   RET=$?

   if [ "0" = "$RET" ]; then
    echo
    echo "***** START VM-Part: 1st interface - Real OSA *****"
    echo
    net_att_devno_vm "$sE1a $sE1b $sE1c"
    assert_warn $? 0 "DEVNOs attached?"
    echo
    sleep 5
   else
    assert_warn $? 1 "Real OSA card cannot be attached as the system is LPAR"
   fi

# START LINUX-Part1 (group):
   echo
   echo "***** START LINUX-Part1 (group): 1st interface - Real OSA *****"
   echo
   net_group_linux $sE1a $sE1b $sE1c $sP1Lay $sP1No
   assert_warn $? 0 "New interface of type Real OSA defined?"
   echo
   sleep 5

# START LINUX-Part2 (ifup):
   echo
   echo "***** START LINUX-Part2 (ifup): 1st interface - Real OSA *****"
   echo

   isIfconfigOrIP
   RET=$?

   if [ $RET -eq 0 ]
   then
        net_ifup_linux $sE1a $sE1ip $sE1mask $sE1broad $sE1mac
        assert_warn $? 0 "Setup of new interface of type Real OSA done?"
        echo
   elif [ $RET -eq 1 ]
   then
      echo "ip"
      net_ifup_linux_ip $sE1a $sE1ip $sE1netpref $sE1broad $sE1mac
      assert_warn $? 0 "Setup of new interface done?"
   fi


# - - - - - - - - - - - - - - - - - - - - - - - -
# Define 2nd interface: <Real HSI : ipv4 address>
# - - - - - - - - - - - - - - - - - - - - - - - -

echo "----------------------------------------------------------------"
echo " Define 2nd interface: <Real HSI : ipv4 address>  (Server side) "
echo "----------------------------------------------------------------"
echo

# START VM-Part (attach):
   isVM
   RET=$?

   if [ "0" = "$RET" ]; then
    echo
    echo "***** START VM-Part: 2nd interface - Real HSI - ipv4 address *****"
    echo
    net_att_devno_vm "$sE2a $sE2b $sE2c"
    assert_warn $? 0 "DEVNOs attached?"
    echo
    sleep 5
   else
    assert_warn $? 1 "HSI card cannot be attached as the system is LPAR"
   fi

# START LINUX-Part1 (group):
   echo
   echo "***** START LINUX-Part1 (group): 2nd interface - Real HSI - ipv4 address *****"
   echo
   net_group_linux $sE2a $sE2b $sE2c $sP2Lay $sP2No
   assert_warn $? 0 "New interface of type HSI defined?"
   echo
   sleep 5

# START LINUX-Part2 (ifup):
   echo
   echo "***** START LINUX-Part2 (ifup): 2nd interface - Real HSI - ipv4 address *****"
   echo

   isIfconfigOrIP
   RET=$?

   if [ $RET -eq 0 ]
   then
        net_ifup_linux $sE2a $sE2ip $sE2mask $sE2broad $sE2mac
        assert_warn $? 0 "Setup of new interface of type HSI done?"
   elif [ $RET -eq 1 ]
   then
        echo "ip"
        net_ifup_linux_ip $sE2a $sE2ip $sE2netpref $sE2broad $sE2mac
        assert_warn $? 0 "Setup of new interface done?"
   fi

# - - - - - - - - - - - - - - - - - - - - - - - -
# Define 3rd interface: <Real HSI : ipv6 address>
# - - - - - - - - - - - - - - - - - - - - - - - -

echo "---------------------------------------------------------------"
echo " Define 3rd interface: <Real HSI : ipv6 address> (Server side) "
echo "---------------------------------------------------------------"
echo

# START VM-Part (attach):
   isVM
   RET=$?

   if [ "0" = "$RET" ]; then
    echo
    echo "***** START VM-Part: 3rd interface - Real HSI - ipv6 address *****"
    echo
    net_att_devno_vm "$sE3a $sE3b $sE3c"
    assert_warn $? 0 "DEVNOs attached?"
    echo
    sleep 5
   else
    assert_warn $? 1 "HSI card cannot be attached as the system is LPAR"
   fi

# START LINUX-Part1 (group):
   echo
   echo "***** START LINUX-Part1 (group): 3rd interface - Real HSI - ipv6 address *****"
   echo
   net_group_linux $sE3a $sE3b $sE3c $sP3Lay $sP3No
   assert_warn $? 0 "New interface of type HSI defined?"
   echo
   sleep 5

# START LINUX-Part2 (ifup):
   echo
   echo "***** START LINUX-Part2 (ifup): 3rd interface - Real HSI - ipv6 address *****"
   echo

   isIfconfigOrIP
   RET=$?

   if [ $RET -eq 0 ]
   then
        sE3="$(cat /sys/bus/ccwgroup/drivers/qeth/$sE3a/if_name)"
        ifconfig $sE3 inet6 add $sE3ip6/$sE3ip6Prefix up
        assert_warn $? 0 "Setup of new interface of type HSI done?"
        ifconfig $sE3
   elif [ $RET -eq 1 ]
   then
        echo "ip"
        net_ifup_linux_ip6 $sE3a $sE3ip6 $sE3ip6Prefix
        assert_warn $? 0 "Setup of new interface done?"
   fi

   sleep 7

   assert_warn $? 0 "NULL"
}

###########################################################################################
part_x(){
  echo "(x) tbd"

   # tbd ...

   assert_warn $? 0 "NULL"
}

######################################################################################
###
### MAIN

# default testcases
# TESTCASES="a" ./<name of script>
# only executes testcase in "part_a"
#
#TESTCASES="${TESTCASES:-a b c}"
TESTCASES="${TESTCASES:-$x20STEST}"

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
