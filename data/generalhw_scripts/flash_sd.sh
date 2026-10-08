#!/bin/bash
# Script to be used with:
#   * 'sd-mux-ctrl' software, with the following hardware: SDWire, SD_Mux, or any other compatible hardware
#   * or 'usbsdmux' software, with the following hardware: USB-SD-mux from https://shop.linux-automation.com/index.php?route=product/product&product_id=50

# Print commands and abort script on failure
set -ex

# You need to copy ssh pub keys to the flasher for root and geekotest user if this is not the openQA worker
# ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.0.35
# Software dep on target: sd-mux-ctrl or usbsdmux

echo "Flash script start...";

# user
username=root # $(whoami)

# Check number of args
if [ "$#" -ne 6 ]; then
    # Workaround for jeos-container_host@RPi3 where NUMDISKS=2 is set and adds 2 additonal args
    if [ "$#" -ne 8 ]; then
        echo "Please provide <tool>, <destination>, <device serial>, <sdX device>, <image to flash> and <hdd size> (ignored). Be carefull when setting sdX device. Destination is IP_or_hostname:/storage/"
        exit 1;
    else
        echo "Too many arguments, but ignore them as a workaround for jeos-container_host@RPi3"
    fi
fi

# Get tool: sd-mux-ctrl or usbsdmux
tool=$1
# Get destination: <IP_or_hostname>:/storage/
destination=$2
# Get device serial (check 'sd-mux-ctrl --list', or usb-sd-mux/id-<SERIAL>)
device_serial=$3
# /dev target: sdX, disk/by-id/usb-LinuxAut_sdmux_HS-SD_MMC_<SERIAL>-0:0
sdX_device=$4
# Get image to flash
image_to_flash=$5
# Get hdd size (ignored for SD, but passed as arg from openQA)
hdd_size=$6
# Extract IP/hostanme from $destination
IFS=: read -r flasher_ip destination_folder <<< "$destination"

echo "* Switch SD card to flasher"
if [ "$tool" = "usbsdmux" ]; then
  ssh root@$flasher_ip usbsdmux /dev/usb-sd-mux/id-$device_serial host
elif [ "$tool" = "sd-mux-ctrl" ]; then
  ssh root@$flasher_ip sd-mux-ctrl --device-serial=$device_serial --ts
else
  echo "Unsupported tool: '$tool'"
  exit 1;
fi

# Cleanup target folder
ssh $username@$flasher_ip mkdir -p "$destination_folder/"
ssh $username@$flasher_ip rm -f "$destination_folder/*.{raw,xz,iso,qcow2}"
echo "** Previous image deleted"

image_to_flash_full_path="$destination_folder/$(basename $image_to_flash)"
image_to_flash_extension="${image_to_flash##*.}"

if [ "$image_to_flash_extension" == "qcow2" ] ; then
	uncompressed_filename="$(basename $image_to_flash_full_path .qcow2).raw"
else
	uncompressed_filename=$(basename $image_to_flash_full_path .xz)
fi

# Copy current image
scp $image_to_flash $username@$destination
# Extract compressed image, if needed
if [[ "$image_to_flash_extension" == "xz" ]]; then
	ssh $username@$flasher_ip unxz --threads=0 $image_to_flash_full_path
	echo "*** xz image uncompressed"
	# No need to resize since the SD card size is fixed
elif [[ "$image_to_flash_extension" == "qcow2" ]]; then
	ssh $username@$flasher_ip qemu-img convert $image_to_flash_full_path "$destination_folder/$uncompressed_filename"
	echo "*** qcow2 image uncompressed"
fi

# Check /dev/$sdX_device is not mounted to prevent unexpected overwritting
# TODO: resolve symlinks
set +e
output=$(ssh root@$flasher_ip "mount | grep /dev/$sdX_device")
set -e
if [ "$output" == "" ]; then
	# Copy to SD card
	echo "** Copy to SD card"
	ssh root@$flasher_ip dd if=$destination_folder/$uncompressed_filename of=/dev/$sdX_device oflag=sync bs=8M
else
	echo "***** /dev/$sdX_device is mounted, so it is unlikely your target. Please check. *****"
	echo "$output"
	exit 1
fi

echo "* Switch SD card to SUT"
if [ "$tool" = "usbsdmux" ]; then
  ssh root@$flasher_ip usbsdmux /dev/usb-sd-mux/id-$device_serial dut
elif [ "$tool" = "sd-mux-ctrl" ]; then
  ssh root@$flasher_ip sd-mux-ctrl --device-serial=$device_serial --dut
else
  echo "Unsupported tool: '$tool'"
  exit 1;
fi

echo "Flash script done!";
