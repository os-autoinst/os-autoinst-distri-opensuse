#!/bin/bash
#
# Summary: Add PCIe root port and PCIe to PCI bridge for hotplugging
# Usage: $0 DOMAIN

if [[ $# -lt 1 ]]; then
	echo "Usage: $0 DOMAIN"
	echo "Adds a PCIe root port and PCIe to PCI bridge, necessary for hotplugging"
	exit 1
fi

DOMAIN="$1"
XML="${DOMAIN}.xml"

function cleanup() {
	set +e
	rm -f "$XML"
}
trap cleanup EXIT

set -e

# Skip, if a pcie-to-pci-bridge is already present
if virsh dumpxml "$DOMAIN" | grep "controller" | grep "pcie-to-pci-bridge" >/dev/null; then
	echo "Skipping $DOMAIN - pcie-to-pci-bridge is already present"
	exit 0
fi

# Note: tac reverses the input line by line.
# We replace the first line of the reversed input, and then reverse it again, so that effectively we are replacing the last occurance of </controller>
virsh dumpxml "$DOMAIN" | tac | sed '0,/<\/controller>/s//<controller type="pci" model="pcie-root-port"\/>\n<controller type="pci" model="pcie-to-pci-bridge"\/>\n<\/controller>/' | tac | tee "$XML"
virsh define "$XML"

# Check if the settings are applied correctly
virsh dumpxml "$DOMAIN" | grep "controller" | grep "pcie-root-port"
virsh dumpxml "$DOMAIN" | grep "controller" | grep "pcie-to-pci-bridge"

# All good
