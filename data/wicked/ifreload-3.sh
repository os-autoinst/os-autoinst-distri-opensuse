#!/bin/bash

pause()
{
	test "X$pause" = X && return
	echo -n "Press enter to continue...."
	read
}

show_bridges()
{
        for br in $(ip -o link show type bridge | awk -F': ' '{print $2}'); do
                echo -n "bridge:$br {"
                bridge link | grep "master $br" | awk -F': ' '{print $2}' | xargs echo -n
                echo "}"
        done

}

unset wdebug
unset cprep
unset only
while test $# -gt 0 ; do
        case $1 in
        -p) pause=yes ;;
        -d) wdebug='--debug all --log-level debug2 --log-target syslog::perror' ;;
	-s) shift ; only="$1" ;;
	-c) cprep=yes ;;
        -*) exit 2 ;;
        *)  break ;;
        esac
        shift
done

err=0
dir=${1:-"/etc/sysconfig/network"}

test "X${dir}" != "X" -a -d "${dir}" || exit 2

bond_master="bond0"
bond_slaves=${bond_slaves:-"eth1 eth2"}
bond_options=${bond_options:-"mode=802.3ad miimon=100"}
bond_slave_ifcfg=no

vlan_tag1="2140"
vlan_tag2="2144"
bond_vlan1="${bond_master}.${vlan_tag1}"
bond_vlan2="${bond_master}.${vlan_tag2}"
bridge1="br40"
bridge2="br44"

other_call="tuntap"
other_type="tap"
other1="tap40"
other2="tap44"

#set -x

step1()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	##
	## setup bond as bridge1 port
	##
	echo ""
	echo "=== $step: ifreload ${bridge1} { ${bond_master} { ${bond_slaves} } + ${other1} }, ${bridge2} { ${bond_vlan2} + ${other2} }"

	cat >"${dir}/ifcfg-${bond_master}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BONDING_MASTER='yes'
		BONDING_MODULE_OPTS='${bond_options}'
	EOF
	i=0
	for slave in ${bond_slaves} ; do
		((i++))
		cat >>"${dir}/ifcfg-${bond_master}" <<-EOF
			BONDING_SLAVE_${i}='$slave'
		EOF
	done
	if test "X$bond_slave_ifcfg" = "Xyes" ; then
		for slave in ${bond_slaves} ; do
			cat >"${dir}/ifcfg-${slave}" <<-EOF
				STARTMODE='hotplug'
				BOOTPROTO='none'
			EOF
		done
	fi

	cat >"${dir}/ifcfg-${bond_vlan2}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ETHERDEVICE='${bond_master}'
		#VLAN_ID='${vlan_tag2}'
	EOF

	# vlan1 is untagged pvid on bond
	cat >"${dir}/ifcfg-${bridge1}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${bond_master}'
	EOF

	# vlan2 is a tagged vlan on bond
	cat >"${dir}/ifcfg-${bridge2}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${bond_vlan2}'
	EOF

	wicked show-config > "config-step-${step}.xml"
	#wicked show-policy > "policy-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload all

	case ${other_call} in
	link)
	    ip link add ${other1} type ${other_type}
	    ip link add ${other2} type ${other_type}
	    ;;
	tuntap)
	    ip tuntap add ${other1} mode ${other_type}
	    ip tuntap add ${other2} mode ${other_type}
	    ;;
	esac
	ip link set master ${bridge1} up dev ${other1} || ((err++))
	ip link set master ${bridge2} up dev ${other2} || ((err++))

	wicked ifstatus all
	for dev in ${bond_slaves} ${bond_master} ; do
		ip -d a s dev ${dev} || ((err++))
	done
	ip -d a s dev ${bond_vlan1}  && ((err++))
	for dev in ${bond_vlan2} ${other1} ${other2} ${bridge1} ${bridge2} ; do
		ip -d a s dev ${dev} || ((err++))
	done
	show_bridges

	for slave in ${bond_slaves} ; do
		if ! ip a s dev ${slave} | grep -qs "master ${bond_master}" ; then
			echo "ERROR: ${slave} is not enslaved into ${bond_master}"
			((err++))
		fi
	done

	if ! ip a s dev ${bond_master} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${bond_master} is not enslaved into ${bridge1}"
		((err++))
	fi
	if ip a s dev ${bond_vlan1} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${bond_vlan1} is enslaved into ${bridge1}"
		((err++))
	fi
	if ! ip a s dev ${other1} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${other1} is not enslaved into ${bridge1}"
		((err++))
	fi

	if ! ip a s dev ${bond_vlan2} | grep -qs "master ${bridge2}" ; then
		echo "ERROR: ${bond_vlan2} is not enslaved into ${bridge2}"
		((err++))
	fi
	if ! ip a s dev ${other2} | grep -qs "master ${bridge2}" ; then
		echo "ERROR: ${other2} is not enslaved into ${bridge2}"
		((err++))
	fi

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	##
	## setup bond vlan1 instead of bond as bridge1 port
	##
	echo ""
	echo "=== $step: ifreload ${bond_master} { ${bond_slaves} }, ${bridge1} { ${bond_vlan1} + ${other1} }, ${bridge2} { ${bond_vlan2} + ${other2} }"

	cat >"${dir}/ifcfg-${bond_vlan1}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ETHERDEVICE='${bond_master}'
		#VLAN_ID='${vlan_tag1}'
	EOF

	cat >"${dir}/ifcfg-${bridge1}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${bond_vlan1}'
	EOF

	wicked show-config > "config-step-${step}.xml"
	#wicked show-policy > "policy-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload all

	wicked ifstatus all
	for dev in ${bond_slaves} ${bond_master} ; do
		ip -d a s dev ${dev} || ((err++))
	done
	ip -d a s dev ${bond_vlan1}  || ((err++))
	for dev in ${bond_vlan2} ${other1} ${other2} ${bridge1} ${bridge2} ; do
		ip -d a s dev ${dev} || ((err++))
	done
	show_bridges

	for slave in ${bond_slaves} ; do
		if ! ip a s dev ${slave} | grep -qs "master ${bond_master}" ; then
			echo "ERROR: ${slave} is not enslaved into ${bond_master}"
			((err++))
		fi
	done

	if ip a s dev ${bond_master} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${bond_master} is enslaved into ${bridge1}"
		((err++))
	fi
	if ! ip a s dev ${bond_vlan1} | grep -qs "master ${bridge1} " ; then
		echo "ERROR: bond0.2140 is not enslaved into ${bridge1}"
		((err++))
	fi
	if ! ip a s dev ${other1} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${other1} is not enslaved into ${bridge1}"
		((err++))
	fi

	if ! ip a s dev ${bond_vlan2} | grep -qs "master ${bridge2}" ; then
		echo "ERROR: bond0.2144 is not enslaved into ${bridge2}"
		((err++))
	fi
	if ! ip a s dev ${other2} | grep -qs "master ${bridge2}" ; then
		echo "ERROR: ${other2} is not enslaved into ${bridge2}"
		((err++))
	fi

	echo ""
	echo "=== step $step: finished with $err errors"
}

step3()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	##
	## remove bond vlan1 from bridge1 ports, but keep vlan1 ifcfg file
	##
	echo ""
	echo "=== $step: ifreload ${bond_master} { ${bond_slaves} }, ${bridge1} { + ${other1} }, ${bridge2} { ${bond_vlan2} + ${other2} }, ${bond_vlan1}"

	cat >"${dir}/ifcfg-${bridge1}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS=''
	EOF

	wicked show-config > "config-step-${step}.xml"
	#wicked show-policy > "policy-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload all

	wicked ifstatus all
	for dev in ${bond_slaves} ${bond_master} ; do
		ip -d a s dev ${dev} || ((err++))
	done
	ip -d a s dev ${bond_vlan1}  || ((err++))
	for dev in ${bond_vlan2} ${other1} ${other2} ${bridge1} ${bridge2} ; do
		ip -d a s dev ${dev} || ((err++))
	done
	show_bridges

	for slave in ${bond_slaves} ; do
		if ! ip a s dev ${slave} | grep -qs "master ${bond_master}" ; then
			echo "ERROR: ${slave} is not enslaved into ${bond_master}"
			((err++))
		fi
	done

	if ip a s dev ${bond_master} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${bond_master} is enslaved into ${bridge1}"
		((err++))
	fi
	if ip a s dev ${bond_vlan1} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${bond_vlan1} is enslaved into ${bridge1}"
		((err++))
	fi
	if ! ip a s dev ${other1} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${other1} is not enslaved into ${bridge1}"
		((err++))
	fi

	if ! ip a s dev ${bond_vlan2} | grep -qs "master ${bridge2}" ; then
		echo "ERROR: ${bond_vlan2} is not enslaved into ${bridge2}"
		((err++))
	fi
	if ! ip a s dev ${other2} | grep -qs "master ${bridge2}" ; then
		echo "ERROR: ${other2} is not enslaved into ${bridge2}"
		((err++))
	fi

	echo ""
	echo "=== step $step: finished with $err errors"
}

step4()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	##
	## cleanup unenslaved bond vlan1
	##
	echo ""
	echo "=== $step: ifreload ${bond_master} { ${bond_slaves} }, ${bridge1} { + ${other1} }, ${bridge2} { ${bond_vlan2} + ${other2} }"

	rm -f "${dir}/ifcfg-${bond_vlan1}"

	wicked show-config > "config-step-${step}.xml"
	#wicked show-policy > "policy-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload all

	wicked ifstatus all
	for dev in ${bond_slaves} ${bond_master} ; do
		ip -d a s dev ${dev} || ((err++))
	done
	ip -d a s dev ${bond_vlan1}  && ((err++))
	for dev in ${bond_vlan2} ${other1} ${other2} ${bridge1} ${bridge2} ; do
		ip -d a s dev ${dev} || ((err++))
	done
	show_bridges

	for slave in ${bond_slaves} ; do
		if ! ip a s dev ${slave} | grep -qs "master ${bond_master}" ; then
			echo "ERROR: ${slave} is not enslaved into ${bond_master}"
			((err++))
		fi
	done

	if ip a s dev ${bond_master} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${bond_master} is enslaved into ${bridge1}"
		((err++))
	fi
	if ip a s dev ${bond_vlan1} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${bond_vlan1} is enslaved into ${bridge1}"
		((err++))
	fi
	if ! ip a s dev ${other1} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${other1} is not enslaved into ${bridge1}"
		((err++))
	fi

	if ! ip a s dev ${bond_vlan2} | grep -qs "master ${bridge2}" ; then
		echo "ERROR: ${bond_vlan2} is not enslaved into ${bridge2}"
		((err++))
	fi
	if ! ip a s dev ${other2} | grep -qs "master ${bridge2}" ; then
		echo "ERROR: ${other2} is not enslaved into ${bridge2}"
		((err++))
	fi

	echo ""
	echo "=== step $step: finished with $err errors"
}

step5()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	##
	## create bond vlan1 and enslave as bridge1 port again
	##
	echo ""
	echo "=== $step: ifreload ${bond_master} { ${bond_slaves} }, ${bridge1} { ${bond_vlan1} + ${other1} }, ${bridge2} { ${bond_vlan2} + ${other2} }"

	cat >"${dir}/ifcfg-${bond_vlan1}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ETHERDEVICE='${bond_master}'
		#VLAN_ID='${vlan_tag1}'
	EOF

	cat >"${dir}/ifcfg-${bridge1}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${bond_vlan1}'
	EOF

	wicked show-config > "config-step-${step}.xml"
	#wicked show-policy > "policy-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload all

	wicked ifstatus all
	for dev in ${bond_slaves} ${bond_master} ; do
		ip -d a s dev ${dev} || ((err++))
	done
	ip -d a s dev ${bond_vlan1}  || ((err++))
	for dev in ${bond_vlan2} ${other1} ${other2} ${bridge1} ${bridge2} ; do
		ip -d a s dev ${dev} || ((err++))
	done
	show_bridges

	for slave in ${bond_slaves} ; do
		if ! ip a s dev ${slave} | grep -qs "master ${bond_master}" ; then
			echo "ERROR: ${slave} is not enslaved into ${bond_master}"
			((err++))
		fi
	done

	if ip a s dev ${bond_master} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${bond_master} is enslaved into ${bridge1}"
		((err++))
	fi
	if ! ip a s dev ${bond_vlan1} | grep -qs "master ${bridge1} " ; then
		echo "ERROR: bond0.2140 is not enslaved into ${bridge1}"
		((err++))
	fi
	if ! ip a s dev ${other1} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${other1} is not enslaved into ${bridge1}"
		((err++))
	fi

	if ! ip a s dev ${bond_vlan2} | grep -qs "master ${bridge2}" ; then
		echo "ERROR: bond0.2144 is not enslaved into ${bridge2}"
		((err++))
	fi
	if ! ip a s dev ${other2} | grep -qs "master ${bridge2}" ; then
		echo "ERROR: ${other2} is not enslaved into ${bridge2}"
		((err++))
	fi

	echo ""
	echo "=== step $step: finished with $err errors"
}

step5()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	##
	## replace bond vlan1 bridge1 port with bond and delete bond vlan1 again
	##
	echo ""
	echo "=== $step: ifreload ${bond_master} { ${bond_slaves} }, ${bridge1} { ${bond_vlan1} + ${other1} }, ${bridge2} { ${bond_vlan2} + ${other2} }"

	rm -f "${dir}/ifcfg-${bond_vlan1}"
	cat >"${dir}/ifcfg-${bridge1}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${bond_master}'
	EOF

	wicked show-config > "config-step-${step}.xml"
	#wicked show-policy > "policy-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload all

	wicked ifstatus all
	for dev in ${bond_slaves} ${bond_master} ; do
		ip -d a s dev ${dev} || ((err++))
	done
	ip -d a s dev ${bond_vlan1}  && ((err++))
	for dev in ${bond_vlan2} ${other1} ${other2} ${bridge1} ${bridge2} ; do
		ip -d a s dev ${dev} || ((err++))
	done
	show_bridges

	for slave in ${bond_slaves} ; do
		if ! ip a s dev ${slave} | grep -qs "master ${bond_master}" ; then
			echo "ERROR: ${slave} is not enslaved into ${bond_master}"
			((err++))
		fi
	done

	if ! ip a s dev ${bond_master} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${bond_master} is enslaved into ${bridge1}"
		((err++))
	fi
	if ip a s dev ${bond_vlan1} | grep -qs "master ${bridge1} " ; then
		echo "ERROR: bond0.2140 is not enslaved into ${bridge1}"
		((err++))
	fi
	if ! ip a s dev ${other1} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${other1} is not enslaved into ${bridge1}"
		((err++))
	fi

	if ! ip a s dev ${bond_vlan2} | grep -qs "master ${bridge2}" ; then
		echo "ERROR: bond0.2144 is not enslaved into ${bridge2}"
		((err++))
	fi
	if ! ip a s dev ${other2} | grep -qs "master ${bridge2}" ; then
		echo "ERROR: ${other2} is not enslaved into ${bridge2}"
		((err++))
	fi

	echo ""
	echo "=== step $step: finished with $err errors"
}

step6()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	##
	## removal of first bond slave from config (it is **not** a hotplugging test)
	##
	echo ""
	echo "=== $step: ifreload ${bond_master} { ${bond_slaves#* } }, ${bridge1} { ${bond_vlan1} + ${other1} }, ${bridge2} { ${bond_vlan2} + ${other2} }"

	cat >"${dir}/ifcfg-${bond_master}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BONDING_MASTER='yes'
		BONDING_MODULE_OPTS='${bond_options}'
	EOF
	i=0
	for slave in ${bond_slaves#* } ; do
		((i++))
		cat >>"${dir}/ifcfg-${bond_master}" <<-EOF
			BONDING_SLAVE_${i}='$slave'
		EOF
	done
	if test "X$bond_slave_ifcfg" = "Xyes" ; then
		for slave in ${bond_slaves} ; do
			rm -f "${dir}/ifcfg-${slave}"
		done
		for slave in ${bond_slaves#* } ; do
			cat >"${dir}/ifcfg-${slave}" <<-EOF
				STARTMODE='hotplug'
				BOOTPROTO='none'
			EOF
		done
	fi

	wicked show-config > "config-step-${step}.xml"
	#wicked show-policy > "policy-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload all

	wicked ifstatus all
	for dev in ${bond_slaves} ${bond_master} ; do
		ip -d a s dev ${dev} || ((err++))
	done
	ip -d a s dev ${bond_vlan1}  && ((err++))
	for dev in ${bond_vlan2} ${other1} ${other2} ${bridge1} ${bridge2} ; do
		ip -d a s dev ${dev} || ((err++))
	done
	show_bridges

	for slave in ${bond_slaves} ; do
		enslaved=no
		for s in ${bond_slaves#* } ; do
			test "x$s" = "x$slave" && enslaved=yes
		done
		if test $enslaved = yes ; then
			if ! ip a s dev ${slave} | grep -qs "master ${bond_master}" ; then
				echo "ERROR: ${slave} is not enslaved into ${bond_master}"
				((err++))
			fi
		else
			if ip a s dev ${slave} | grep -qs "master ${bond_master}" ; then
				echo "ERROR: ${slave} is enslaved into ${bond_master}"
				((err++))
			fi
		fi
	done

	if ! ip a s dev ${bond_master} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${bond_master} is enslaved into ${bridge1}"
		((err++))
	fi
	if ip a s dev ${bond_vlan1} | grep -qs "master ${bridge1} " ; then
		echo "ERROR: bond0.2140 is not enslaved into ${bridge1}"
		((err++))
	fi
	if ! ip a s dev ${other1} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${other1} is not enslaved into ${bridge1}"
		((err++))
	fi

	if ! ip a s dev ${bond_vlan2} | grep -qs "master ${bridge2}" ; then
		echo "ERROR: bond0.2144 is not enslaved into ${bridge2}"
		((err++))
	fi
	if ! ip a s dev ${other2} | grep -qs "master ${bridge2}" ; then
		echo "ERROR: ${other2} is not enslaved into ${bridge2}"
		((err++))
	fi

	echo ""
	echo "=== step $step: finished with $err errors"
}

step7()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	##
	## re-add first bond slave to config (it is **not** a hotplugging test)
	##
	echo ""
	echo "=== $step: ifreload ${bond_master} { ${bond_slaves} }, ${bridge1} { ${bond_vlan1} + ${other1} }, ${bridge2} { ${bond_vlan2} + ${other2} }"

	cat >"${dir}/ifcfg-${bond_master}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BONDING_MASTER='yes'
		BONDING_MODULE_OPTS='${bond_options}'
	EOF
	i=0
	for slave in ${bond_slaves} ; do
		((i++))
		cat >>"${dir}/ifcfg-${bond_master}" <<-EOF
			BONDING_SLAVE_${i}='$slave'
		EOF
	done
	if test "X$bond_slave_ifcfg" = "Xyes" ; then
		for slave in ${bond_slaves} ; do
			cat >"${dir}/ifcfg-${slave}" <<-EOF
				STARTMODE='hotplug'
				BOOTPROTO='none'
			EOF
		done
	fi

	wicked show-config > "config-step-${step}.xml"
	#wicked show-policy > "policy-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload all

	wicked ifstatus all
	for dev in ${bond_slaves} ${bond_master} ; do
		ip -d a s dev ${dev} || ((err++))
	done
	ip -d a s dev ${bond_vlan1}  && ((err++))
	for dev in ${bond_vlan2} ${other1} ${other2} ${bridge1} ${bridge2} ; do
		ip -d a s dev ${dev} || ((err++))
	done
	show_bridges

	for slave in ${bond_slaves} ; do
		if ! ip a s dev ${slave} | grep -qs "master ${bond_master}" ; then
			echo "ERROR: ${slave} is not enslaved into ${bond_master}"
			((err++))
		fi
	done

	if ! ip a s dev ${bond_master} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${bond_master} is enslaved into ${bridge1}"
		((err++))
	fi
	if ip a s dev ${bond_vlan1} | grep -qs "master ${bridge1} " ; then
		echo "ERROR: bond0.2140 is not enslaved into ${bridge1}"
		((err++))
	fi
	if ! ip a s dev ${other1} | grep -qs "master ${bridge1}" ; then
		echo "ERROR: ${other1} is not enslaved into ${bridge1}"
		((err++))
	fi

	if ! ip a s dev ${bond_vlan2} | grep -qs "master ${bridge2}" ; then
		echo "ERROR: bond0.2144 is not enslaved into ${bridge2}"
		((err++))
	fi
	if ! ip a s dev ${other2} | grep -qs "master ${bridge2}" ; then
		echo "ERROR: ${other2} is not enslaved into ${bridge2}"
		((err++))
	fi

	echo ""
	echo "=== step $step: finished with $err errors"
}

cleanup()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	echo ""
	echo "=== $step: cleanup"

	wicked ifdown ${bridge1} ${bridge2} ${bond_vlan1} ${bond_vlan2} ${bond_master} ${bond_slaves} ${other1} ${other2}
	for dev in ${bridge1} ${bridge2} ${bond_vlan1} ${bond_vlan2} ${bond_master} ${other1} ${other2} ; do
		ip link delete dev $dev
	done
	rm -f "${dir}/ifcfg-${bridge2}"
	rm -f "${dir}/ifcfg-${bridge1}"
	rm -f "${dir}/ifcfg-${bond_vlan1}"
	rm -f "${dir}/ifcfg-${bond_vlan2}"
	rm -f "${dir}/ifcfg-${bond_master}"
	for slave in ${bond_slaves} ; do
		rm -f "${dir}/ifcfg-${slave}"
	done
	echo "-----------------------------------"
	ps  ax | grep /usr/.*/wicked | grep -v grep
	echo "-----------------------------------"
	wicked ifstatus all
	echo "-----------------------------------"
	show_bridges
	echo "-----------------------------------"
	ls -l /var/run/wicked/nanny/
	echo "==================================="
}

step=0
errs=0
cleanup ; pause ; let step++ ; let errs+=$err ; err=0
step1   ; pause ; let step++ ; let errs+=$err ; err=0
step2   ; pause ; let step++ ; let errs+=$err ; err=0
step3   ; pause ; let step++ ; let errs+=$err ; err=0
step4   ; pause ; let step++ ; let errs+=$err ; err=0
step5   ; pause ; let step++ ; let errs+=$err ; err=0
step6   ; pause ; let step++ ; let errs+=$err ; err=0
step7   ; pause ; let step++ ; let errs+=$err ; err=0
cleanup ; pause ; let step++ ; let errs+=$err ; err=0

echo ""
echo "=== STATUS: finished with $errs errors"
exit $errs
