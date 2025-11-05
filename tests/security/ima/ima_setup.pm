# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Setup environmnet for IMA & EVM testing - import MOK cert,
#          setup grub boot menu and install necessary ima tools
# Maintainer: QE Security <none@suse.de>
# Tags: poo#45662

use base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use bootloader_setup 'add_grub_cmdline_settings';
use power_action_utils "power_action";
use version_utils qw(is_sle);
use Utils::Architectures qw(is_aarch64);

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Check that the FS is indeed ext4
    my $root_fs = script_output 'findmnt -n -o FSTYPE /';
    chomp $root_fs;

    $root_fs eq 'ext4' or die "Root file system is not ext4 but '$root_fs'";

    # Add 'iversion' to fstab mount options
    assert_script_run "awk -i inplace '{if(\$3 == \"ext4\") \$4=\$4\",iversion\"; print}' /etc/fstab";

    # Add 'rootflags=iversion' to grub2 boot menu
    add_grub_cmdline_settings('rootflags=iversion', update_grub => 1);

    # Some necessary packages
    zypper_call('in evmctl dracut-ima');

    # Reboot to make settings work
    power_action('reboot', textmode => 1);
    $self->wait_boot;
    select_serial_terminal;
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
