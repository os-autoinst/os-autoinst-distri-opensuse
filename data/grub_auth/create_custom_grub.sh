#!/bin/bash
  
set -euo pipefail

ROOT_DISK=`df -T | grep \/$ | awk '{print $1}'`
PARTNO=`echo ${ROOT_DISK:0-1}`
FS=`df -T | grep \/$ | awk '{print $2}'`
SUP_USER="$1"
SUP_PASSWD="$2"
MAINT_USER="$3"
MAINT_PASSWD="$4"

: > /etc/grub.d/10_linux

if [ $FS = "ext4" ] || [ $FS = "ext3" ]; then
FS=ext2
fi

source  /etc/default/grub

(

cat <<EOF
set superusers=$SUP_USER
password $SUP_USER $SUP_PASSWD
password $MAINT_USER $MAINT_PASSWD

menuentry 'Operational mode' {
insmod $FS
set root=hd0,gpt${PARTNO}
echo 'Loading Linux ...'
linux /boot/vmlinuz root=$ROOT_DISK $GRUB_CMDLINE_LINUX_DEFAULT $GRUB_CMDLINE_LINUX mode=operation
echo 'Loading Initrd ...'
initrd /boot/initrd
}

menuentry 'Maintenance mode' --users $MAINT_USER {
insmod $FS
set root=hd0,gpt$PARTNO
echo 'Loading Linux ...'
linux /boot/vmlinuz root=$ROOT_DISK $GRUB_CMDLINE_LINUX_DEFAULT $GRUB_CMDLINE_LINUX mode=maintenance
echo 'Loading Initrd ...'
initrd /boot/initrd
}
EOF

) >/boot/grub2/custom.cfg

grub2-mkconfig -o /boot/grub2/grub.cfg
