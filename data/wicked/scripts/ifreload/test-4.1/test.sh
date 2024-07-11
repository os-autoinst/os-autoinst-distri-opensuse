#!/bin/bash


bridgeA="${bridgeA:-bridgeA}"
nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
nicB="${nicB:?Missing "nicB" parameter, this should be set to the first physical ethernet adapter (e.g. nicB=eth2)}"

test_description()
{
	cat - <<-EOT
	Changing the port configuration of a bridge and apply via ifreload

	setup:

	    $nicA/$nicB/none -m-> $bridgeA

	EOT
}

set_bridge_ports()
{
	local br=$1; shift

	sed -i "/BRIDGE_PORTS/cBRIDGE_PORTS='$*'" "${dir}/ifcfg-$br"

	log_device_config "$br"
}

step0()
{
	bold "=== $step -- Setup configuration"

	# no explicit port config
	rm -f -- "${dir}/ifcfg-$nicA"
	rm -f -- "${dir}/ifcfg-$nicB"

	# port in the port list
	cat >"${dir}/ifcfg-$bridgeA" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='$nicA'
	EOF

	print_test_description
	log_device_config "$bridgeA" "$nicA" "$nicB"
}

step1()
{
	bold "=== $step: ifup all: $bridgeA { $nicA }"

	set_bridge_ports "$bridgeA" "$nicA"

	echo "wicked $wdebug ifup $cfg all"
	wicked $wdebug ifup $cfg all
	echo ""

	print_device_status "$bridgeA" "$nicA"
	print_bridges

	check_device_has_port "$bridgeA" "$nicA"
	check_device_has_compat_suse_config "$nicA"
}

step2()
{
	bold "=== $step: ifreload all: $bridgeA { }"

	set_bridge_ports "$bridgeA" ""

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status "$bridgeA" "$nicA"
	print_bridges

	check_device_has_not_port "$bridgeA" "$nicA"
	check_device_has_not_compat_suse_config "$nicA"
}

step3()
{
	step1
}

step4()
{
	bold "=== $step: ifreload $bridgeA: $bridgeA { }"

	set_bridge_ports "$bridgeA" ""

	echo "wicked ifreload --dry-run $cfg $bridgeA"
	wicked ifreload --dry-run $cfg $bridgeA
	echo ""
	echo "wicked $wdebug ifreload $cfg $bridgeA"
	wicked $wdebug ifreload $cfg $bridgeA
	echo ""

	print_device_status "$bridgeA" "$nicA"
	print_bridges

	check_device_has_not_port "$bridgeA" "$nicA"
	check_device_has_not_compat_suse_config "$nicA"
}

step5()
{
	bold "=== $step: ifreload $bridgeA: $bridgeA { $nicA }"

	set_bridge_ports "$bridgeA" "$nicA"

	echo "wicked ifreload --dry-run $cfg $bridgeA"
	wicked ifreload --dry-run $cfg "$bridgeA"
	echo ""
	echo "wicked $wdebug ifreload $cfg $bridgeA"
	wicked $wdebug ifreload $cfg $bridgeA
	echo ""

	print_device_status "$bridgeA" "$nicA"
	print_bridges

	check_device_has_port "$bridgeA" "$nicA"
	check_device_has_compat_suse_config "$nicA"
}

step6()
{
	bold "=== $step: ifreload $nicA: $bridgeA { }"

	set_bridge_ports "$bridgeA" ""

	echo "wicked ifreload --dry-run $cfg $nicA"
	wicked ifreload --dry-run $cfg "$nicA"
	echo ""
	echo "wicked $wdebug ifreload $cfg $nicA"
	wicked $wdebug ifreload $cfg "$nicA"
	echo ""

	print_device_status "$bridgeA" "$nicA"
	print_bridges

	check_device_has_not_port "$bridgeA" "$nicA"
	check_device_has_not_compat_suse_config "$nicA"
}

step7()
{
	bold "=== $step: ifreload $nicA: $bridgeA { $nicA }"

	set_bridge_ports "$bridgeA" "$nicA"

	echo "wicked ifreload --dry-run $cfg $nicA"
	wicked ifreload --dry-run $cfg "$nicA"
	echo ""
	echo "wicked $wdebug ifreload $cfg $nicA"
	wicked $wdebug ifreload $cfg "$nicA"
	echo ""

	print_device_status "$bridgeA" "$nicA"
	print_bridges

	check_device_has_not_port "$bridgeA" "$nicB"
	check_device_has_port "$bridgeA" "$nicA"
	check_device_has_compat_suse_config "$nicA"
	check_device_has_not_compat_suse_config "$nicB"
}

step8()
{
	bold "=== $step: ifreload all: $bridgeA { $nicB }"
	# switching the port interface

	set_bridge_ports "$bridgeA" "$nicB"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg "all"
	echo ""

	print_device_status "$bridgeA" "$nicA" "$nicB"
	print_bridges

	check_device_has_port "$bridgeA" "$nicB"
	check_device_has_not_port "$bridgeA" "$nicA"
	check_device_has_compat_suse_config "$nicB"
	check_device_has_not_compat_suse_config "$nicA"
}

step9()
{
	bold "=== $step: ifreload $nicA $nicB: $bridgeA { $nicA }"
	# switching the port interface

	set_bridge_ports "$bridgeA" "$nicA"

	echo "wicked ifreload --dry-run $cfg $nicB"
	wicked ifreload --dry-run $cfg "$nicB"
	echo ""
	echo "wicked $wdebug ifreload $cfg $nicA $nicB"
	wicked $wdebug ifreload $cfg "$nicA" "$nicB"
	echo ""

	print_device_status "$bridgeA" "$nicA" "$nicB"
	print_bridges

	check_device_has_port "$bridgeA" "$nicA"
	check_device_has_not_port "$bridgeA" "$nicB"
	check_device_has_compat_suse_config "$nicA"
	check_device_has_not_compat_suse_config "$nicB"
}

step10()
{
	bold "=== $step: ifreload $nicA: $bridgeA { $nicB }"
	# switching the port interface

	set_bridge_ports "$bridgeA" "$nicB"

	echo "wicked ifreload --dry-run $cfg $nicA"
	wicked ifreload --dry-run $cfg "$nicA"
	echo ""
	echo "wicked $wdebug ifreload $cfg $nicA"
	wicked $wdebug ifreload $cfg "$nicA"
	echo ""

	print_device_status "$bridgeA" "$nicA" "$nicB"
	print_bridges

	check_device_has_not_port "$bridgeA" "$nicA"
	check_device_has_not_port "$bridgeA" "$nicB"

	check_device_has_not_compat_suse_config "$nicA"
	check_device_has_not_compat_suse_config "$nicB"
}

step11()
{
	bold "=== $step: ifreload $nicB: $bridgeA { $nicB }"
	# switching the port interface

	set_bridge_ports "$bridgeA" "$nicB"

	echo "wicked ifreload --dry-run $cfg $nicB"
	wicked ifreload --dry-run $cfg "$nicB"
	echo ""
	echo "wicked $wdebug ifreload $cfg $nicB"
	wicked $wdebug ifreload $cfg "$nicB"
	echo ""

	print_device_status "$bridgeA" "$nicB" "$nicA"
	print_bridges

	check_device_has_not_port "$bridgeA" "$nicA"
	check_device_has_port "$bridgeA" "$nicB"

	check_device_has_not_compat_suse_config "$nicA"
	check_device_has_compat_suse_config "$nicB"
}


step99()
{
	bold "=== $step: cleanup"

	wicked $wdebug ifdown $bridgeA $nicA $nicB
	rm -f "${dir}/ifcfg-$bridgeA"
	rm -f "${dir}/ifcfg-$nicA"
	if test -d "/sys/class/net/$nicA" ; then
		ip link delete $nicA && ((++err))
	fi
	if test -d "/sys/class/net/$bridgeA" ; then
		ip link delete $bridgeA || ((++err))
	fi
	echo "-----------------------------------"
	ps  ax | grep /usr/.*/wicked | grep -v grep
	echo "-----------------------------------"
	wicked ifstatus $cfg all
	echo "-----------------------------------"
	print_bridges
	echo "-----------------------------------"
	ls -l /var/run/wicked/nanny/
	echo "==================================="
}

. ../../lib/common.sh
