#!/bin/bash
#
# Usage:
# ./ifrename-1.sh --apply y2lan eth0 dyn0 && ./ifrename-1.sh --apply y2lan dyn0 eth0
# ./ifrename-1.sh --apply ifup  eth0 dyn0 && ./ifrename-1.sh --apply ifup  dyn0 eth0
#
# Default varant is '--apply y2lan'. Experimental (doesn't work on 0.6.64 nor 0.6.68 + fix):
# ./ifrename-1.sh --apply ifreload eth0 dyn0 && ./ifrename-1.sh --apply ifreload dyn0 eth0
#
# Optional argument: '--match <mac|bus>' to generate and initial rule.
#
#
# default, MAC based persistent name rule is:
#  SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="XX:XX:XX:XX:XX:XX", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth0"
#
# bus id based persistent name rule is:
#  SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", KERNELS=="ZZZZ:ZZ:ZZ.F", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth0"
#
# See `udevadm info -q all -p /sys/class/net/eth0`    (base properties)
# and `udevadm info -q all -p /sys/class/net/eth0 -a` (attribute walk)
#
# We actually don't care in this _TEST_ script about rule lock files,
# see also /usr/lib/udev/rule_generator.functions which is using
#     mkdir /run/udev/.lock-70-persistent-net.rules
# loop.
#
name_rule="/etc/udev/rules.d/70-persistent-net.rules"
sysfs_net="/sys/class/net"
ifcfg_dir="/etc/sysconfig/network"
conf_file="${0/.sh/.conf}"
wdebug='--debug all --log-target syslog'

fail()
{
	local ret="$1" ; shift
	echo >&2 "FAILURE: $*"
	exit $(($ret)) 2>/dev/null
}

apply=y2lan
match=mac
old_ifname=""
new_ifname=""
if test $# -eq 0 -a -r "$conf_file" ; then
	.  "$conf_file" || exit 2
else
	while test $# -gt 0 ; do
		case $1 in
		--apply) shift ; apply="$1" ; shift ;;
		--match) shift ; match="$1" ; shift ;;
		-*) fail 2 "unknown parameter $1"   ;;
		*)  break ;;
		esac
	done
	old_ifname="$1"
	new_ifname="$2"
fi

old_iface="${sysfs_net}/${old_ifname}"
new_iface="${sysfs_net}/${new_ifname}"
old_ifcfg="${ifcfg_dir}/ifcfg-${old_ifname}"
new_ifcfg="${ifcfg_dir}/ifcfg-${new_ifname}"

test "X$apply" = "X" -o "X$old_ifname" = "X" -o "X$new_ifname" = "X" \
				&& fail 2 "missed parameters or config file"

test -d "${sysfs_net}"		|| fail 2 "sysfs dir '${sysfs_net}' missed"
test -d "${ifcfg_dir}"          || fail 2 "ifcfg dir '${ifcfg_dir}' missed"

test -f "${old_ifcfg}"          || fail 2 "ifcfg file '${old_ifcfg}' missed"
test -d "${old_iface}"          || fail 2 "interface '${old_ifname}' missed"

test -f "${new_ifcfg}"          && fail 2 "ifcfg file '${new_ifcfg}' exists"
test -d "${new_iface}"          && fail 2 "interface '${new_ifname}' exists"

test -f "${name_rule}"          || fail 2 "persistent name rule file '${name_rule}' missed"
rule=$(grep -E "^SUBSYSTEM.*NAME=\"${new_ifname}\"" -- "${name_rule}")
if test "X${rule}" != "X" ; then
	fail 2 "persistent name rule for '${new_ifname}' exists"
fi

rule=$(grep -E "^SUBSYSTEM.*NAME=\"${old_ifname}\"" -- "${name_rule}")
if test "X${rule}" = "X" ; then
	case $match in
	mac)
		mac=$(wicked ethtool "$old_ifname" --get-permanent-address 2>/dev/null)
		test "X$mac" = "X" && mac=$(ethtool -P "$old_ifname" 2>/dev/null)
		mac=${mac#*address: }
		test "X$mac" = "X" && \
		read mac < "$old_iface/address"
		read dev_id < "$old_iface/dev_id"
		read iftype < "$old_iface/type"
		test ${#mac} -eq 17 \
				|| fail 2 "cannot generate mising persistent name rule for '${old_ifname}' missed"

		cat >>"${name_rule}" <<-EOF
		SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="$mac", ATTR{dev_id}=="$dev_id", ATTR{type}=="$iftype", NAME="$old_ifname"
		EOF
		rule=$(grep -E "^SUBSYSTEM.*NAME=\"${old_ifname}\"" -- "${name_rule}")
		;;
	bus)
		bus=$(cd -P "/sys/class/net/$old_ifname/device" 2>/dev/null && echo "${PWD##*/}")
		test "X$bus" = "X" \
				&& fail 2 "persistent name rule for '${old_ifname}' missed"
		read dev_id < "$old_iface/dev_id"
		read iftype < "$old_iface/type"
		cat >>"${name_rule}" <<-EOF
		SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", KERNELS=="$bus", ATTR{dev_id}=="$dev_id", ATTR{type}=="$iftype", NAME="$old_ifname"
		EOF
		rule=$(grep -E "^SUBSYSTEM.*NAME=\"${old_ifname}\"" -- "${name_rule}")
		;;
	*)
		fail 2 "persistent name rule for '${old_ifname}' missed"
		;;
	esac
fi
echo "* udev persistent name rule for $old_ifname:"
grep -E "^SUBSYSTEM.*NAME=\"${old_ifname}\"" -- "${name_rule}"

echo "* wicked config $old_ifname:"
wicked show-config "$old_ifname"
echo "* wicked config $new_ifname:"
wicked show-config "$new_ifname"

echo "* wicked ifstatus $old_ifname:"
wicked ifstatus "$old_ifname"
echo "* wicked ifstatus $new_ifname:"
wicked ifstatus "$new_ifname"


case $apply in
ifup|y2lan)
	# ensure it "was" active
	echo "* ifup $old_ifname:"
	wicked $wdebug ifup "$old_ifname" \
				|| fail 1 "A 'wicked ifup $old_ifname' reports a problem: $?"

	# ifdown to drop the old policy from nanny
	echo "* ifdown $old_ifname (before rename):"
	wicked $wdebug ifdown "$old_ifname"	\
				|| fail 1 "A 'wicked ifdown $old_ifname' reports a problem: $?"
	;;
ifreload)
	# ensure it "was" active
	echo "* wicked ifreload all:"
	wicked $wdebug ifreload all \
				|| fail 1 "A 'wicked ifreload all' reports a problem: $?"

	# set only the link down so rename does not fail -- instead full ifdown
	echo "* set the link down only"
	ip link set down dev "$old_ifname"
	;;
esac

# check if the IFF_UP bit is still set (disallows rename)
echo "* check if $old_ifname is DOWN:"
ifflags=$(cat "${old_iface}/flags" 2>/dev/null)
((ifflags & 0x1))		&& fail 1 "Interface '$old_ifname' is DOWN"

echo "* adjusting rename rule ifname from $old_ifname to $new_ifname:"
sed -i "${name_rule}" \
    -e "/^SUBSYSTEM=.*[ ]NAME=\"${old_ifname}\"/{s/NAME=\"${old_ifname}\"/NAME=\"${new_ifname}\"/;s/KERNEL==\".*\",[ ]*//}" \
				|| fail 1 "Failed to adjust persistent name rule to $new_ifname"

echo "* adjusted rename rule using new ifname $new_ifname:"
grep -E "^SUBSYSTEM.*NAME=\"${new_ifname}\"" -- "${name_rule}" \
				|| fail 1 "Failed to adjust persistent name rule to $new_ifname"

echo "* renaming ifcfg-$old_ifname to ifcfg-$new_ifname:"
mv "${old_ifcfg}" "${new_ifcfg}" \
				|| fail 1 "Failed to rename ifcfg-$old_ifname to ifcfg-$new_ifname"

echo "* wicked config $old_ifname:"
wicked show-config "$old_ifname"
echo "* wicked config $new_ifname:"
wicked show-config "$new_ifname"


echo "* reloading udev rule and triggering rename:"
udevadm control --reload				&& \
udevadm trigger --subsystem-match=net --action=add	&& \
udevadm settle			|| fail 1 "Failed to rename interface via udev event trigger"

echo "* wicked ifstatus $old_ifname:"
wicked ifstatus "$old_ifname"
echo "* wicked ifstatus $new_ifname:"
wicked ifstatus "$new_ifname"

test -d "${new_iface}"          || fail 2 "interface '${new_ifname}' missed -- failed rename"
test -d "${old_iface}"          && fail 2 "interface '${old_ifname}' exists"

case $apply in
ifup)
	# ifup new interface now
	echo "* ifup $new_ifname:"
	wicked $wdebug ifup "$new_ifname" \
				|| fail 1 "A 'wicked ifup $new_ifname' reports a problem: $?"
	;;
y2lan)
	# as ifdown has been called before the rename
	# we can ifreload the new ifname (avoids to
	# reload modified but unrelated ifcfg files).
	echo "* ifreload $new_ifname:"
	wicked $wdebug ifreload "$new_ifname" \
				|| fail 1 "A 'wicked ifreload $new_ifname' reports a problem: $?"
	;;

ifreload)
	# ifreload should apply the config changes too
	# and internally ifdown old + ifup new ifname
	# requires old + new ifname list or "all"
	echo "* ifreload $old_ifname $new_ifname"
	wicked $wdebug ifreload "$old_ifname" "$new_ifname" \
				|| fail 1 "A 'wicked ifreload $old_ifname $new_ifname' reports a problem: $?"
	;;
esac
echo "* check if $new_ifname is UP:"
ifflags=$(cat "${new_iface}/flags" 2>/dev/null)
((ifflags & 0x1)) || fail 1 "Interface '$new_ifname' is DOWN"

echo "* wicked ifstatus $old_ifname:"
wicked ifstatus "$old_ifname"
echo "* wicked ifstatus $new_ifname:"
wicked ifstatus "$new_ifname"

echo "* check if $new_ifname is \"up\" in wicked:"
ifstate=""
while read name state crap ; do
	test "X$state" = "X" || ifstate="$state"
done < <(wicked ifstatus --brief "$new_ifname")
test "X$ifstate" = "Xup"	&& \
	echo "SUCCESS: $new_ifname is \"up\"" || \
	fail 1 "Interface '$new_ifname' is not UP in wicked"

