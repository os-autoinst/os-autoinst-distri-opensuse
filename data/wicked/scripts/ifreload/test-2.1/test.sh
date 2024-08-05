#!/bin/bash


bridgeA=${bridgeA:-bridgeA}
nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
tapA=${tapA:-tapA}

test_description()
{
	cat - <<-EOT

	And/remove ports from Bridge and use wicked ifreload to apply

	setup:

	   $nicA,$tapA -m-> $bridgeA

	EOT
}

step0()
{

	bold "=== $step -- Setup configuration"

	cat >"${dir}/ifcfg-${bridgeA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BRIDGE='yes'
		BRIDGE_STP='off'
		BRIDGE_FORWARDDELAY='0'
		BRIDGE_PORTS='${nicA}'
		# ignore br carrier
	EOF

	print_test_description
	log_device_config "$bridgeA" "$nicA"
}

step1()
{
	bold "=== $step: ifup ${bridgeA} { ${nicA} }"

	echo "wicked $wdebug ifup $cfg all"
	wicked $wdebug ifup $cfg all
	echo ""

	print_device_status "${bridgeA}" "${nicA}" "${tapA}"

	check_device_has_port "$bridgeA" "$nicA"
}

step2()
{
	bold "=== $step: ifreload ${bridgeA} { }"

	# change bridge to not use any port + ifreload
	cat >"${dir}/ifcfg-${bridgeA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BRIDGE='yes'
		BRIDGE_STP='off'
		BRIDGE_FORWARDDELAY='0'
		BRIDGE_PORTS=''
		# ignore br carrier
		LINK_REQUIRED='no'
	EOF

	log_device_config "$bridgeA" "$nicA"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status ${bridgeA} ${nicA} ${tapA}

	check_device_has_not_port $bridgeA $nicA
}

step3()
{
	bold "=== $step: ifreload ${bridgeA} { ${nicA} + ${tapA} }"

	cat >"${dir}/ifcfg-${bridgeA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BRIDGE='yes'
		BRIDGE_STP='off'
		BRIDGE_FORWARDDELAY='0'
		BRIDGE_PORTS='${nicA}'
		# ignore br carrier
		LINK_REQUIRED='no'
	EOF

	log_device_config "$bridgeA" "$nicA"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo "ip tuntap add ${tapA} mode tap"
	ip tuntap add ${tapA} mode tap
	echo "ip link set master ${bridgeA} up dev ${tapA}"
	ip link set master ${bridgeA} up dev ${tapA}
	echo ""

	print_device_status ${bridgeA} ${nicA} ${tapA}

	check_device_has_port "$bridgeA" "$nicA" "$tapA"
}

step4()
{
	echo "=== $step: ifreload ${bridgeA} { + ${tapA} }"

	cat >"${dir}/ifcfg-${bridgeA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BRIDGE='yes'
		BRIDGE_STP='off'
		BRIDGE_FORWARDDELAY='0'
		BRIDGE_PORTS=''
		# ignore br carrier
		LINK_REQUIRED='no'
	EOF

	log_device_config $bridgeA

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status ${bridgeA} ${nicA} ${tapA}

	check_device_has_port "$bridgeA" "$tapA"
	check_device_has_not_port "$bridgeA" "$nicA"
}

step99()
{
	echo "=== $step: cleanup"

	echo "ip link delete $tapA"
	ip link delete $tapA
	echo ""

	echo "wicked $wdebug ifdown ${bridgeA}"
	wicked $wdebug ifdown ${bridgeA}
	rm -f "${dir}/ifcfg-${bridgeA}"
	rm -f "${dir}/ifcfg-${nicA}"

	print_device_status all
	check_device_is_down "$bridgeA"
	check_device_is_down "$nicA"
}

. ../../lib/common.sh
