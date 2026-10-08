#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
nicB="${nicB:?Missing "nicB" parameter, this should be set to the first physical ethernet adapter (e.g. nicB=eth2)}"
teamA="${teamA:-teamA}"
team_slaves="$nicA $nicB"
team_slave_ifcfg=no

vlanA_id="${vlanA_id:-10}"
vlanB_id="${vlanB_id:-20}"
vlanA="${teamA}.${vlanA_id}"
vlanB="${teamA}.${vlanB_id}"
bridgeA="${bridgeA:-bridgeA}"
bridgeB="${bridgeB:-bridgeB}"

other_call="tuntap" # link or tuntap supported
other_type="tap"
: ${other0:="tap40"}
: ${other1:="tap44"}

all_interfaces="$nicA $nicB $teamA $vlanA $vlanB $bridgeA $bridgeB $other0 $other1"

test_description()
{
	cat - <<-EOT

	Add and remove ports from team interface. Also use TAP devices which are not
	configured within wicked.

	setup:

	    $nicA|$nicB  -m->   $teamA  <-l-  $vlanB  -m->  $bridgeB
	                                -m->  $bridgeA
	EOT
}

step0()
{
	bold "=== $step -- Setup configuration"

	##
	## setup team as bridgeA port
	##
	cat >"${dir}/ifcfg-${teamA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		TEAM_RUNNER='activebackup'
		TEAM_LW_NAME='ethtool'
	EOF
	i=0
	for slave in ${team_slaves} ; do
		((i++))
		cat >>"${dir}/ifcfg-${teamA}" <<-EOF
			TEAM_PORT_DEVICE_${i}='$slave'
		EOF
	done
	if test "X$team_slave_ifcfg" = "Xyes" ; then
		for slave in ${team_slaves} ; do
			cat >"${dir}/ifcfg-${slave}" <<-EOF
				STARTMODE='hotplug'
				BOOTPROTO='none'
			EOF
		done
	fi

	cat >"${dir}/ifcfg-${vlanB}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ETHERDEVICE='${teamA}'
		#VLAN_ID='${vlanB_id}'
	EOF

	# vlanB is untagged pvid on team
	cat >"${dir}/ifcfg-${bridgeA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${teamA}'
	EOF

	# vlan2 is a tagged vlan on team
	cat >"${dir}/ifcfg-${bridgeB}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${vlanB}'
	EOF

	print_test_description
	log_device_config $all_interfaces
}

step1()
{
	bold "=== $step: ifreload ${bridgeA} { ${teamA} { ${team_slaves} } + ${other0} }, ${bridgeB} { ${vlanB} + ${other1} }"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	case ${other_call} in
	link)
	    echo "ip link add ${other0} type ${other_type}"
	    ip link add ${other0} type ${other_type}
	    echo "ip link add ${other1} type ${other_type}"
	    echo ""
	    ;;
	tuntap)
	    echo "ip tuntap add ${other0} mode ${other_type}"
	    ip tuntap add ${other0} mode ${other_type}
	    echo "ip tuntap add ${other1} mode ${other_type}"
	    ip tuntap add ${other1} mode ${other_type}
	    ;;
	esac
	echo "ip link set master ${bridgeA} up dev ${other0}"
	ip link set master ${bridgeA} up dev ${other0} || ((err++))
	echo "ip link set master ${bridgeB} up dev ${other1}"
	ip link set master ${bridgeB} up dev ${other1} || ((err++))

	print_device_status all
	print_bridges

	check_device_has_port "$teamA" ${team_slaves}

	check_device_has_not_port "$bridgeA" "$vlanA"
	check_device_has_port "$bridgeA" "$teamA" "$other0"
	check_device_has_port "$bridgeB" "$vlanB" "$other1"
	check_device_has_link "$vlanB" "$teamA"
}

step2()
{
	bold "=== $step: ifreload ${teamA} { ${team_slaves} }, ${bridgeA} { ${vlanA} + ${other0} }, ${bridgeB} { ${vlanB} + ${other1} }"
	#
	## setup team vlanB instead of team as bridgeA port
	##

	cat >"${dir}/ifcfg-${vlanA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ETHERDEVICE='${teamA}'
		#VLAN_ID='${vlanA_id}'
	EOF

	cat >"${dir}/ifcfg-${bridgeA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${vlanA}'
	EOF

	log_device_config $all_interfaces

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all
	print_bridges

	check_device_has_link "$vlanA" "$teamA"
	check_device_has_port "$teamA" ${team_slaves}
	check_device_has_not_port "$teamA" "$bridgeA"
	check_device_has_port "$bridgeA" "$vlanA" "$other0"
	check_device_has_port "$bridgeB" "$vlanB" "$other1"
	check_device_has_link "$vlanB" "$teamA"
}

step3()
{
	bold "=== $step: ifreload ${teamA} { ${team_slaves} }, ${bridgeA} { + ${other0} }, ${bridgeB} { ${vlanB} + ${other1} }, ${vlanA}"
	##
	## remove team vlanB from bridgeA ports, but keep vlanB ifcfg file
	##

	cat >"${dir}/ifcfg-${bridgeA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS=''
	EOF

	log_device_config $all_interfaces

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all
	print_bridges

	check_device_has_port "$teamA" ${team_slaves}
	check_device_has_not_port "$bridgeA" "$teamA" "$vlanA"
	check_device_has_port "$bridgeA" "$other0"
	check_device_has_port "$bridgeB" "$vlanB" "$other1"
	check_device_has_link "$vlanB" "$teamA"
}

step4()
{
	bold "=== $step: ifreload ${teamA} { ${team_slaves} }, ${bridgeA} { + ${other0} }, ${bridgeB} { ${vlanB} + ${other1} }"
	##
	## cleanup unenslaved team vlanB
	##

	rm -f "${dir}/ifcfg-${vlanA}"

	log_device_config $all_interfaces

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all
	print_bridges

	check_device_has_port "$teamA" ${team_slaves}
	check_device_has_not_port "$bridgeA" "$teamA" "$vlanA"
	check_device_has_port "$bridgeA" "$other0"
	check_device_has_port "$bridgeB" "$vlanB" "$other1"
	device_exists "$vlanA" && ((err++))
	check_device_has_link "$vlanB" "$teamA"
}

step5()
{
	##
	## create team vlanA and enslave as bridgeA port again
	##
	bold "=== $step: ifreload ${teamA} { ${team_slaves} }, ${bridgeA} { ${vlanA} + ${other0} }, ${bridgeB} { ${vlanB} + ${other1} }"

	cat >"${dir}/ifcfg-${vlanA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ETHERDEVICE='${teamA}'
		#VLAN_ID='${vlanA_id}'
	EOF

	cat >"${dir}/ifcfg-${bridgeA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${vlanA}'
	EOF

	log_device_config $all_interfaces

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all
	print_bridges

	check_device_has_link "$vlanA" "$teamA"
	check_device_has_port "$teamA" ${team_slaves}
	check_device_has_not_port "$teamA" "$bridgeA"
	check_device_has_port "$bridgeA" "$vlanA" "$other0"
	check_device_has_port "$bridgeB" "$vlanB" "$other1"
	check_device_has_link "$vlanB" "$teamA"
}

step6()
{
	##
	## replace team vlanA bridgeA port with team and delete team vlanA again
	##
	bold "=== $step: ifreload ${bridgeA} { ${teamA} { ${team_slaves} } + ${other0} }, ${bridgeB} { ${vlanB} + ${other1} }"

	rm -f "${dir}/ifcfg-${vlanA}"
	cat >"${dir}/ifcfg-${bridgeA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${teamA}'
	EOF

	log_device_config $all_interfaces

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all
	print_bridges

	check_device_has_port "$teamA" ${team_slaves}
	check_device_has_not_port "$bridgeA" "$vlanA"
	check_device_has_port "$bridgeA" "$teamA" "$other0"
	check_device_has_port "$bridgeB" "$vlanB" "$other1"
	device_exists "$vlanA" && ((err++))
	check_device_has_link "$vlanB" "$teamA"
}

step7()
{
	##
	## removal of first team slave from config (it is **not** a hotplugging test)
	##
	bold "=== $step: ifreload ${bridgeA} { ${teamA} { ${team_slaves#* } } + ${other0} }, ${bridgeB} { ${vlanB} + ${other1} }"

	cat >"${dir}/ifcfg-${teamA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		TEAM_RUNNER='activebackup'
		TEAM_LW_NAME='ethtool'
	EOF
	i=0
	for slave in ${team_slaves#* } ; do
		((i++))
		cat >>"${dir}/ifcfg-${teamA}" <<-EOF
			TEAM_PORT_DEVICE_${i}='$slave'
		EOF
	done
	if test "X$team_slave_ifcfg" = "Xyes" ; then
		for slave in ${team_slaves} ; do
			rm -f "${dir}/ifcfg-${slave}"
		done
		for slave in ${team_slaves#* } ; do
			cat >"${dir}/ifcfg-${slave}" <<-EOF
				STARTMODE='hotplug'
				BOOTPROTO='none'
			EOF
		done
	fi

	log_device_config $all_interfaces

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all
	print_bridges

	for slave in ${team_slaves} ; do
		enslaved=no
		for s in ${team_slaves#* } ; do
			test "x$s" = "x$slave" && enslaved=yes
		done
		if test $enslaved = yes ; then
			check_device_has_port "$teamA" "$slave"
		else
			check_device_has_not_port "$teamA" "$slave"
		fi
	done

	check_device_has_port "$bridgeA" "$teamA" "$other0"
	check_device_has_port "$bridgeB" "$vlanB" "$other1"
	check_device_has_link "$vlanB" "$teamA"
}

step8()
{
	##
	## re-add first team slave to config (it is **not** a hotplugging test)
	##
	bold "=== $step: ifreload ${bridgeA} { ${teamA} { ${team_slaves} } + ${other0} }, ${bridgeB} { ${vlanB} + ${other1} }"

	cat >"${dir}/ifcfg-${teamA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		TEAM_RUNNER='activebackup'
		TEAM_LW_NAME='ethtool'
	EOF
	i=0
	for slave in ${team_slaves} ; do
		((i++))
		cat >>"${dir}/ifcfg-${teamA}" <<-EOF
			TEAM_PORT_DEVICE_${i}='$slave'
		EOF
	done
	if test "X$team_slave_ifcfg" = "Xyes" ; then
		for slave in ${team_slaves} ; do
			cat >"${dir}/ifcfg-${slave}" <<-EOF
				STARTMODE='hotplug'
				BOOTPROTO='none'
			EOF
		done
	fi

	log_device_config $all_interfaces

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all
	print_bridges

	check_device_has_port "$teamA" ${team_slaves}
	check_device_has_port "$bridgeA" "$teamA" "$other0"
	check_device_has_port "$bridgeB" "$vlanB" "$other1"
	check_device_has_link "$vlanB" "$teamA"
}

step99()
{
	bold "=== $step: cleanup"

	echo "wicked ifdown ${bridgeA} ${bridgeB} ${vlanA} ${vlanB} ${teamA} ${team_slaves} ${other0} ${other1}"
	wicked ifdown ${bridgeA} ${bridgeB} ${vlanA} ${vlanB} ${teamA} ${team_slaves} ${other0} ${other1}
	echo ""

	for dev in ${bridgeA} ${bridgeB} ${vlanA} ${vlanB} ${teamA} ${other0} ${other1} ; do
		ip link delete dev $dev
	done
	rm -f "${dir}/ifcfg-${bridgeB}"
	rm -f "${dir}/ifcfg-${bridgeA}"
	rm -f "${dir}/ifcfg-${vlanA}"
	rm -f "${dir}/ifcfg-${vlanB}"
	rm -f "${dir}/ifcfg-${teamA}"
	for slave in ${team_slaves} ; do
		rm -f "${dir}/ifcfg-${slave}"
	done
	echo "-----------------------------------"
	ps  ax | grep /usr/.*/wicked | grep -v grep
	echo "-----------------------------------"
	wicked ifstatus all
	echo "-----------------------------------"
	print_bridges
	echo "-----------------------------------"
	ls -l /var/run/wicked/nanny/
	echo "==================================="
}


. ../../lib/common.sh
