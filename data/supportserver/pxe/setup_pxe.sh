#!/bin/sh

myname="$(basename "$0")"
kernel_dflt="client/vmlinuz"
kernelargs_dflt=\
"initrd=client/initrd splash=off video=1024x768-16 plymouth.ignore-serial-consoles console=ttyS0 console=tty quiet mitigations=auto"

function usage() {
	echo "
Usage:  $myname [-C [-k kernel [-a kernelargs]]]
        $myname -h

        to set up a PXE boot server on the supportserver.

Options:
        -h   Print this help and exit successfully

        -C   Add a further boot entry to pxelinux.cfg/default which provides
             a custom kernel to the PXE client
        -k   specify the kernel for option -C (default: \"$kernel_dflt\")
        -a   specify the kernel command line arguments for option -C. Default:

\"$kernelargs_dflt\"

             Warning: needed: a root=... spec unless the initrd knows by itself.
"
}


# Cmdline evaluation: Defaults and options
#
custom=""
kernel="$kernel_dflt"
kernelargs="$kernelargs_dflt"

while getopts hCk:a: optchar ; do
    case "$optchar" in
        h)      usage ; exit 0            ;;
        C)      custom="yes"              ;;
        k)      kernel="$OPTARG"          ;;
        a)      kernelargs="$OPTARG"      ;;
        *)      usage ; exit 1            ;;
    esac
done
#
# FIXME: no real sanity checks yet.
# Kernel and initrd files don't need to already exist at this stage.
if [ -n "$custom" ] ; then
	if [ -z "$kernel" -o "$kernelargs" == "${kernelargs#*initrd=}" ]; then
		echo "\
$myname: WARNING: custom PXE entry: empty kernel or kernel _without initrd_ specified:

Kernel:      $kernel
Kernel args: $kernelargs

_Not_ adding a custom kernel PXE entry..."
		custom=""
	fi	# if [ -z "$kernel" -o "$kernelargs" == "${kernelargs#*initrd=}" ]; then
fi	# if [ -n "$custom" ] ; then

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

if [ -n "$custom" ] ; then
	cat >>"/srv/tftpboot/boot/pxelinux.cfg/default" <<EOT
LABEL custom
        MENU LABEL Custom kernel
        kernel $kernel
        append $kernelargs

EOT

fi	# if [ -n "$custom" ]

echo "PXE OK"
