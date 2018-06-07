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
source "./00_config-file_TOOL_s390_qetharp" || exit 1

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
   echo "(a) Deny Broadcast"

# - - - - - - - - - - - - - - - - - - - - -
# Disable Broadcast/Multicast
# - - - - - - - - - - - - - - - - - - - - -
   sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1
   assert_warn $? 0 "Deny broadcast"

   assert_warn $? 0 "NULL"

}

###########################################################################################
part_b(){
  echo "(b) Delete all Interface except LAN eth0"

# - - - - - - - - - - - - - - - - - - - - -
# Delete all LINUX interfaces:
# - - - - - - - - - - - - - - - - - - - - -
   net_cleanup_linux "$sLANa"
   lsqeth -p
   assert_warn $? 0 "NULL"

   assert_warn $? 0 "NULL"

}

###########################################################################################
part_c(){
  echo "(c) Detach all DEVNOs except 0.0.F5xx"

# - - - - - - - - - - - - - - - - - - - - -
# Detach all DEVNOs except 0.0.F5xx
# - - - - - - - - - - - - - - - - - - - - -
   isVM
   RET=$?

   if [ "1" = "$RET" ]; then
    echo
    echo "Not a VM-guest!"
    echo
    return
   fi
   if [ "0" = "$RET" ]; then
    echo
    echo "Yes a VM-guest!"
    echo
    net_cleanup_vm "$sLANa $sLANb $sLANc"
   fi
   vmcp 'q v osa'
   assert_warn $? 0 "NULL"

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
TESTCASES="${TESTCASES:-$x10CTEST}"

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
