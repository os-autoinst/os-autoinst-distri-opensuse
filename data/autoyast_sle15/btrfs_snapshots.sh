#!/bin/bash

set -e -x

# See more at bsc#935858

btrfs subvolume list / | grep '@/.snapshots' && SUBVOLUME_EXISTS=1

grep '/\.snapshots .*subvol=/@/\.snapshots' /etc/fstab && SUBVOLUME_IN_FSTAB=1

if [ "${SUBVOLUME_EXISTS}" == "1" ] && [ "${SUBVOLUME_IN_FSTAB}" == "1"  ]; then
  echo "AUTOYAST OK"
else
  echo "SCRIPT FAILURE: Subvolumes not configured"
fi
