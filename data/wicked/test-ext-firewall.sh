#!/bin/bash

ifc=${1:-eth1}
zone1=zone-test-1
zone2=zone-test-2
default_zone=$(firewall-cmd --get-default-zone)
ifcfg="/etc/sysconfig/network/ifcfg-$ifc"

function error {
    local msg=${1:? Error message is mandatory}
    local code=${2:-127}

    echo "ERROR: $msg" 1>&2
    exit "$code"
}

function fw_zone_list_ifc {
    local zone=${1:? Function need zone as parameter}
    local permanent=${2}
    local ifcs=$(firewall-cmd $permanent --list-all --zone="$zone" | grep interfaces)
    ifcs=${ifcs#"  interfaces: "}
    echo "$ifcs"
}

function fwp_zone_remove_ifc {
    local zone=${1:? Function need zone as parameter}
    local ifc=${2:? Function need interface as parameter}
    local permanent=${3}

    firewall-cmd $permanent --zone="$zone" --remove-interface="$ifc"
}

function ifcfg_set_zone {
    local ifc=${1:? Function need interface as parameter}
    local zone=${2:? Function need zone as parameter}

    sed -iE '/\s*ZONE=/d' "$ifcfg"
    echo "ZONE=$zone" >> "$ifcfg"
}

function check_ifc_in_zone {
    local ifc=${1:? Function need interface as parameter}
    local zone=${2:? Function need zone as parameter}
    local permanent=${3}

    echo "[line:${BASH_LINENO[0]}] Check: if interface '$ifc' is in zone '$zone' $permanent"

    for i in $(fw_zone_list_ifc "$zone" "$permanent"); do
        [ X"$i" == X"$ifc" ] && return;
    done
    echo "[line:${BASH_LINENO[0]}] ERROR: Missing interface '$ifc' in zone '$zone' $permanent"
    false;
}

function logex {
    echo "[line:${BASH_LINENO[0]}] Exec:  $*"
    "$@"
}

function init {
    set -e

    firewall-cmd --list-all --zone="$zone1" > /dev/null 2>&1 || firewall-cmd --permanent --new-zone="$zone1"
    firewall-cmd --list-all --zone="$zone2" > /dev/null 2>&1 || firewall-cmd --permanent --new-zone="$zone2"
    firewall-cmd --reload

    for zone in "$zone1" "$zone2"; do 
        for i in $(fw_zone_list_ifc "$zone"); do
            fwp_zone_remove_ifc "$zone" "$i"
            fwp_zone_remove_ifc "$zone" "$i" --permanent
        done
    done

    cat > "$ifcfg" << EOT
BOOTPROTO='static'
STARTMODE='auto'
IPADDR=11.22.33.44/24
EOT
    wicked ifup "$ifc"
    check_ifc_in_zone "$ifc" "$default_zone"
}

function test1 {
    set -e

    logex ifcfg_set_zone "$ifc" "$zone1"

    logex wicked ifup "$ifc"
    check_ifc_in_zone "$ifc" "$zone1"
    logex wicked ifdown "$ifc"
    check_ifc_in_zone "$ifc" "$zone1" --permanent
    logex wicked ifup "$ifc"
    check_ifc_in_zone "$ifc" "$zone1"

    logex sed -i '/IPADDR=/c\IPADDR=44.33.22.11/24' "$ifcfg"
    logex wicked ifreload "$ifc"
    check_ifc_in_zone "$ifc" "$zone1"

    logex systemctl restart wicked
    check_ifc_in_zone "$ifc" "$zone1"

    logex systemctl restart wickedd
    check_ifc_in_zone "$ifc" "$zone1"

    logex systemctl restart firewalld
    check_ifc_in_zone "$ifc" "$zone1"
}

function test2 {
    set -e

    logex ifcfg_set_zone "$ifc" "$zone1"
    logex wicked ifup "$ifc"
    check_ifc_in_zone "$ifc" "$zone1"
    check_ifc_in_zone "$ifc" "$zone1" --permanent

    logex ifcfg_set_zone "$ifc" "$zone2"
    logex wicked ifup "$ifc"
    check_ifc_in_zone "$ifc" "$zone2"
    check_ifc_in_zone "$ifc" "$zone2" --permanent
}

function test3 {
    set -e

    logex firewall-cmd --permanent --zone="$zone1" --change-interface="$ifc"
    logex wicked ifup "$ifc"
    check_ifc_in_zone "$ifc" "$zone1"
    
    logex firewall-cmd --permanent --zone="$zone2" --change-interface="$ifc"
    logex wicked ifup "$ifc"
    check_ifc_in_zone "$ifc" "$zone2"
}

function test4 {
    set -e

    logex firewall-cmd --zone="$zone2" --change-interface="$ifc"
    logex firewall-cmd --permanent --zone="$zone2" --change-interface="$ifc"

    logex ifcfg_set_zone "$ifc" "$zone1"
    logex echo "FIREWALL=no" >> "$ifcfg"

    logex wicked ifup "$ifc"
    check_ifc_in_zone "$ifc" "$zone2"
    check_ifc_in_zone "$ifc" "$zone2" --permanent

    logex wicked ifdown "$ifc"
    check_ifc_in_zone "$ifc" "$zone2"
    check_ifc_in_zone "$ifc" "$zone2" --permanent
}

function test5 {
    set -e 

    logex firewall-cmd --zone="$zone1" --change-interface="$ifc"
    logex firewall-cmd --permanent --zone="$zone2" --change-interface="$ifc"

    logex echo "FIREWALL=no" >> "$ifcfg"

    logex wicked ifup "$ifc"
    check_ifc_in_zone "$ifc" "$zone1"
    check_ifc_in_zone "$ifc" "$zone2" --permanent

    logex wicked ifdown "$ifc" 
    check_ifc_in_zone "$ifc" "$zone1"
    check_ifc_in_zone "$ifc" "$zone2" --permanent
}

function test6 {
    set -e 
    
    logex ifcfg_set_zone "$ifc" "$zone1"
    logex wicked ifreload "$ifc"
    check_ifc_in_zone "$ifc" "$zone1"

    logex ifcfg_set_zone "$ifc" "$zone2"
    logex wicked ifreload "$ifc"
    check_ifc_in_zone "$ifc" "$zone2"

    logex ifcfg_set_zone "$ifc" " "
    logex wicked ifreload "$ifc"
    check_ifc_in_zone "$ifc" "$default_zone"
    
    logex ifcfg_set_zone "$ifc" "$zone1"
    logex wicked ifreload "$ifc"
    check_ifc_in_zone "$ifc" "$zone1"
    
    logex sed -iE '/\s*ZONE=/d' "$ifcfg"
    logex wicked ifreload "$ifc"
    check_ifc_in_zone "$ifc" "$default_zone"
}


for t in test1 test2 test3 test4 test5 test6; do
    echo "##########################################################"
    echo "# Run test $t"
    echo "##########################################################"
    logex init
    $t
done
