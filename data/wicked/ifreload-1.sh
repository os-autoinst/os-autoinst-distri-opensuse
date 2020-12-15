#!/bin/bash

err=0
dir=${1:-"/etc/sysconfig/network"}
cfg=${dir:+--ifconfig "compat:suse:$dir"}

test "X${dir}" != "X" -a -d "${dir}" || exit 2

#set -x

step1()
{
	echo ""
	echo "=== 1: ifup brdummy { dummy0 + tap0 }"

	cat >"${dir}/ifcfg-dummy0" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-dummy1" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-brdummy" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='dummy0'
	EOF

	modprobe -qs dummy
	modprobe -qs tap

	wicked ifup $cfg all
	ip tuntap add tap0 mode tap
	ip link set master brdummy up dev tap0

	wicked ifstatus $cfg all
	ip a s dev dummy0
	ip a s dev dummy1
	ip a s dev tap0

	if ip a s dev dummy0 | grep -qs "master .*brdummy" ; then
		if ip a s dev dummy1 | grep -qs "master .*brdummy" ; then
			echo "ERROR: dummy1 is enslaved into brdummy"
			((err))
		fi
	else
		echo "ERROR: dummy0 is not enslaved into brdummy"
		((err))
	fi
	if ! ip a s dev tap0 | grep -qs "master .*brdummy" ; then
		echo "ERROR: tap0 is not enslaved into brdummy"
		((err))
	fi
	if wicked ifstatus $cfg tap0 | grep -qs compat:suse ; then
		echo "ERROR: tap0 has received generated config"
		((err))
	fi
}

step2()
{
	echo ""
	echo "=== 2: ifup brdummy { dummy0 + tap0 } again"

	wicked ifup $cfg all

	wicked ifstatus $cfg all
	ip a s dev dummy0
	ip a s dev dummy1
	ip a s dev tap0

	if ip a s dev dummy0 | grep -qs "master .*brdummy" ; then
		if ip a s dev dummy1 | grep -qs "master .*brdummy" ; then
			echo "ERROR: dummy1 is enslaved into brdummy"
			((err))
		fi
	else
		echo "ERROR: dummy0 is not enslaved into brdummy"
		((err))
	fi
	if ! ip a s dev tap0 | grep -qs "master .*brdummy" ; then
		echo "ERROR: tap0 is not enslaved into brdummy"
		((err))
	fi
	if wicked ifstatus $cfg tap0 | grep -qs compat:suse ; then
		echo "ERROR: tap0 has received generated config"
		((err))
	fi
}

step3()
{
	echo ""
	echo "=== 3: ifreload brdummy { dummy1 + tap0 }"

	# change bridge to use dummy1 instead + ifreload
	cat >"${dir}/ifcfg-brdummy" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='dummy1'
	EOF

	wicked ifreload $cfg all

	wicked ifstatus $cfg all
	ip a s dev dummy0

	if ip a s dev dummy1 | grep -qs "master .*brdummy" ; then
		if ip a s dev dummy0 | grep -qs "master .*brdummy" ; then
			echo "ERROR: dummy0 still enslaved into brdummy"
			((err))
		fi
	else
		echo "ERROR: dummy1 not enslaved into brdummy"
		((err))
	fi
	if ! ip a s dev tap0 | grep -qs "master .*brdummy" ; then
		echo "ERROR: tap0 is not enslaved into brdummy"
		((err))
	fi
	if wicked ifstatus $cfg tap0 | grep -qs compat:suse ; then
		echo "ERROR: tap0 has received generated config"
		((err))
	fi
}

cleanup()
{
	wicked ifdown brdummy dummy0 dummy1 tap0
	rm -f "${dir}/ifcfg-dummy0"
	rm -f "${dir}/ifcfg-dummy1"
	rm -f "${dir}/ifcfg-brdummy"
	ip link delete brdummy
	ip link delete dummy0
	ip link delete dummy1
	ip link delete tap0
	rmmod dummy &>/dev/null
	rmmod tap   &>/dev/null
}

cleanup
step1
step2
step3
cleanup

echo ""
echo "=== STATUS: finished with $err errors"
exit $err
