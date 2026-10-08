#!/bin/bash -e

# Check for correct arguments
if ! [[ $1 =~ ^(BIOS|UEFI|ARM64)$ ]]; then
    echo "You should declare UEFI, BIOS or ARM64!"
    echo "  USAGE: ${0} <BIOS|UEFI|ARM64>"
    exit 1
fi

# Check if the Autounattend.xml file exists
if [ ! -f "Autounattend_${1}.xml" ]; then
    echo "Error: Autounattend_${1}.xml not found!"
    exit 1
fi

# Create the raw image
output_file="autounattend_${1}.raw"
echo "***** Creating $output_file from Autounattend_${1}.xml *****"
dd if=/dev/zero of="$output_file" bs=1k count=16384
sudo mkfs.vfat -v "$output_file"
mcopy -i "$output_file" "Autounattend_${1}.xml" ::Autounattend.xml

echo "***** $output_file created successfully! *****"