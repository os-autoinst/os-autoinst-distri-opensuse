#!/bin/bash
# Print commands and abort script on failure
set -ex
#
# PREPARATION
# --------------------
. /etc/os-release
# Variables Definition
# --------------------
BRIDGEIF_NAME="br0"
ACTIVE_DEVICE=$(ip a|awk -F': ' '/state UP/ {print $2}'|head -n1)
CONNECTION_NAME=$(nmcli -f DEVICE,CONNECTION dev status| grep ${ACTIVE_DEVICE} | awk '{print $4}')
ACTIVE_CONNECTION="Wired connection ${CONNECTION_NAME}"
ACTIVE_UUID=$(nmcli -g UUID,DEVICE con | grep ${ACTIVE_DEVICE} | cut -d: -f1)
IPV4_ADDRESS=$(nmcli -g IP4.ADDRESS con show "${ACTIVE_UUID}")
IPV4_GATEWAY=$(nmcli -g IP4.GATEWAY con show "${ACTIVE_UUID}")
IPV4_DNS_A=$(nmcli -g IP4.DNS con show "${ACTIVE_UUID}"| awk '{print $1}')
IPV4_DNS_B=$(nmcli -g IP4.DNS con show "${ACTIVE_UUID}"| awk '{print $3}')

# Function Definitions
# --------------------
# Add Host Bridge Network Interface via nmcli
setup_host_bridge_network_interface() {
    # Add bridge type
    nmcli con add type bridge con-name ${BRIDGEIF_NAME} ifname ${BRIDGEIF_NAME} \
         autoconnect yes ipv4.method manual ipv4.address ${IPV4_ADDRESS} \
         ipv4.gateway ${IPV4_GATEWAY} ipv4.dns ${IPV4_DNS_A} +ipv4.dns ${IPV4_DNS_B} \
    # Add bridge-slave type
    nmcli con add type bridge-slave con-name ${BRIDGEIF_NAME}-slave ifname ${ACTIVE_DEVICE} master ${BRIDGEIF_NAME}
}

# Enable Host Bridge Network Interface via nmcli
enable_host_bridge_network_interface() {
    nmcli con up ${BRIDGEIF_NAME}
    # refer to bsc#1208005 for more details
    nmcli con down "${ACTIVE_CONNECTION}"
}

# ==== #
# MAIN # Testing starts here ...
# ==== #
if [[ $ID =~ 'alp' ]]; then
    echo "Confirm Test Environment: ALP"
else
    echo "Error: Please perform this Tool on ALP! Exit... now"
    exit 1
fi

setup_host_bridge_network_interface
enable_host_bridge_network_interface
