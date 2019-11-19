#!/bin/sh

myname="$(basename "$0")"

if ! [ -f /usr/share/syslinux/pxelinux.0 ] ; then
	# On a properly generated supportserver this should never happen, of course.
	echo "$myname: ERROR: Bootloader \"pxelinux.0\" not found (RPM \"syslinux\" missing?) Aborting..." >&2
	exit 1
fi

if rpm --quiet -q atftp ; then
	# Package atftp does not exist anymore for >= SLE-15
	pxe_d="/srv/tftpboot/boot"
	tftp_install="ln -s -v"
elif rpm --quiet -q tftp ; then
	# tftp to take over for the >= SLE-15 supportserver's TFTP service.
	# Contrary to atftpd, tftp in its standard config can serve only
	# /srv/tftpboot/$file (no subdirs).
	# Furthermore, tftp is unable to follow symlinks.
	# Neither can pxelinux.0 if combined with tftp.
	pxe_d="/srv/tftpboot"
	tftp_install="cp -a -v"
else
	# FIXME: no other options besides atftp, tftp are considered.
	#        A need might arise in future products.
	echo "$myname: ERROR: no TFTP server present. Doing nothing." >&2
	exit 1
fi

function usage() {
	echo "
Usage:  $myname
        $myname -h

        to set up a PXE boot server on the supportserver which includes
        a network boot entry with kernel and initrd retrieved from /dev/cdrom
        (openQA variable 'ISO'. Supposed to specify an x86_64 installation medium).

Options:
        -h   Print this help and exit successfully
"
}


# Cmdline evaluation: Defaults and options
#
while getopts h optchar ; do
    case "$optchar" in
        h)      usage ; exit 0            ;;
        *)      usage ; exit 1            ;;
    esac
done

if ! grep -q '/dev/cdrom' /etc/fstab ; then
  mkdir -p /srv/www/htdocs/iso
  echo "/dev/cdrom /srv/www/htdocs/iso iso9660 defaults 0 0" >> /etc/fstab
  mount -a
fi
if ! [ -f "/srv/www/htdocs/iso/boot/x86_64/loader/linux" -a \
       -f "/srv/www/htdocs/iso/boot/x86_64/loader/initrd" ]
then
	# Should never happen unless ISO is set incorrectly or the layout
	# of the installation medium differs from the above hardcoded one
	echo "$myname: ERROR: /dev/cdrom ('ISO'): kernel or initrd not found. Aborting..." >&2
	exit 1
fi

mkdir -p "$pxe_d/pxelinux.cfg"
$tftp_install /usr/share/syslinux/pxelinux.0 "$pxe_d"/pxelinux.0
$tftp_install /usr/share/syslinux/menu.c32 "$pxe_d"/menu.c32

$tftp_install "/srv/www/htdocs/iso/boot/x86_64/loader/linux" "$pxe_d/linux"
$tftp_install "/srv/www/htdocs/iso/boot/x86_64/loader/initrd" "$pxe_d/initrd"


cat >"$pxe_d/pxelinux.cfg/default" <<EOT
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
