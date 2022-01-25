#!/bin/bash
# add_pci_bridge.sh 
# Add pci devices to guest .xml to enable hotplugging. This script can be expanded to add custom number
# of devices depending on specific tests cases.
# Maintainer: Teodor Baev <teodor.baev@suse.com>

machine="$1"
xml="$2"

if [[ $machine == "q35" ]]; then
	# add 10 pcie-root-port devices for hotplugging
	for n in {1..10}
		do
		sed -i "/.*<\/devices>/i<controller type='pci' model='pcie-root-port'/>" $xml
	        done

	# add pcie-to-pci brdige for legecy devices
	sed -i "/.*<\/devices>/i<controller type='pci' model='pcie-to-pci-bridge'/>" $xml

elif [[ $machine == "i440fx" ]]; then
	# add pci-bridge
	sed -i "/.*<\/devices>/i<controller type='pci' model='pci-bridge'/>" $xml
fi
