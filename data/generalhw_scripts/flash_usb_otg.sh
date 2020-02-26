#!/bin/bash
# Print commands
set -ex

# You need to copy ssh pub keys to the flasher for root and geekotest user if this is not the openQA worker
# ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.0.35
# ssh-copy-id -i ~/.ssh/id_rsa.pub geekotest@192.168.0.35

# Get parameters
# Destination: <IP_or_hostname>:/storage/
destination=$1
# Image: *.raw.xz or *.iso file
image_to_flash=$2
# Size to resize
size=$3
# user
username=root # $(whoami)


if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]
  then
    echo "Please provide <destination>, <image to flash> and <hdd size> as arguments."
    exit 1;
fi

# Extract IP/hostanme from $destination
IFS=: read -r flasher_ip destination_folder <<< "$destination"
image_to_flash_full_path="$destination_folder/$(basename $image_to_flash)"

image_to_flash_extension="${image_to_flash##*.}"
uncompressed_filename=$(basename $image_to_flash_full_path .xz)

umount_previous_image="modprobe -r g_mass_storage || true"
mount_current_image="modprobe g_mass_storage file=$destination_folder/$uncompressed_filename removable=1 || true"


echo "Flash script start...";

# Disconnect previous image, if any
ssh root@$flasher_ip $umount_previous_image
echo "** USB disk disconnected"

# Cleanup target folder
ssh $username@$flasher_ip rm -f $destination_folder/*.{raw,xz,iso}

# Copy current image
scp $image_to_flash $username@$destination
# Extract compressed image, if needed
if [[ "$image_to_flash_extension" == "xz" ]]; then
	ssh $username@$flasher_ip unxz --threads=0 $image_to_flash_full_path
	echo "**** xz image uncompressed"
	# Resize *.raw image
	ssh $username@$flasher_ip qemu-img resize $destination_folder/$uncompressed_filename $size
	echo "**** raw image resized to $size"
fi
echo "** USB disk flashed"


# Mount current image
ssh root@$flasher_ip $mount_current_image
echo "** USB disk connected"

echo "Flash script done!";
