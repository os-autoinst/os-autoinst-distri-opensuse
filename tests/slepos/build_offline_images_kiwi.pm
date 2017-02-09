# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic SLEPOS test
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "basetest";
use strict;
use warnings;
use testapi;
use utils;


sub run() {
    #todo: add another images if needed
    my $images_ref = get_var_array('IMAGE_OFFLINE_KIWI');
    foreach my $image (@{$images_ref}) {

        if ($image eq 'graphical') {
            script_output "
        set -x -e
        cd /var/lib/SLEPOS/system/images/graphical-3.4.0 && kiwi --bootusb initrd-netboot-suse-SLES11.i686-*.splash.gz
        dd if=/dev/zero bs=1M count=1024 >> /var/lib/SLEPOS/system/images/graphical-3.4.0/initrd-netboot-suse-SLES11.i686-*.splash*.raw
        fdisk /var/lib/SLEPOS/system/images/graphical-3.4.0/initrd-netboot-suse-SLES11.i686-*.splash*.raw <<EOT
d
n
p
1


w
EOT

        DEV=/dev/mapper/`kpartx -s -v -a /var/lib/SLEPOS/system/images/graphical-3.4.0/initrd-netboot-suse-SLES11.i686-*.splash*.raw |cut -f 3 -d ' '`
        e2fsck -f -y \$DEV
        resize2fs \$DEV
        tune2fs -L SRV_SLEPOS_TMPL \$DEV

        mount \$DEV /mnt

#        zypper -n in POS_Image-Tools
#        posSyncSrvPart --source-config config.00:00:90:FF:90:04 --dest-dir /mnt

        sed -i -e 's|vga=[^ ]*|vga=0x317|' /mnt/boot/grub/menu.lst

        cp -prv /srv/SLEPOS/boot /srv/SLEPOS/image /mnt
        mkdir -p /mnt/KIWI
        mkdir -p /mnt/KIWI/default
        curl " . autoinst_url . "/data/slepos/xorg.conf > /mnt/KIWI/default/xorg.conf

        cat >/mnt/KIWI/config.default << EOT
IMAGE=/dev/sda3;graphical.i686;3.4.0;192.168.1.1;8192;compressed
CONF=/KIWI/default/xorg.conf;/etc/X11/xorg.conf;/srv/SLEPOS;1024;43214a0763309d5e2c44efeca3e9c5fe
PART=3000;83;/srv/SLEPOS,1000;82;swap,3000;83;/
DISK=/dev/sda
POS_KERNEL=linux
POS_INITRD=initrd.gz
POS_KERNEL_PARAMS= panic=60 ramdisk_size=710000 ramdisk_blocksize=4096 vga=0x317 splash=silent POS_KERNEL_PARAMS_HASH=36f616c2947904e4afb229b37302ffb6
POS_KERNEL_PARAMS_HASH_VERIFY=36f616c2947904e4afb229b37302ffb6

EOT

        umount /mnt
        kpartx -d /var/lib/SLEPOS/system/images/graphical-3.4.0/initrd-netboot-suse-SLES11.i686-*.splash*.raw

        mv /var/lib/SLEPOS/system/images/graphical-3.4.0/initrd-netboot-suse-SLES11.i686-*.splash*.raw /var/lib/SLEPOS/system/images/slepos-image-offline-graphical.raw

    ", 500;

            upload_asset '/var/lib/SLEPOS/system/images/slepos-image-offline-graphical.raw';
        }
    }
}
sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
