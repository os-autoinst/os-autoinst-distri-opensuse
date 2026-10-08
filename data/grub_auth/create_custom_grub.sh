#!/bin/bash
  
set -euo pipefail

: << BLOCK
We can set a user name and password to authenticate the access of
GRUB options at boot loader screen. example as below:

set superuser=“[User Name]”
password [User name] [Password]

Storing password as text is not a secure way to manage credentials.
Luckily GRUB not only supports encrypted password but also provides
a command to encrypt the text password: "grub2-mkpasswd-pbkd2".
We can use hash password as below format:

password_pbkdf2 [user name] [hashed string]
BLOCK

ROOT_DISK=`df -T | grep \/$ | awk '{print $1}'`
FS=`df -T | grep \/$ | awk '{print $2}'`
UUID=`blkid | grep $ROOT_DISK | awk -F \" '{print $2}'`
ARCH=`uname -m`
KERNEL=""
SUP_USER="$1"
SUP_PASSWD="$2"
MAINT_USER="$3"
MAINT_PASSWD="$4"
SUPER_PDKDF2=`cat /tmp/sup_passwd_hash | grep PBKDF2 | awk -F "password is " '{print \$2}'`
MAINT_PDKDF2=`cat /tmp/maint_passwd_hash | grep PBKDF2 | awk -F "password is " '{print \$2}'`

: > /etc/grub.d/10_linux

if [ $FS = "ext4" ] || [ $FS = "ext3" ]; then
FS=ext2
fi

if [ $ARCH = "x86_64" ]; then
KERNEL="vmlinuz"
elif [ $ARCH = "aarch64" ]; then
KERNEL="Image"
fi

source  /etc/default/grub

(

cat <<EOF
set superusers=$SUP_USER
password_pbkdf2 $SUP_USER $SUPER_PDKDF2
password_pbkdf2 $MAINT_USER $MAINT_PDKDF2

menuentry 'Operational mode' {
insmod $FS
insmod part_gpt
search --no-floppy -u --set=root $UUID
echo 'Loading Linux ...'
linux /boot/$KERNEL root=$ROOT_DISK $GRUB_CMDLINE_LINUX_DEFAULT $GRUB_CMDLINE_LINUX mode=operation
echo 'Loading Initrd ...'
initrd /boot/initrd
}

menuentry 'Maintenance mode' --users $MAINT_USER {
insmod $FS
insmod part_gpt
search --no-floppy -u --set=root $UUID
echo 'Loading Linux ...'
linux /boot/$KERNEL root=$ROOT_DISK $GRUB_CMDLINE_LINUX_DEFAULT $GRUB_CMDLINE_LINUX mode=maintenance
echo 'Loading Initrd ...'
initrd /boot/initrd
}
EOF

) >/boot/grub2/custom.cfg
grub2-mkconfig -o /boot/grub2/grub.cfg
