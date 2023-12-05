#!/bin/bash

replace()
{
	local s=$1
	local d=$2

	grep -rn --exclude replace.sh -E "\\b$s\\b"
	echo "Contiue to replace $s => $d in all: "
	read A

	if [ "$A" == "y" ]; then
		for i in $(grep -rnl --exclude replace.sh -E "\\b$s\\b"); do
			echo sed -Ei 's/\b'"$s"'\b/'"$d"'/g' "$i"
			sed -Ei 's/\b'"$s"'\b/'"$d"'/g' "$i"
		done
	else
		echo "DO NOT REPLACED!!"
	fi
}

replace eth0_ip eth0_ip4
replace "10.0.0.1" "198.18.0.1"

replace eth1_ip eth1_ip4
replace "10.0.1.1" "198.18.1.1"

replace vlan0_ip vlan0_ip4
replace  "10.1.0.1" "198.18.2.1"

replace vlan1_ip vlan1_ip4
replace "10.1.1.1" "198.18.3.1"

replace dummy0_ip dummy0_ip4
replace "10.3.0.1" "198.18.4.1"

replace bond0_ip bond0_ip4
replace "10.4.0.1" "198.18.5.1"

replace macvlan0_ip macvlan0_ip4
replace "10.5.0.1" "198.18.6.1"

replace macvlan1_ip macvlan1_ip4
replace "10.5.1.1" "198.18.7.1"

replace br0_ip br0_ip4
replace "10.6.0.1" "198.18.8.1"

replace "br1_ip" "br1_ip4"
replace "10.6.1.1" "198.18.9.1"

replace team0_ip team0_ip4
replace "10.7.0.1" "198.18.10.1"

replace team1_ip team1_ip
replace "10.7.1.1" "198.18.11.1"

replace ovsbr0_ip ovsbr0_ip4
replace "10.8.0.1" "198.18.12.1"

replace ovsbr1_ip ovsbr1_ip4
replace "10.8.1.1" "198.18.13.1"

