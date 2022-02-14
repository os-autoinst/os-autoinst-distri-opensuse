#!/bin/bash

set -e

# Give the other shell some time to transfer up to the wifi_master namespace
sleep 5
# Ensure wlan0 is known, otherwise it doesn't make sense to go on
ip link | grep "wlan0" > /dev/null

echo "Starting hostapd ... "
# hostapd starts the wifi hotspot on wlan0
hostapd -t hostapd.conf >> hostapd.log &
hostapd_pid=$!
timeout 30s grep -q 'wlan0: AP-ENABLED ' <(tail -f hostapd.log)
ip addr add 192.168.200.1/24 dev wlan0
ip addr add 192.168.201.1/24 dev wlan0_0
ip addr add 192.168.202.1/24 dev wlan0_1

# Wait for signal to start dnsmasq
timeout 60s grep -q 'start dnsmasq' <(tail -f hostapd.com)
echo "Starting dnssmasq ... "
dnsmasq -R -i wlan0 --dhcp-range=192.168.200.128,192.168.200.200 -i wlan0_0 --dhcp-range=192.168.201.128,192.168.201.200 -i wlan0_1 --dhcp-range=192.168.202.128,192.168.202.200 > dnsmasq.log
echo "dnsmasq is up."

# Wait for termination signal
timeout 30s grep -q 'terminate' <(tail -f hostapd.com)
kill $hostapd_pid
echo 'ok' >> hostapd.com
sleep 1
exit 0
