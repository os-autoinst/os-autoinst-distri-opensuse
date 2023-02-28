#!/bin/bash
# Script to be used with: 'usbsdmux' software, with the following hardware:
#  USB-SD-mux from https://shop.linux-automation.com/index.php?route=product/product&product_id=50

# Print commands and abort script on failure
set -ex

echo "Flash script start...";

# Check number of args
if [ "$#" -ne 4 ]; then
    echo "Please provide <destination>, <device serial>, <image to flash> and <hdd size> (ignored)."
    exit 1;
fi

# Get destination: /storage/
destination_folder=$1
# Get device serial (check 'sd-mux-ctrl --list', or usb-sd-mux/id-<SERIAL>)
device_serial=$2
# Get image to flash
image_to_flash=$3
# Get hdd size (ignored for SD, but passed as arg from openQA)
hdd_size=$4

echo "* Switch SD card to flasher"
usbsdmux /dev/usb-sd-mux/id-$device_serial host

# Cleanup target folder
mkdir -p "$destination_folder/"
rm -f $destination_folder/*.{raw,xz,iso,qcow2}
echo "** Previous image deleted"

image_to_flash_extension="${image_to_flash##*.}"
if [ "$image_to_flash_extension" == "qcow2" ] ; then
	uncompressed_filename="$(basename $image_to_flash .qcow2).raw"
else
	uncompressed_filename=$(basename $image_to_flash .xz)
fi
uncompressed_full_path="$destination_folder/$uncompressed_filename"
ext="${uncompressed_filename##*.}"

# Extract compressed image, if needed
if [[ "$image_to_flash_extension" == "xz" ]]; then
	if [ "$ext" == "raw" ] ; then
		echo "*** image is raw.xz, no need to uncompress it"
	else
		xzcat "$image_to_flash" --threads=0 "$uncompressed_full_path"
		echo "*** xz image uncompressed"
		# No need to resize since the SD card size is fixed
	fi
elif [[ "$image_to_flash_extension" == "qcow2" ]]; then
	qemu-img convert "$image_to_flash" "$uncompressed_full_path"
	echo "*** qcow2 image uncompressed"
fi

# Check /dev/sdX_device is not mounted to prevent unexpected overwritting
set +e
sdX_device=$(readlink -f /dev/disk/by-id/usb-LinuxAut_sdmux_HS-SD_MMC_${device_serial}-0:0)
output=$(mount | grep /dev/$sdX_device)
set -e
if [ "$output" == "" ]; then
	# Copy to SD card
	echo "** Copy to SD card"
	if [ "$ext" == "raw" ] ; then
		# stream data to SD card directly
		xz -cd $image_to_flash | dd of=/dev/disk/by-id/usb-LinuxAut_sdmux_HS-SD_MMC_${device_serial}-0:0 oflag=sync bs=8M
	else
		dd if=$uncompressed_full_path of=/dev/disk/by-id/usb-LinuxAut_sdmux_HS-SD_MMC_${device_serial}-0:0 oflag=sync bs=8M
	fi
else
	echo "***** /dev/$sdX_device is mounted, so it is unlikely your target. Please check. *****"
	echo "$output"
	exit 1
fi

echo "* Switch SD card to SUT"
usbsdmux /dev/usb-sd-mux/id-$device_serial dut

echo "Flash script done!";
