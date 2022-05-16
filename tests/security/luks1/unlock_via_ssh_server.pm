# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Luks1 decrypt with ssh
#
# Maintainer: rfan1 <richard.fan@suse.com> Starry Wang <starry.wang@suse.com>
# Tags: poo#107488, tc#1769799, poo#110953

use strict;
use warnings;
use base 'consoletest';
use base 'opensusebasetest';
use testapi;
use utils;
use lockapi;
use mmapi;
use bootloader_setup 'add_grub_cmdline_settings';
use power_action_utils 'power_action';
use grub_utils qw(grub_test);

sub run {
    select_console('root-console');

    # Install the required packages
    zypper_call('in dracut-sshd');

    mutex_create('SERVER_UP');

    my $children = get_children();
    mutex_wait('CLIENT_READY', (keys %$children)[0]);

    # Modify the grub with static ip address to get accessed in boot phase
    add_grub_cmdline_settings('ip=10.0.2.101::10.0.2.1:255.255.255.0:eth0::off rd.neednet=1', update_grub => 1);

    # dracut to add network and ssh service to ramdisk
    assert_script_run('dracut -f -a "network sshd"');

    # Reboot the server to make sure the changes can take effect
    power_action('reboot', textmode => 1);
    record_info 'Handle GRUB';
    grub_test();
    assert_screen('encrypted-disk-password-prompt', timeout => 120);

    mutex_create('SERVER_READY');
    wait_for_children;

    # Make sure the boot is unlocked and server should be up
    assert_screen([qw(generic-desktop opensuse-welcome displaymanager)], 200);

    # Double confirm the boot partiton is encrypted
    select_console('root-console');
    assert_script_run('cat /etc/crypttab | grep boot');
}

1;
