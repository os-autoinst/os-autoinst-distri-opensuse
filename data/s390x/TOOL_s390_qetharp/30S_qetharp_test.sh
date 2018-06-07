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

cleanup(){
  true;
}

setup_testcase(){

   echo "(INIT) Check preconditions"
   $CLEANUPTESTCASE_PROCEDURE
   dmesg -c &> /dev/null
   assert_warn $? 0 "NULL"
}
part_a(){
   echo "(a) Test qetharp common options"

   assert_exec 0 qetharp -h
   assert_exec 0 qetharp --help
   assert_exec 0 qetharp -v
   assert_exec 0 qetharp --version

}
part_b(){
  echo "(b) Real OSA <IPv4> : Qetharp Options"

  IFNAME=$(cat $P0$sE1a/if_name)
  CHECK=`ip addr show $IFNAME | grep -w inet | wc -l`

 if [[ $CHECK -eq 1 ]]; then

  ping -c 2 $cE1ip

  assert_exec 0 qetharp -q $IFNAME
  entry1=`qetharp -q $IFNAME | grep $sE1ip`
  entry2=`qetharp -q $IFNAME | grep $cE1ip`

  s_host_name=`hostname`
  host_name_entry1=`qetharp -q $IFNAME | grep $sHOST`

  c_host_name=`hostname`
  host_name_entry2=`qetharp -q $IFNAME | grep $cHOST`


  if [ "`expr \"$entry1\" : \"$sE1ip\"`" != "0" ]; then
     assert_warn $? 0 "Qetharp with -q option for $IFNAME contains $sE1ip "

  elif [ "`expr \"$host_name_entry1\" : \"$sHOST\"`" != "0" ] ; then
       assert_warn $? 0 "Qetharp with -q option for $IFNAME contains $sHOST "

  else
     assert_warn $? 0 "Qetharp with -q option for $IFNAME does not contain $sE1ip"

  fi

  if [ "`expr \"$entry2\" : \"$cE1ip\"`" != "0" ]; then
     assert_warn $? 0 "Qetharp with -q option for $IFNAME contains $cE1ip "

  elif [ "`expr \"$host_name_entry2\" : \"$cHOST\"`" != "0" ] ; then
       assert_warn $? 0 "Qetharp with -q option for $IFNAME contains $cHOST "

  else
     assert_warn $? 0 "Qetharp with -q option for $IFNAME does not contain $cE1ip"

  fi

  echo
  echo
  assert_exec 0 qetharp -nq $IFNAME
  entry1=`qetharp -nq $IFNAME | grep $sE1ip`
  entry2=`qetharp -nq $IFNAME | grep $cE1ip`

  if [ "`expr \"$entry1\" : \"$sE1ip\"`" != "0" ]; then
     assert_warn $? 0 "Qetharp with -nq option for $IFNAME contains $sE1ip "
  else
     assert_warn $? 0 "Qetharp with -nq option for $IFNAME does not contain $sE1ip"
  fi

  if [ "`expr \"$entry2\" : \"$cE1ip\"`" != "0" ]; then
     assert_warn $? 0 "Qetharp with -nq option for $IFNAME contains $cE1ip "
  else
     assert_warn $? 0 "Qetharp with -nq option for $IFNAME does not contain $cE1ip"
  fi


  echo
  echo
  assert_exec 0 qetharp -cnq $IFNAME
  entry1=`qetharp -cnq $IFNAME | grep $sE1ip`
  entry2=`qetharp -cnq $IFNAME | grep $cE1ip`

  if [ "`expr \"$entry1\" : \"$sE1ip\"`" != "0" ]; then
     assert_warn $? 0 "Qetharp with -nq option for $IFNAME contains $sE1ip "
  else
     assert_warn $? 0 "Qetharp with -nq option for $IFNAME does not contain $sE1ip"
  fi

  if [ "`expr \"$entry2\" : \"$cE1ip\"`" != "0" ]; then
     assert_warn $? 0 "Qetharp with -nq option for $IFNAME contains $cE1ip "
  else
     assert_warn $? 0 "Qetharp with -nq option for $IFNAME does not contain $cE1ip"
  fi

  echo
  echo
  assert_exec 0 qetharp -a $IFNAME -i $dummy_ip -m $dummy_mac
  entry1=`qetharp -q $IFNAME | grep $dummy_ip`

   if [ "`expr \"$entry1\" : \"$dummy_ip\"`" != "0" ]; then
     assert_warn $? 0 "New IP address got added successfully to arp cache when tried with -a option "
     echo
     echo
     assert_exec 0 qetharp -d $IFNAME -i $dummy_ip
     entry2=`qetharp -q $IFNAME | grep $dummy_ip`

     if [ "`expr \"$entry2\" : \"$dummy_ip\"`" == "0" ]; then
     assert_warn $? 0 "$dummy_ip - IP Address got removed successfully from arp cache with -d option"
    else
     assert_warn $? 0 "$dummy_ip - IP Address got removed successfully from arp cache with -d option"
    fi

  else
     assert_warn $? 0 "New IP address didnt get added to arp cache when tried with -a option"
  fi

 else
    echo "Interface $IFNAME - is not of type Ipv4 address"
 fi


}
part_c(){
  echo "(c) Real Hipersockets <IPv4> : Qetharp Options"

  IFNAME=$(cat $P0$sE2a/if_name)
  CHECK=`ip addr show $IFNAME | grep -w inet | wc -l`

 if [[ $CHECK -eq 1 ]]; then
  assert_exec 0 qetharp -q $IFNAME
  entry1=`qetharp -q $IFNAME | grep $sE2ip`
  entry2=`qetharp -q $IFNAME | grep $cE2ip`

  s_host_name=`hostname`
  host_name_entry1=`qetharp -q $IFNAME | grep $sHOST`

  if [ "`expr \"$entry1\" : \"$sE2ip\"`" != "0" ]; then
     assert_warn $? 0 "Qetharp with -q option for $IFNAME contains $sE2ip "

  elif [ "`expr \"$host_name_entry1\" : \"$sHOST\"`" != "0" ] ; then
       assert_warn $? 0 "Qetharp with -q option for $IFNAME contains $sHOST "

  else
     assert_warn $? 0 "Qetharp with -q option for $IFNAME does not contain $sE2ip"

  fi

  if [ "`expr \"$entry2\" : \"$cE2ip\"`" != "0" ]; then
     assert_warn $? 0 "Qetharp with -q option for $IFNAME contains $cE2ip "
  else
     assert_warn $? 0 "Qetharp with -q option for $IFNAME does not contain $cE2ip"

  fi

  echo
  echo
  assert_exec 0 qetharp -nq $IFNAME
  entry1=`qetharp -nq $IFNAME | grep $sE2ip`
  entry2=`qetharp -nq $IFNAME | grep $cE2ip`

  if [ "`expr \"$entry1\" : \"$sE2ip\"`" != "0" ]; then
     assert_warn $? 0 "Qetharp with -nq option for $IFNAME contains $sE2ip "
  else
     assert_warn $? 0 "Qetharp with -nq option for $IFNAME does not contain $sE2ip"
  fi

  if [ "`expr \"$entry2\" : \"$cE2ip\"`" != "0" ]; then
     assert_warn $? 0 "Qetharp with -nq option for $IFNAME contains $cE2ip "
  else
     assert_warn $? 0 "Qetharp with -nq option for $IFNAME does not contain $cE2ip"
  fi

  echo
  echo
  assert_exec 0 qetharp -cnq $IFNAME
  entry1=`qetharp -cnq $IFNAME | grep $sE2ip`
  entry2=`qetharp -cnq $IFNAME | grep $cE2ip`

  if [ "`expr \"$entry1\" : \"$sE2ip\"`" != "0" ]; then
     assert_warn $? 0 "Qetharp with -nq option for $IFNAME contains $sE2ip "
  else
     assert_warn $? 0 "Qetharp with -nq option for $IFNAME does not contain $sE2ip"
  fi

  if [ "`expr \"$entry2\" : \"$cE2ip\"`" != "0" ]; then
     assert_warn $? 0 "Qetharp with -nq option for $IFNAME contains $cE2ip "
  else
     assert_warn $? 0 "Qetharp with -nq option for $IFNAME does not contain $cE2ip"
  fi


 else
    echo "Interface $IFNAME - is not of type Ipv4 address"
 fi

}
part_d(){
  echo "(d) Real Hipersockets <IPv6> : Qetharp Options"

  IFNAME=$(cat $P0$sE3a/if_name)
  CHECK=`ip addr show $IFNAME | grep -w inet | wc -l`

 if [[ $CHECK -ne 1 ]]; then
  assert_exec 0 qetharp -6q $IFNAME
  entry1=`qetharp -6q $IFNAME | grep $sE3ip6`
  entry2=`qetharp -6q $IFNAME | grep $cE3ip6`

  s_host_name=`hostname`
  host_name_entry1=`qetharp -q $IFNAME | grep $sHOST`

  if [ "`expr \"$entry2\" : \"$cE3ip6\"`" != "0" ]; then
     assert_warn $? 0 "Qetharp with -6q option for $IFNAME contains $cE3ip6 "
  else
     assert_warn $? 0 "Qetharp with -6q option for $IFNAME does not contain $cE3ip6"

  fi

  assert_exec 0 qetharp -6nq $IFNAME

  assert_exec 0 qetharp -6cnq $IFNAME

 else
    echo "Interface $IFNAME - is of type Ipv4 address"
 fi
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
#TESTCASES="${TESTCASES:-a b }"
TESTCASES="${TESTCASES:-$x30STEST}"

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


# vim: ai et ts=2 shiftwidth=2 expandtab tabstop=3 bg=dark
