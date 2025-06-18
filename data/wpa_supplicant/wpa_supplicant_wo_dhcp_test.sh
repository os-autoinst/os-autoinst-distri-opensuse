#!/bin/bash -ex

function prepare() {
	modprobe mac80211_hwsim radios=2
	# Ensure there are no other processes running that disturb this test
	systemctl disable --now wpa_supplicant || true
	killall wpa_supplicant 2>/dev/null || true
	killall hostapd 2>/dev/null || true
}

function cleanup() {
	set +e
	if ps -p $hostapd_pid >/dev/null; then
		kill $hostapd_pid
	fi
	modprobe -r mac80211_hwsim
	rm -f wifi_scan.txt networks.txt status.txt hostapd.com dnsmasq.log dhclinet.log dhclient.pid dhclient.lease
	rm -f /etc/sysconfig/network/ifcfg-wlan1
	wpa_cli -i wlan1 terminate >/dev/null 2>/dev/null
	ip netns pids wifi_master | xargs kill 2> /dev/null || true        # Don't display error messages, as they are misleading
	ip netns del wifi_master
}

# run grep, ident output and exit on grep failure
function GREP {
    grep "$@" | sed 's/^/   > /'
    status="${PIPESTATUS[0]}"
    if [[ $status != 0 ]]; then
        echo "[ERROR] 'grep $@' failed with status $status"
        exit 1
    fi
}

## ==== Prepare environment ================================================= ##
set -o pipefail
trap cleanup EXIT
prepare



# Prepare files that are used as communication channel
touch hostapd.log
touch wpa_supplicant.log
touch hostapd.com
# We put the hostapd in a separate network namespace
ip netns add wifi_master
ip netns exec wifi_master bash hostapd.sh &
hostapd_pid="$!"
echo "Started hostapd-bash (pid: $hostapd_pid)"
sleep 2
# Assign wlan0 (=phy0) to the namespace $hostapd_pid is in
iw phy phy0 set netns $hostapd_pid
echo "Waiting for hostapd to start ..."
timeout 30s grep -q 'wlan0: AP-ENABLED ' <(tail -f hostapd.log)

echo "Testing for wifi networks to show up ... "
wpa_supplicant -B -i wlan1 -t -dd -f wpa_supplicant.log -c wpa_supplicant1.conf
wpa_cli -i wlan1 list_networks > networks.txt
GREP "FBI Surveillance Van 3" networks.txt
GREP "FBI Surveillance Van 4" networks.txt
echo "Scanning for wifi networks ... "
wpa_cli -i wlan1 scan
for (( i=0; i < 20 ; i++)) ; do
    sleep 1;
    echo "wait for scan_results..."
    if [ $(wpa_cli -i wlan1 scan_result | wc -l) -gt 3 ]; then
        break;
    fi
done
wpa_cli -i wlan1 scan_result > wifi_scan.txt
GREP "Tony's Ice Cream Shop" wifi_scan.txt
GREP "FBI Surveillance Van 3" wifi_scan.txt
GREP "FBI Surveillance Van 4" wifi_scan.txt
echo "OK"

echo "Connecting to open wifi networks ... "
wpa_cli -i wlan1 reconfigure
wpa_cli -i wlan1 reassociate
sleep 20
wpa_cli -i wlan1 status > status.txt
GREP "ssid=FBI Surveillance Van 4" status.txt
GREP "wpa_state=COMPLETED" status.txt
GREP "pairwise_cipher=NONE" status.txt
GREP "group_cipher=NONE" status.txt
GREP "key_mgmt=NONE" status.txt
ip addr add 192.168.201.2/24 dev wlan1
ping -c 4 192.168.201.1
ip addr del 192.168.201.2/24 dev wlan1

echo "Connecting to WPA2 wifi networks ... "
wpa_cli -i wlan1 terminate
sleep 2
wpa_supplicant -B -i wlan1 -t -dd -f wpa_supplicant.log -c wpa_supplicant2.conf
# Wait until connected
for (( i=0; i < 20 ; i++)) ; do
    sleep 1;
    echo "wait for wpa_supplicant connected..."
    if wpa_cli -i wlan1 status | grep 'wpa_state=COMPLETED'; then
        break;
    fi
done
# Apply static IP configuration (dhcp comes next)
ip addr add 192.168.202.2/24 dev wlan1
wpa_cli -i wlan1 status | tee status.txt 
GREP "ssid=Tony's Ice Cream Shop" status.txt
GREP "pairwise_cipher=CCMP" status.txt
GREP "group_cipher=TKIP" status.txt
GREP "key_mgmt=WPA2-PSK" status.txt
GREP "wpa_state=COMPLETED" status.txt
ping -c 4 192.168.202.1
ip addr del 192.168.202.2/24 dev wlan1

## All good
echo -e "\n\n"
echo "[Info] ignore the 'rfkill: Cannot get wiphy information' warnings"
echo -e "\n"
echo "WPA_SUPPLICANT_TEST: PASSED"           # Cookie for openQA script
echo "[ OK ] wpa_supplicant regression test completed successfully"
