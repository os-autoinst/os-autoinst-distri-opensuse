#!/bin/bash
#


bridgeA=${bridgeA:-bridgeA}
dummyA=${dummyA:-dummyA}
dummyB=${dummyB:-dummyB}
tapA=${tapA:-tapA}


test_description()
{
	cat - <<-EOT

	And/remove ports from Bridge and use wicked ifreload to apply"

	setup:

	   $dummyA,$dummyB,$tapA -m-> $bridgeA

	EOT
}

step0()
{
	bold "=== $step -- Setup configuration"
	echo ""

	cat >"${dir}/ifcfg-$dummyA" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		DUMMY=yes
	EOF

	cat >"${dir}/ifcfg-$dummyB" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		DUMMY=yes
	EOF

	cat >"${dir}/ifcfg-$bridgeA" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='$dummyA'
	EOF

	print_test_description
	log_device_config "$dummyA" "$dummyB" "$bridgeA"
}

step1()
{
	bold "=== $step: ifup $bridgeA { $dummyA + $tapA }"

	echo "wicked $wdebug ifup $cfg all"
	wicked $wdebug ifup $cfg all
	echo ""

	print_device_status "$bridgeA" "$dummyA"
	check_device_is_up "$bridgeA" "$dummyA"
	echo ""

	echo "ip tuntap add $tapA mode tap"
	ip tuntap add $tapA mode tap
	echo "ip link set master $bridgeA up dev $tapA"
	ip link set master $bridgeA up dev $tapA
	echo ""

	print_device_status "$dummyA" "$dummyB" "$tapA"

	check_device_has_port "$bridgeA" "$dummyA" "$tapA"
	check_device_has_not_port "$bridgeA" "$dummyB"
	echo ""

	if wicked ifstatus $cfg $tapA | grep -qs compat:suse ; then
		red "ERROR: $tapA has received generated config"
		((err++))
	fi
	check_policy_not_exists tapA
}

step2()
{
	bold "=== $step: ifup $bridgeA { $dummyA + $tapA } again"

	echo "wicked $wdebug ifup $cfg all"
	wicked $wdebug ifup $cfg all
	echo ""

	print_device_status all

	check_device_has_port "$bridgeA" "$dummyA" "$tapA"
	check_device_has_not_port "$bridgeA" "$dummyB"
	echo ""

	if wicked ifstatus $cfg $tapA | grep -qs compat:suse ; then
		red "ERROR: $tapA has received generated config"
		((err++))
	fi
	check_policy_not_exists tapA
}

step3()
{
	bold "=== $step: ifreload $bridgeA { $dummyB + $tapA }"

	# change bridge to use $dummyB instead + ifreload
	cat >"${dir}/ifcfg-$bridgeA" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='$dummyB'
	EOF

	log_device_config "$dummyA" "$dummyB" "$bridgeA"


	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all

	check_device_has_port "$bridgeA" "$dummyB" "$tapA"
	check_device_has_not_port "$bridgeA" "$dummyA"
	echo ""

	if wicked ifstatus $cfg $tapA | grep -qs compat:suse ; then
		red "ERROR: $tapA has received generated config"
		((err++))
	fi
	check_policy_not_exists tapA
}

step4()
{
	bold "=== $step: ifreload $bridgeA { $dummyA + $dummyB + $tapA }"

	# change bridge to use $dummyB instead + ifreload
	cat >"${dir}/ifcfg-$bridgeA" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='$dummyA $dummyB'
	EOF

	log_device_config "$dummyA" "$dummyB" "$bridgeA"


	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all

	check_device_has_port "$bridgeA" "$dummyA" "$dummyB" "$tapA"
	echo ""

	if wicked ifstatus $cfg $tapA | grep -qs compat:suse ; then
		red "ERROR: $tapA has received generated config"
		((err++))
	fi
	check_policy_not_exists tapA
}

step99()
{
	bold "=== $step: cleanup"

	echo "ip link delete $tapA"
	ip link delete $tapA

	echo "wicked $wdebug ifdown "$bridgeA" "$dummyA" "$dummyB" "$tapA""
	wicked $wdebug ifdown "$bridgeA" "$dummyA" "$dummyB" "$tapA"
	echo ""

	rm -f "${dir}/ifcfg-$dummyA"
	rm -f "${dir}/ifcfg-$dummyB"
	rm -f "${dir}/ifcfg-$bridgeA"

	check_policy_not_exists "$dummyA"
	check_policy_not_exists "$dummyB"
	check_device_is_down "$bridgeA"
}

. ../../lib/common.sh
