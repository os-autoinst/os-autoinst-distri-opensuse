# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Setup environmnet for IMA & EVM testing - import MOK cert,
#          setup grub boot menu and install necessary ima tools
# Maintainer: QE Security <none@suse.de>
# Tags: poo#45662

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;
use bootloader_setup 'add_grub_cmdline_settings';
use power_action_utils "power_action";

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # Add 'iversion' to fstab mount options
    assert_script_run "awk -i inplace '{if(\$3 == \"ext4\") \$4=\$4\",iversion\"; print}' /etc/fstab";

    # Add 'rootflags=iversion' to grub2 boot menu
    add_grub_cmdline_settings('rootflags=iversion', update_grub => 1);

    # Some necessary packages
    zypper_call('in evmctl dracut-ima');

    # Reboot to make settings work
    power_action('reboot', textmode => 1);
    $self->wait_boot;
    $self->select_serial_terminal;
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
