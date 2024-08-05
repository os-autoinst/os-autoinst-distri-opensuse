#!/bin/bash


bridgeA="${bridgeA:-bridgeA}"
bridgeA_ip4="${bridgeA_ip4:-198.18.10.10/24}"
dummyA="${dummyA:-dummy99}"  # use a valid dummy name here, the dummy does be generated

test_description()
{
	cat - <<-EOT

	Change config from bridge interface and run ifreload all.
	The port is a dummy interface.

	setup:

	   $dummyA -m-> $bridgeA

	EOT
}

step0()
{
	print_test_description
}

step1()
{
	check_change_bridge_fwd_delay 7 "$dummyA"
}

step2()
{
	check_change_bridge_fwd_delay 5 "$dummyA"
}

step3()
{
	check_change_bridge_fwd_delay 10 "$dummyA"
}

step99()
{
	bold "=== $step: cleanup"

	echo "wicked $wdebug ifdown $bridgeA $dummyA"
	wicked $wdebug ifdown "$bridgeA" "$dummyA"
	echo ""

	rm -f "${dir}/ifcfg-$dummyA"
	rm -f "${dir}/ifcfg-$bridgeA"

	check_policy_not_exists "$dummyA"
	check_policy_not_exists "$bridgeA"
	check_device_is_down "$bridgeA"
}

. ../test-1.2/common.sh
