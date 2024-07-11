#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
nicB="${nicB:?Missing "nicB" parameter, this should be set to the first physical ethernet adapter (e.g. nicB=eth2)}"
ovsbrA=${ovsbrA:-ovsbrA}
tapA=${tapA:-tap3}

test_description()
{
	cat - <<-EOT

	Setup:
	    $nicA|$nicB   -m->    $ovsbrA   <-l-    $ovsbrB

	EOT
}

set_ovsbridge_ports()
{
	local br=$1; shift

	if [ "XXX$*" == "XXX" ]; then
		sed -i "/OVS_BRIDGE_PORT_DEVICE/d" "${dir}/ifcfg-$br"
	else
		if grep -qsw OVS_BRIDGE_PORT_DEVICE "${dir}/ifcfg-$br"; then
			sed -i "/OVS_BRIDGE_PORT_DEVICE/cOVS_BRIDGE_PORT_DEVICE='$*'" "${dir}/ifcfg-$br"
		else
			echo "OVS_BRIDGE_PORT_DEVICE='$*'" >> "${dir}/ifcfg-$br"
		fi
	fi

	log_device_config "$br" "$@"
}

step0()
{
	bold "=== $step -- Setup configuration"

	cat >"${dir}/ifcfg-${ovsbrA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		OVS_BRIDGE='yes'
		OVS_BRIDGE_PORT_DEVICE='${nicA}'
		# ignore br carrier
		LINK_REQUIRED='no'
	EOF

	print_test_description
	log_device_config "$ovsbrA"
}

step1()
{
	bold "=== $step: ifup ${ovsbrA} { ${nicA} }"

	echo "wicked ${wdebug} ifup $cfg all"
	wicked ${wdebug} ifup $cfg all
	echo ""

	print_device_status "$ovsbrA" "$nicA"
	check_ovsbr_has_port "$ovsbrA" "$nicA"
}

step2()
{
	bold "=== $step: ifreload ${ovsbrA} { }"

	set_ovsbridge_ports "$ovsbrA" ""

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked ${wdebug} ifreload all"
	wicked ${wdebug} ifreload $cfg all
	echo ""

	print_device_status "$ovsbrA" "$nicA"
	check_ovsbr_has_not_port "$ovsbrA" "$nicA"
}

step3()
{
	bold "=== $step: ifreload ${ovsbrA} { ${nicA} + ${tapA} }"

	set_ovsbridge_ports "$ovsbrA" "$nicA"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked ${wdebug} ifreload $cfg all"
	wicked ${wdebug} ifreload $cfg all
	echo ""

	print_device_status "$ovsbrA" "$nicA"
	check_ovsbr_has_port "$ovsbrA" "$nicA"


	ip tuntap add ${tapA} mode tap
	ovs-vsctl add-port ${ovsbrA} ${tapA}
	ip link set up dev ${tapA}

	print_device_status "${ovsbrA}" "${nicA}" "${tapA}"
	ovs-vsctl show

	check_ovsbr_has_port "$ovsbrA" "$nicA" "$tapA"
}

step4()
{
	bold "=== $step: ifreload ${ovsbrA} { ${tapA} }"

	set_ovsbridge_ports "$ovsbrA" ""

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked ${wdebug} ifreload $cfg all"
	wicked ${wdebug} ifreload $cfg all
	echo ""

	print_device_status "${ovsbrA}" "${nicA}" "${tapA}"
	ovs-vsctl show

	check_ovsbr_has_port "$ovsbrA" "$tapA"
	check_ovsbr_has_not_port "$ovsbrA" "$nicA"
}

step5()
{
	bold "=== $step: ifreload ${ovsbrA} { ${tapA} + $nicB }"

	set_ovsbridge_ports "$ovsbrA" "$nicB"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked ${wdebug} ifreload $cfg all"
	wicked ${wdebug} ifreload $cfg all
	echo ""

	print_device_status "${ovsbrA}" "${nicB}" "$nicA" "${tapA}"
	ovs-vsctl show

	check_ovsbr_has_port "$ovsbrA" "$tapA" "$nicB"
	check_ovsbr_has_not_port "$ovsbrA" "$nicA"
}

step6()
{
	bold "=== $step: ifreload ${ovsbrA} { ${tapA} + $nicA }"

	set_ovsbridge_ports "$ovsbrA" "$nicA"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked ${wdebug} ifreload $cfg all"
	wicked ${wdebug} ifreload $cfg all
	echo ""

	print_device_status "${ovsbrA}" "${nicB}" "$nicA" "${tapA}"
	ovs-vsctl show

	check_ovsbr_has_port "$ovsbrA" "$tapA" "$nicA"
	check_ovsbr_has_not_port "$ovsbrA" "$nicB"
}


step99()
{
	bold "=== $step: cleanup"

	echo "# wicked ifdown ${ovsbrA} ${nicA}"
	wicked ${wdebug} ifdown ${ovsbrA} ${nicA}
	echo ""

	print_device_status ${ovsbrA} ${nicA} ${tapA}
	echo "# ovs-vsctl show"
	ovs-vsctl show
	echo ""

	# delete tapA we've created in this testcase
	echo "# ip link delete ${tapA}"
	ip link delete ${tapA}
	echo ""

	# just in case ifdown fails, also br in ovs
	echo "# ovs-vsctl del-br ${ovsbrA}"
	ovs-vsctl del-br ${ovsbrA}
	echo ""

	echo "# rm -v -f -- ${dir}/ifcfg-${ovsbrA}*"
	rm -v -f -- "${dir}/ifcfg-${ovsbrA}"*
	echo "# rm -v -f -- ${dir}/ifcfg-${nicA}*"
	rm -v -f -- "${dir}/ifcfg-${nicA}"*
	echo ""

	echo "==================================="
}


. ../../lib/common.sh
