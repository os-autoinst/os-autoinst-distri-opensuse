#!/bin/sh

if ! grep -q '/dev/cdrom' /etc/fstab ; then
#  mkdir -p /srv/www/htdocs/share
  mkdir -p /srv/www/htdocs/iso
#  echo "10.0.2.2:/var/lib/openqa/share /srv/www/htdocs/share nfs defaults 0 0" >> /etc/fstab
  echo "/dev/cdrom /srv/www/htdocs/iso iso9660 defaults 0 0" >> /etc/fstab
  mount -a
fi

mkdir -p /srv/tftpboot/boot/pxelinux.cfg
ln -s /usr/share/syslinux/pxelinux.0 /srv/tftpboot/boot/pxelinux.0
ln -s /usr/share/syslinux/menu.c32 /srv/tftpboot/boot/menu.c32


ln -sf "/srv/www/htdocs/iso/boot/x86_64/loader/linux" "/srv/tftpboot/boot/linux"
ln -sf "/srv/www/htdocs/iso/boot/x86_64/loader/initrd" "/srv/tftpboot/boot/initrd"


cat >"/srv/tftpboot/boot/pxelinux.cfg/default" <<EOT
default menu.c32
prompt 0
timeout 100

menu title PXE boot

LABEL hd
        MENU LABEL Hard Disk
        localboot 0

LABEL netboot
        MENU LABEL Network
        kernel linux
        append initrd=initrd install=http://10.0.2.1/iso

EOT





echo "PXE OK"