# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Set serial terminal in GRUB for VMware
# Maintainer: Michal Nowak <mnowak@suse.com>

use strict;
use base 'y2logsstep';
use testapi;

sub run {
    select_console 'install-shell';

    my $device = 'sda';
    # Find installed OS root device, mount it, and chroot into it
    assert_script_run("for part in /dev/${device}[1-4]; do
            mount \$part /mnt &> /dev/null &&
            test -e /mnt/etc/default/grub &&
                break ||
                umount /mnt &> /dev/null
        done");
    assert_script_run('mount -o bind /dev /mnt/dev');
    assert_script_run('mount -o bind /proc /mnt/proc');
    type_string("chroot /mnt\n");
    wait_still_screen;

    # Configure GRUB with serial terminal (in addition to gfxterm)
    assert_script_run('sed -ie \'s/GRUB_TERMINAL.*//\' /etc/default/grub');
    assert_script_run('echo GRUB_TERMINAL_OUTPUT=\"serial gfxterm\" >> /etc/default/grub');
    assert_script_run('echo GRUB_SERIAL_COMMAND=\"serial\" >> /etc/default/grub');
    # Set expected resolution for GRUB and kernel
    assert_script_run('sed -ie \'s/GRUB_GFXMODE.*/GRUB_GFXMODE=\"1024x768x32\"/\' /etc/default/grub');
    assert_script_run('echo GRUB_GFXPAYLOAD_LINUX=\"1024x768x32\" >> /etc/default/grub');
    assert_script_run('grep ^[[:alpha:]] /etc/default/grub');
    # Update GRUB
    assert_script_run('grub2-mkconfig -o /boot/grub2/grub.cfg');

    # Exit chroot
    type_string "exit\n";
    wait_still_screen;

    # Clean-up
    assert_script_run('umount /mnt/dev');
    assert_script_run('umount /mnt/proc');
    assert_script_run('umount /mnt');

    select_console 'installation' unless get_var('REMOTE_CONTROLLER');
}

sub test_flags {
    return {fatal => 1};
}

1;
