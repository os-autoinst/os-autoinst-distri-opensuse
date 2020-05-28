#!/bin/bash
# Print commands
set -ex

# You need to copy ssh pub keys to the flasher for root and geekotest user if this is not the openQA worker
# ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.0.35
# ssh-copy-id -i ~/.ssh/id_rsa.pub geekotest@192.168.0.35

echo "Flash script start...";

# user
username=root # $(whoami)

# Check number of args
if [ "$(($# % 2))" -ne 1 ] || [ "$#" -lt 3 ]; then
    echo "Please provide <destination>, <image1 to flash> and <hdd1 size> as arguments. Optionnaly, <image2 to flash> and <hdd2 size>, etc."
    exit 1;
fi

# Get destination: <IP_or_hostname>:/storage/
destination=$1
# Extract IP/hostanme from $destination
IFS=: read -r flasher_ip destination_folder <<< "$destination"
# Number of disks
numberofdisks=$(( ($# - 1) / 2 ));

# Disconnect previous image, if any
umount_previous_image="modprobe -r g_mass_storage || true"
ssh root@$flasher_ip $umount_previous_image
echo "** Previous USB disk(s) disconnected"

# Cleanup target folder
ssh $username@$flasher_ip rm -f "$destination_folder/*.{raw,xz,iso}"
echo "** Previous image(s) deleted"

# Handle each HDD/SIZE passed in argument
for i in $(seq 1 $numberofdisks); do
	argnumber=$(($i * 2));
	# Image: *.raw.xz or *.iso file
	image_to_flash=${!argnumber};
	# Size to resize
	argnumber=$(($argnumber + 1));
	hdd_size=${!argnumber};

	image_to_flash_full_path="$destination_folder/$(basename $image_to_flash)"

	image_to_flash_extension="${image_to_flash##*.}"
	uncompressed_filename=$(basename $image_to_flash_full_path .xz)

	# Copy current image
	scp $image_to_flash $username@$destination
	# Extract compressed image, if needed
	if [[ "$image_to_flash_extension" == "xz" ]]; then
		ssh $username@$flasher_ip unxz --threads=0 $image_to_flash_full_path
		echo "**** xz image uncompressed"
		# Resize *.raw image
		ssh $username@$flasher_ip qemu-img resize $destination_folder/$uncompressed_filename $hdd_size
		echo "**** raw image resized to $hdd_size"
	fi
	#  Build args list for modprobe g_mass_storage
	if [ "$i" -eq 1 ]; then
		images_list_full_path=$destination_folder/$uncompressed_filename;
		images_removable_list="1";
	else
		images_list_full_path="$images_list_full_path,$destination_folder/$uncompressed_filename";
		images_removable_list="$images_removable_list,1";
	fi;
	echo "** USB disk $i/$numberofdisks flashed"

done

# Mount current image(s)
mount_current_images="modprobe g_mass_storage file=$images_list_full_path removable=$images_removable_list"
ssh root@$flasher_ip $mount_current_images
echo "** USB disk(s) connected"

echo "Flash script done!";
