#!/bin/bash

pause()
{
	test "X$pause" = X && return
	echo -n "Press enter to continue...."
	read
}
policy_name2path()
{
        local path="$1"
        path="${path//[_]/__}"
        path="${path//[-]/_m}"
        path="${path//[.]/_d}"
        echo "$path"
}
policy_file()
{
	local name="policy_$1"
	local path=$(policy_name2path "${name}")
	echo "$run/$path.xml"
}
policy_exists()
{
	local file=$(policy_file "$1")
	test -e "$file"
}
device_exists()
{
	test -d "/sys/class/net/$1"
}
device_is_up()
{
	LC_ALL=POSIX ip link show dev "$1" 2>/dev/null | grep -qs "[<,]UP[,>]"
}
device_is_port_of()
{
	local port="$1"
	local master="$2"
	LC_ALL=POSIX ip link show dev "$1" 2>/dev/null | grep -qs "master $master"
}
print_device_status()
{
	echo "# wicked ifstatus $cfg ""$*"
	wicked ifstatus $cfg "$@"
	echo ""

	for dev in "$@"; do
		echo "# ip a s dev $dev"
		ip a s dev $dev
	done
}
check_device_is_up()
{
    if device_is_up "$1" ; then
		echo "WORKS: $1 is up"
	else
		red "ERROR: $1 is NOT up"
		((err++))
	fi
}
check_device_is_down()
{
    if ! device_is_up "$1" ; then
		echo "WORKS: $1 is down"
	else
		red "ERROR: $1 is NOT down"
		((err++))
	fi
}
check_policy_exists()
{
    if policy_exists $1 ; then
		echo "WORKS: policy $1 exists"
	else
		red "ERROR: policy $1 is missing"
		((err++))
	fi
}
check_policy_not_exists()
{
    if ! policy_exists $1 ; then
		echo "WORKS: policy $1 is missing"
	else
		red "ERROR: policy $1 exists"
		((err++))
	fi
}

has_wicked_support()
{
	local cmd=$1
	local arg=$2
	! wicked $cmd $arg |& grep "unrecognized option '$arg'" >/dev/null
}

color() {
    local NC
    local c=$1
    if [ "$use_colors" == "yes" ]; then
        NC="$(tput sgr0)"
        case "$c" in
            red|RED) c="$(tput setaf 1)";;
            green|GREEN) c="$(tput setaf 2)";;
            bold|BOLD) c="$(tput bold)";;
            *);;
        esac
    else
        NC=""; c="";
    fi
    echo "$c$2$NC"
}
bold(){
    color BOLD "$1"
}
red(){
    color RED "$1"
}
green(){
    color GREEN "$1"
}

print_help()
{
    echo " -p               Pause between each teststep"
    echo " -d               Use debug output on wicked calls"
    echo " -l | --list      List all steps"
    echo " -s <func>        Run only the given step"
    echo " --cfg-dir <dir>  Path to ifcfg files (Default: /etc/sysconfig/network)"
    echo " --stop-on-err    Stop execution on first errounous step"
}

wdebug='--log-level info --log-target syslog'
unset cprep
unset only
unset list
unset use_colors
unset stop_on_error
unset dir
[ "$(tput colors)" -ge 8 ] && use_colors=yes
while test $# -gt 0 ; do
	case "$1" in
	-p) pause=yes ;;
	-d) wdebug='--debug all --log-level debug2 --log-target syslog' ;;
	-s) shift ; only="$1" ;;
	--cfg-dir) shift; dir="$1" ;;
	-l|--list) shift; list=yes;;
	--stop-on-err*) shift; stop_on_error=yes;;
	--color) use_colors=yes;;
	-h) print_help; exit 0 ;;
	-*) print_help; exit 2 ;;
	*)  break ;;
esac
shift
done

# permit to override above variables
config="${0//.sh/.conf}"
up_config=$(dirname "$config")/../$(basename "$config")
test -r "$up_config" && . "$up_config"
test -r "$config" && . "$config"

dir=${dir:-"/etc/sysconfig/network"}
cfg=${cfg:---ifconfig "compat:suse:$dir"}
run=${run:-/run/wicked/nanny}

test "X${dir}" != "X" -a -d "${dir}" || exit 2

err=0
step=0
errs=0
steps="$(typeset -f | grep -P -o "^step[0-9]+\s+" | sort -n -k 1.5)"

if [ "$list" = "yes" ]; then
    for func in $steps; do
        echo  " $func"
    done
else
    for func in $steps; do
	    test "X$only" = "X" -o "X$only" = "X$func" || continue
	    echo ""
        step="${func}"; $func "$step"; pause ; ((errs+=$err)) ; err=0
	[ "$stop_on_error" == "yes" ] && [ "$errs" -gt 0 ] && break;
    done

    echo ""
    if [ $errs -gt 0 ]; then
        red "=== STATUS: failed with $errs errors"
    else
        echo "=== STATUS: finished with $errs errors"
    fi
fi

exit $errs
