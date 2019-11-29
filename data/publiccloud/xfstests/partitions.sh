#!/bin/bash -e

disk=$1

parted -s /dev/${disk} mklabel gpt
parted -s /dev/${disk} mkpart primary 0% 50%
parted -s /dev/${disk} mkpart primary 50% 100%

mkfs.xfs /dev/${disk}1
mkfs.xfs /dev/${disk}2
