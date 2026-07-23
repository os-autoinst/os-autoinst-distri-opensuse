#!/bin/bash

# Disable GRUB timeout
mount %INSTALL_DISK%1 /mnt
grub2-editenv /mnt/grubenv set timeout=-1
umount /mnt
