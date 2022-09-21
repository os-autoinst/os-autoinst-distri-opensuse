# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Set serial terminal in GRUB for VMware
# Maintainer: Michal Nowak <mnowak@suse.com>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;

sub run {
    select_console 'install-shell';

    my $device = 'sda';
    # Find installed OS root device, mount it, and chroot into it
    assert_script_run("for part in /dev/${device}[1-4]; do
            mount \$part /mnt &&
            test -e /mnt/etc/default/grub &&
                break ||
                umount /mnt
        done");
    assert_script_run('mount -o bind /dev /mnt/dev');
    assert_script_run('mount -o bind /proc /mnt/proc');
    enter_cmd("chroot /mnt");
    wait_still_screen;

    # Mount Btrfs sub-volumes
    assert_script_run('mount -a');
    # Configure GRUB with serial terminal (in addition to gfxterm)
    assert_script_run('sed -ie \'s/GRUB_TERMINAL.*//\' /etc/default/grub');
    # VMware needs to always stop in Grub and wait for interaction.
    # Migration seems to reset it.
    assert_script_run('sed -ie \'s/GRUB_TIMEOUT.*/GRUB_TIMEOUT=-1/\' /etc/default/grub');
    assert_script_run('echo GRUB_TERMINAL_OUTPUT=\"serial gfxterm\" >> /etc/default/grub');
    assert_script_run('echo GRUB_SERIAL_COMMAND=\"serial\" >> /etc/default/grub');
    # Set expected resolution for GRUB and kernel
    assert_script_run('sed -ie \'s/GRUB_GFXMODE.*/GRUB_GFXMODE=\"1024x768x32\"/\' /etc/default/grub');
    assert_script_run('echo GRUB_GFXPAYLOAD_LINUX=\"1024x768x32\" >> /etc/default/grub');
    assert_script_run('grep ^[[:alpha:]] /etc/default/grub');
    # Update GRUB
    assert_script_run('grub2-mkconfig -o /boot/grub2/grub.cfg');

    # Exit chroot
    enter_cmd "exit";
    wait_still_screen;

    # Clean-up
    assert_script_run('umount /mnt/dev');
    assert_script_run('umount /mnt/proc');
    # There might be remnants from `mount -a` in /mnt,
    # so lets unmount it "lazily".
    assert_script_run('umount -l /mnt');

    select_console 'installation' unless get_var('REMOTE_CONTROLLER');
}

1;
