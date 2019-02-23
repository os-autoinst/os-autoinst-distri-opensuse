# Copyright (C) 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Setup environmnet for IMA & EVM testing - import MOK cert,
#          setup grub boot menu and install necessary ima tools
# Maintainer: wnereiz <wnereiz@member.fsf.org>
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
    add_grub_cmdline_settings('rootflags=iversion', 1);

    # Some necessary packages
    zypper_call('in evmctl dracut-ima');

    # Reboot to make settings work
    power_action('reboot', textmode => 1);
    $self->wait_boot;
    $self->select_serial_terminal;
}

sub test_flags {
    return {fatal => 1};
}

1;
