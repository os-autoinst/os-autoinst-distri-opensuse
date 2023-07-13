#!/bin/bash
# Script to be used with: 'usbsdmux' software, with the following hardware:
#  USB-SD-mux from https://shop.linux-automation.com/index.php?route=product/product&product_id=50

# Print commands and abort script on failure
set -ex

echo "Flash script start...";

# Check number of args
if [ "$#" -ne 3 ]; then
    echo "Please provide <device serial>, <image to flash> and <hdd size> (ignored)."
    exit 1;
fi

# Get device serial (check 'sd-mux-ctrl --list', or usb-sd-mux/id-<SERIAL>)
device_serial=$1
# Get image to flash
image_to_flash=$2
# Get hdd size (ignored for SD, but passed as arg from openQA)
hdd_size=$3

device_link="/dev/disk/by-id/usb-LinuxAut_sdmux_HS-SD_MMC_${device_serial}-0:0"

echo "* Switch SD card to flasher"
usbsdmux /dev/usb-sd-mux/id-$device_serial host

echo "* Wait for kernel to propagate device nodes"
sleep 5
while ! [[ -L $device_link ]] ; do
	sleep 1
done
sdX_device=$(readlink -f $device_link)
while ! [[ -b $sdX_device ]] ; do
	sleep 1
done

# Check /dev/sdX_device is not mounted to prevent unexpected overwritting
set +e
output=$(mount | grep $sdX_device)
set -e
if [ "$output" == "" ]; then
	# Copy to SD card
	echo "** Copy to SD card"
	du --apparent-size -h $image_to_flash
	image_to_flash_extension="${image_to_flash##*.}"
	if [ "$image_to_flash_extension" == "qcow2" ] ; then
		qemu-img info $image_to_flash
		qemu-img dd -f qcow2 -O raw if=$image_to_flash of=$device_link bs=8M
	elif [ "$image_to_flash_extension" == "xz" ] ; then
		xzcat --threads=0 $image_to_flash | dd of=$device_link oflag=sync bs=8M status=progress
	elif [ "$image_to_flash_extension" == "gz" ] ; then
		zcat $image_to_flash | dd of=$device_link oflag=sync bs=8M status=progress
	else
		cat $image_to_flash | dd of=$device_link oflag=sync bs=8M status=progress
	fi
else
	echo "***** /dev/$sdX_device is mounted, so it is unlikely your target. Please check. *****"
	echo "$output"
	exit 1
fi

echo "* Switch SD card to SUT"
usbsdmux /dev/usb-sd-mux/id-$device_serial dut

echo "Flash script done!";
