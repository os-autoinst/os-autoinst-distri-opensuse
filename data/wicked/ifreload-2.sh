#!/bin/bash

pause()
{
        echo -n "Press enter to continue...."
        read
}

case $1 in
        -p) pause=pause ; shift ;;
esac

err=0
dir=${1:-"/etc/sysconfig/network"}

dev=${2:-eth3}
brx=${3:-br3}
tap=${4:-tap3}

test "X${dir}" != "X" -a -d "${dir}" || exit 2
test "X${dev}" != "X" -a -d "/sys/class/net/${dev}" || exit 2

log='--debug all --log-target syslog'
#set -x

step1()
{
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

	wicked ${log} ifup all

	wicked ${log} ifstatus ${brx} ${dev} ${tap}
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

	wicked ${log} ifreload all

	wicked ${log} ifstatus ${brx} ${dev} ${tap}
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

	wicked ${log} ifreload all
	ip tuntap add ${tap} mode tap
	ip link set master ${brx} up dev ${tap}

	wicked ${log} ifstatus ${brx} ${dev} ${tap}
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

	wicked ${log} ifreload all

	wicked ${log} ifstatus ${brx} ${dev} ${tap}
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

	wicked ${log} ifdown ${brx} ${dev}
	rm -f "${dir}/ifcfg-${brx}"
	rm -f "${dir}/ifcfg-${dev}"
	ip link delete ${tap}
	ip link delete ${brx}
	wicked ${log} ifstatus all
	echo "==================================="
}

step=0
cleanup ; $pause ; ((step++))
step1   ; $pause ; ((step++))
step2   ; $pause ; ((step++))
step3   ; $pause ; ((step++))
step4   ; $pause ; ((step++))
cleanup ; $pause ; ((step++))

echo ""
echo "=== STATUS: finished with $err errors"
exit $err
