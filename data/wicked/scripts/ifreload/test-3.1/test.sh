#!/bin/bash
# The following variables are options which test the same scenario with
# slightly different setup


bond0_slave_ifcfg=${bond0_slave_ifcfg:-yes}  # options: yes, no
other_call=${other_call:-link}               # options: link, tuntap
other_type=${other_type:-tap}
other1="${other1:-tap40}"
other2="${other2:-tap44}"

nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
nicB="${nicB:?Missing "nicB" parameter, this should be set to the first physical ethernet adapter (e.g. nicB=eth2)}"

bondA="${bondA:-bondA}"
bondA_options="${bondA_options:-mode=active-backup miimon=100}"
bond0_slaves="$nicA $nicB"

vlanA_id="${vlanA_id:-10}"
vlanA="${bondA}.${vlanA_id}"

vlanB_id="${vlanB_id:-20}"
vlanB="${bondA}.${vlanB_id}"

bridgeA=${bridgeA:-bridgeA}
bridgeB=${bridgeB:-bridgeB}

dummyA=${dummyA:-dummyA}

all_interfaces="$bondA $other1 $other2 $vlanA $vlanB $bridgeA $bridgeB $dummyA"

other_call="tuntap"
other_type="tap"

test_description()
{
	cat - <<-EOT

	Changing bond and bridge ports and use ifreload to apply.

	setup:

	    $nicA,$nicB -m-> $bondA <-l- $vlanA -m-> $bridgeB
	                         <-l- $vlanB
	                         -m-> $bridgeA

	EOT
}

step0()
{
	bold "=== $step -- Setup configuration"
	echo ""

	cat >"${dir}/ifcfg-${bondA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BONDING_MASTER='yes'
		BONDING_MODULE_OPTS='${bondA_options}'
	EOF
	i=0
	for slave in ${bond0_slaves} ; do
		((i++))
		cat >>"${dir}/ifcfg-${bondA}" <<-EOF
			BONDING_SLAVE_${i}='$slave'
		EOF
	done
	if test "X$bond0_slave_ifcfg" = "Xyes" ; then
		for slave in ${bond0_slaves} ; do
			cat >"${dir}/ifcfg-${slave}" <<-EOF
				STARTMODE='hotplug'
				BOOTPROTO='none'
			EOF
		done
	fi

	cat >"${dir}/ifcfg-${vlanB}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ETHERDEVICE='${bondA}'
		#VLAN_ID='${vlanB_id}'
	EOF

	cat >"${dir}/ifcfg-${bridgeA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${bondA}'
	EOF

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
	bold "=== $step: ifreload ${bridgeA} { ${bondA} { ${bond0_slaves} } + ${other1} }, ${bridgeB} { ${vlanB} + ${other2} }"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status $all_interfaces
	print_bridges

	check_device_has_port $bondA $bond0_slaves
	check_device_has_not_port $bridgeA $vlanA
	check_device_has_port $bridgeA $bondA
	check_device_has_port $bridgeB $vlanB

	case ${other_call} in
		link)
			echo "ip link add ${other1} type ${other_type}"
			ip link add ${other1} type ${other_type}
			echo "ip link add ${other2} type ${other_type}"
			ip link add ${other2} type ${other_type}
			;;
		tuntap)
			echo "ip tuntap add ${other1} mode ${other_type}"
			ip tuntap add ${other1} mode ${other_type}
			echo "ip tuntap add ${other2} mode ${other_type}"
			ip tuntap add ${other2} mode ${other_type}
			;;
	esac
	echo "ip link set master ${bridgeA} up dev ${other1}"
	ip link set master ${bridgeA} up dev ${other1} || ((err++))
	echo "ip link set master ${bridgeB} up dev ${other2}"
	ip link set master ${bridgeB} up dev ${other2} || ((err++))

	print_device_status $all_interfaces
	print_bridges

	check_device_has_port $bondA $bond0_slaves
	check_device_has_port $bridgeA $bondA
	check_device_has_not_port $bridgeA $vlanA

	check_device_has_port $bridgeA $other1
	check_device_has_port $bridgeB $vlanB
	check_device_has_port $bridgeB $other2
}

step2()
{
        ##
        ## setup bond vlanB instead of bond as bridge1 port
        ##

	bold "=== $step: ifreload ${bondA} { ${bond0_slaves} }, ${bridgeA} { ${vlanA} + ${other1} }, ${bridgeB} { ${vlanB} + ${other2} }"

	cat >"${dir}/ifcfg-${vlanA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ETHERDEVICE='${bondA}'
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

	print_device_status $all_interfaces
	print_bridges

	check_device_has_port "$bondA" $bond0_slaves
	check_device_has_not_port "$bridgeA" "$bondA"
	check_device_has_port "$bridgeA" "$vlanA" "$other1"
	check_device_has_port "$bridgeB" "$vlanB" "$other2"
}

step3()
{
	##
	## remove bond vlanB from bridgeA ports, but keep vlanB ifcfg file
	##
	bold "=== $step: ifreload ${bondA} { ${bond0_slaves} }, ${bridgeA} { + ${other1} }, ${bridgeB} { ${vlanB} + ${other2} }, ${vlanA}"

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

	print_device_status $all_interfaces
	print_bridges

	check_device_has_port "$bondA" $bond0_slaves
	check_device_has_not_port "$bridgeA" "$bondA"
	check_device_has_not_port "$bridgeA" "$vlanA"
	check_device_has_port "$bridgeA" "$other1"
	check_device_has_port "$bridgeB" "$vlanB" "$other2"
}

step4()
{
	##
	## cleanup unenslaved bond vlanB
	##
	bold "=== $step: ifreload ${bondA} { ${bond0_slaves} }, ${bridgeA} { + ${other1} }, ${bridgeB} { ${vlanB} + ${other2} }"

	rm -f "${dir}/ifcfg-${vlanA}"

	log_device_config $all_interfaces

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status $all_interfaces
	print_bridges

	check_device_has_port "$bondA" $bond0_slaves
	check_device_has_not_port "$bridgeA" "$bondA" "$vlanA"
	check_device_has_port "$bridgeA" "$other1"
	check_device_has_port "$bridgeB" "$vlanB" "$other2"
}

step5()
{
	##
	## create bond vlanB and enslave as bridgeA port again
	##
	echo ""
	echo "=== $step: ifreload ${bondA} { ${bond0_slaves} }, ${bridgeA} { ${vlanA} + ${other1} }, ${bridgeB} { ${vlanB} + ${other2} }"

	cat >"${dir}/ifcfg-${vlanA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ETHERDEVICE='${bondA}'
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

	print_device_status $all_interfaces
	print_bridges

	check_device_has_port "$bondA" $bond0_slaves
	check_device_has_not_port "$bridgeA" "$bondA"
	check_device_has_port "$bridgeA" "$other1" "$vlanA"
	check_device_has_port "$bridgeB" "$vlanB" "$other2"
	check_device_is_link "$vlanA" "$bondA"
}

step5()
{
	##
	## replace bond vlanB bridgeA port with bond and delete bond vlanB again
	##
	bold "=== $step: ifreload ${bondA} { ${bond0_slaves} }, ${bridgeA} { ${bondA} + ${other1} }, ${bridgeB} { ${vlanB} + ${other2} }"

	rm -f "${dir}/ifcfg-${vlanA}"
	cat >"${dir}/ifcfg-${bridgeA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${bondA}'
	EOF

	log_device_config $all_interfaces

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status $all_interfaces
	print_bridges

	check_device_has_port "$bondA" $bond0_slaves
	check_device_has_not_port "$bridgeA" "$vlanA"
	check_device_has_port "$bridgeA" "$other1" "$bondA"
	check_device_has_port "$bridgeB" "$vlanB" "$other2"
}

step6()
{
	##
	## removal of first bond slave from config (it is **not** a hotplugging test)
	##
	bold "=== $step: ifreload ${bondA} { ${bond0_slaves#* } }, ${bridgeA} { ${bondA} + ${other1} }, ${bridgeB} { ${vlanB} + ${other2} }"

	cat > "${dir}/ifcfg-${bondA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BONDING_MASTER='yes'
		BONDING_MODULE_OPTS='${bondA_options}'
	EOF
	i=0
	for slave in ${bond0_slaves#* } ; do
		((i++))
		cat >>"${dir}/ifcfg-${bondA}" <<-EOF
			BONDING_SLAVE_${i}='$slave'
		EOF
	done
	if test "X$bond0_slave_ifcfg" = "Xyes" ; then
		for slave in ${bond0_slaves} ; do
			rm -f "${dir}/ifcfg-${slave}"
		done
		for slave in ${bond0_slaves#* } ; do
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


	print_device_status $all_interfaces
	print_bridges

	for slave in ${bond0_slaves} ; do
		enslaved=no
		for s in ${bond0_slaves#* } ; do
			test "x$s" = "x$slave" && enslaved=yes
		done
		if test $enslaved = yes ; then
			check_device_has_port "$bondA" "$slave"
		else
			check_device_has_not_port "$bondA" "$slave"
		fi
	done

	check_device_has_port "$bridgeA" "$other1" "$bondA"
	check_device_has_port "$bridgeB" "$other2" "$vlanB"
}

step7()
{
	##
	## re-add first bond slave to config (it is **not** a hotplugging test)
	##
	bold "=== $step: ifreload ${bondA} { ${bond0_slaves} }, ${bridgeA} { ${bondA} + ${other1} }, ${bridgeB} { ${vlanB} + ${other2} }"

	cat >"${dir}/ifcfg-${bondA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BONDING_MASTER='yes'
		BONDING_MODULE_OPTS='${bondA_options}'
	EOF
	i=0
	for slave in ${bond0_slaves} ; do
		((i++))
		cat >>"${dir}/ifcfg-${bondA}" <<-EOF
			BONDING_SLAVE_${i}='$slave'
		EOF
	done
	if test "X$bond0_slave_ifcfg" = "Xyes" ; then
		for slave in ${bond0_slaves} ; do
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

	print_device_status $all_interfaces
	print_bridges

	check_device_has_port "$bondA" $bond0_slaves
	check_device_has_not_port "$bridgeA" "$vlanA"
	check_device_has_port "$bridgeA" "$bondA" "$other1"
	check_device_has_port "$bridgeB" "$vlanB" "$other2"
}

step99()
{
	bold "=== $step: cleanup"

	wicked $wdebug ifdown ${bridgeA} ${bridgeB} ${vlanA} ${vlanB} ${bondA} ${bond0_slaves} ${other1} ${other2}
	for dev in ${bridgeA} ${bridgeB} ${vlanA} ${vlanB} ${bondA} ${other1} ${other2} ; do
		ip link delete dev $dev
	done
	rm -f "${dir}/ifcfg-${bridgeB}"
	rm -f "${dir}/ifcfg-${bridgeA}"
	rm -f "${dir}/ifcfg-${vlanA}"
	rm -f "${dir}/ifcfg-${vlanB}"
	rm -f "${dir}/ifcfg-${bondA}"
	for slave in ${bond0_slaves} ; do
		rm -f "${dir}/ifcfg-${slave}"
	done
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
