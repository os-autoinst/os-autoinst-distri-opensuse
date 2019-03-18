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
source "./x00_config-file_tool_s390_qethqoat" || exit 1

CLEANUPTESTCASE_PROCEDURE="cleanup"

cleanup(){
  true;
}

setup_testcase(){
   section_start "(INIT) Check preconditions"
   $CLEANUPTESTCASE_PROCEDURE
   assert_warn $? 0 "NULL"
   section_end
}

part_a(){
	section_start "(a) Test qethqoat General Options"
	incr=1
	echo "[root@$sHOST ]# lsqeth -p"
	IFNAME=$(cat $P0$sE1a/if_name)
	echo
	echo "[root@$sHOST ]# lsqeth $IFNAME"
	hsiName=$(cat $P0$sE2a/if_name)
	sed -e "s/hsi/${hsiName}/g"  qethoptGeneral > tempqethoptGen
	echo
	while read line
	do
		echo
		CMD=$(echo $line | cut -d" " -f3-)
		echo "$incr. Testing $CMD"
		echo
		ERESULT=$(echo $line | awk -F " " '{ print $1 }')
		ERetCode=$(echo $line | awk -F " " '{ print $2 }')

		echo "[root@$sHOST ]# $CMD"
		if [ "$ERESULT" == "PASS" ]
		then
			$CMD
			assert_warn $? $ERetCode "Command '$CMD' should be executed successful"
		else
			$CMD
			assert_warn $? $ERetCode "Command '$CMD' should fail with exit code $ERetCode"
		fi
		echo "===================================================================="
		incr=$((incr+1))

	done < tempqethoptGen
	rm -f  tempqethoptGen
	section_end;
}

function test_qeth {
	if [ "$lay2" == "1" ]; then
		assert_warn 1 "qethqoat doesn't work for Layer 2 devices"
		return;
	else
		echo "Interface: $IFNAME"
		assert_exec 0 "qethqoat $IFNAME"
		assert_exec 0 "qethqoat -r -s 0 $IFNAME > myfile1"
		assert_exec 0 "qethqoat -f myfile1"
		assert_exec 0 "qethqoat -r -s 1 $IFNAME > myfile2"
		assert_exec 0 "qethqoat -f myfile2"
		assert_exec 0 "qethqoat -r $IFNAME > myfile3"
		assert_exec 0 "qethqoat -f myfile3"
		assert_exec 0 "qethqoat -s 0 $IFNAME"
		assert_exec 0 "qethqoat -s 1 $IFNAME > result.txt"
	fi

	rm -f myfile100
	rm -f myfile2
	rm -f myfile3
	rm -f result.txt
}

part_b(){
	section_start "(b) Test qethqoat Interface specific options for qeth"

	lay2=$(cat $P0$sE1a/layer2)


	IFNAME=$(cat $P0$sE1a/if_name)
	test_qeth
	sleep 2
	IFNAME=$(cat $P0$sE3a/if_name)
	test_qeth
	sleep 2


	echo "Test qethqoat with hipersocket"

	hsiName=$(cat $P0$sE2a/if_name)
	lay2=$(cat $P0$sE1a/layer2)

	if [ "$lay2" == "1" ];	then
		assert_warn 1 "qethqoat doesn't work for Layer 2 devices"
		return
	else
		echo "$hsiName"
		#oldcomment#assert_exec 22 qethqoat $hsiName
		#comment due to lack of HS dev on my zVM#		assert_exec 1 qethqoat $hsiName
		#oldcomment#assert_exec 22 "qethqoat -r -s 0 $hsiName > myfile1"
		#comment due to lack of HS dev on my zVM#		assert_exec 1 "qethqoat -r -s 0 $hsiName > myfile1"
		#comment due to lack of HS dev on my zVM#		assert_exec 0 qethqoat -f myfile1
		#oldcomment#assert_exec 22 "qethqoat -r -s 1 $hsiName > server/myfile2"
		#comment due to lack of HS dev on my zVM#		assert_exec 1 "qethqoat -r -s 1 $hsiName > myfile2"
		#comment due to lack of HS dev on my zVM#		assert_exec 0 qethqoat -f myfile2

		#comment due to lack of HS dev on my zVM#		assert_exec 1 "qethqoat -r $hsiName > myfile3"
		#comment due to lack of HS dev on my zVM#		assert_exec 0  qethqoat -f myfile3
		#oldcomment#assert_exec 22 qethqoat -s 0 $hsiName
		#comment due to lack of HS dev on my zVM#		assert_exec 1 qethqoat -s 0 $hsiName
		#oldcomment#assert_exec 22 "qethqoat -s 1 $hsiName > result.txt"
		#comment due to lack of HS dev on my zVM#		assert_exec 1 "qethqoat -s 1 $hsiName > result.txt"
	fi

	rm -f myfile1
	rm -f myfile2
	rm -f myfile3
	rm -f result.txt


	echo "Additional test: Delete a interface after execute qethqoat"
	IFNAME=$(cat $P0$sE1a/if_name)

	assert_exec 0 lsqeth -p
	assert_exec 0 lsqeth
	assert_exec 0 znetconf -n -r $sE1a
	assert_exec 0 lsqeth -p
	#assert_exec 22 qethqoat $IFNAME
	assert_exec 1 qethqoat $IFNAME

	section_end
}


################################################################################
# Start
################################################################################
TESTCASES="${TESTCASES:-$x30STEST}"

section_start "START: $0"
init_tests
setup_testcase

echo "Executing the testscript ($0) with the following sections: $TESTCASES"
echo
echo "Run dedicated testcases with TESTCASE = $0"

for i in $TESTCASES; do
   echo
   "part_$i";
   echo
done

show_test_results
