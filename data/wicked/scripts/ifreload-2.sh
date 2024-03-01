#!/bin/bash

pause()
{
	test "X$pause" = X && return
	echo -n "Press enter to continue...."
	read
}

unset wdebug
unset cprep
unset only
while test $# -gt 0 ; do
	case $1 in
	-p) pause=yes ;;
	-d) wdebug='--debug all --log-level debug2 --log-target syslog' ;;
	-s) shift ; only="$1" ;;
	-c) cprep=yes ;;
	-*) exit 2 ;;
	*)  break ;;
	esac
	shift
done

err=0
dir=${dir:-"/etc/sysconfig/network"}
cfg=${dir:+--ifconfig "compat:suse:$dir"}

test "X${dir}" != "X" -a -d "${dir}" || exit 2

dev=${dev:-eth3}
brx=${brx:-br3}
tap=${tap:-tap3}

# permit to override above variables
config="${0//.sh/.conf}"
test -r "$config" && . "$config"

test "X${dev}" != "X" -a -d "/sys/class/net/${dev}" || exit 2

#set -x

step1()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	echo ""
	echo "=== $step: ifup ${brx} { ${dev} }"

	cat >"${dir}/ifcfg-${brx}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BRIDGE='yes'
		BRIDGE_STP='off'
		BRIDGE_FORWARDDELAY='0'
		BRIDGE_PORTS='${dev}'
		# ignore br carrier
	EOF

	wicked show-config > "config-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifup $cfg all

	wicked ifstatus $cfg ${brx} ${dev} ${tap}
	ip a s dev ${brx}
	ip a s dev ${dev}

	if ! ip a s dev ${dev} | grep -qs "master ${brx}" ; then
		echo "ERROR: ${dev} is not enslaved into ${brx}"
		((err++))
	fi
}

step2()
{
	echo ""
	echo "=== $step: ifreload ${brx} { }"

	# change bridge to not use any port + ifreload
	cat >"${dir}/ifcfg-${brx}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BRIDGE='yes'
		BRIDGE_STP='off'
		BRIDGE_FORWARDDELAY='0'
		BRIDGE_PORTS=''
		# ignore br carrier
		LINK_REQUIRED='no'
	EOF

	wicked show-config > "config-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload $cfg all

	wicked ifstatus $cfg ${brx} ${dev} ${tap}
	ip a s dev ${brx}
	ip a s dev ${dev}

	if ip a s dev ${dev} | grep -qs "master ${brx}" ; then
		echo "ERROR: ${dev} is still enslaved into ${brx}"
		((err++))
	fi
}

step3()
{
	echo ""
	echo "=== $step: ifreload ${brx} { ${dev} + ${tap} }"

	cat >"${dir}/ifcfg-${brx}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BRIDGE='yes'
		BRIDGE_STP='off'
		BRIDGE_FORWARDDELAY='0'
		BRIDGE_PORTS='${dev}'
		# ignore br carrier
		LINK_REQUIRED='no'
	EOF

	wicked show-config > "config-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload $cfg all
	ip tuntap add ${tap} mode tap
	ip link set master ${brx} up dev ${tap}

	wicked ifstatus $cfg ${brx} ${dev} ${tap}
	ip a s dev ${brx}
	ip a s dev ${dev}
	ip a s dev ${tap}

	if ! ip a s dev ${dev} | grep -qs "master ${brx}" ; then
		echo "ERROR: ${dev} is not enslaved into ${brx}"
		((err++))
	fi
	if ! ip a s dev ${tap} | grep -qs "master ${brx}" ; then
		echo "ERROR: ${tap} is not enslaved into ${brx}"
		((err++))
	fi
}

step4()
{
	echo ""
	echo "=== $step: ifreload ${brx} { + ${tap} }"

	cat >"${dir}/ifcfg-${brx}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BRIDGE='yes'
		BRIDGE_STP='off'
		BRIDGE_FORWARDDELAY='0'
		BRIDGE_PORTS=''
		# ignore br carrier
		LINK_REQUIRED='no'
	EOF

	wicked show-config > "config-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload $cfg all

	wicked ifstatus $cfg ${brx} ${dev} ${tap}
	ip a s dev ${brx}
	ip a s dev ${dev}
	ip a s dev ${tap}

	if ip a s dev ${dev} | grep -qs "master ${brx}" ; then
		echo "ERROR: ${dev} is still enslaved into ${brx}"
		((err++))
	fi
	if ! ip a s dev ${tap} | grep -qs "master ${brx}" ; then
		echo "ERROR: ${tap} is not enslaved into ${brx}"
		((err++))
	fi
}

cleanup()
{
	echo ""
	echo "=== $step: cleanup"

	wicked $wdebug ifdown ${brx} ${dev}
	rm -f "${dir}/ifcfg-${brx}"
	rm -f "${dir}/ifcfg-${dev}"
	ip link delete ${tap}
	ip link delete ${brx}
	wicked ifstatus $cfg all
	echo "==================================="
}

step=0
errs=0
cleanup ; pause ; let step++ ; let errs+=$err ; err=0
step1   ; pause ; let step++ ; let errs+=$err ; err=0
step2   ; pause ; let step++ ; let errs+=$err ; err=0
step3   ; pause ; let step++ ; let errs+=$err ; err=0
step4   ; pause ; let step++ ; let errs+=$err ; err=0
cleanup ; pause ; let step++ ; let errs+=$err ; err=0

echo ""
echo "=== STATUS: finished $step step(s) with $errs errors"
exit $errs
