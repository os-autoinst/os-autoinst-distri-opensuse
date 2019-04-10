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
# Summary: Setup environment for EVM protection testing
# Note: This case should come after 'ima_setup'
# Maintainer: wnereiz <wnereiz@member.fsf.org>
# Tags: poo#53579

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;
use bootloader_setup "add_grub_cmdline_settings";
use power_action_utils "power_action";

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $key_dir        = '/etc/keys';
    my $userkey_blob   = "$key_dir/kmk-user.blob";
    my $evmkey_blob    = "$key_dir/evm.blob";
    my $masterkey_conf = '/etc/sysconfig/masterkey';
    my $evm_conf       = '/etc/sysconfig/evm';

    # Create Kernel Master Key
    assert_script_run "keyctl add user kmk-user '`dd if=/dev/urandom bs=1 count=32 2>/dev/null`' \@u";
    assert_script_run "mkdir $key_dir";
    assert_script_run "keyctl pipe `/bin/keyctl search \@u user kmk-user` > $userkey_blob";

    # Generate EVM key which will be used for HMACs
    assert_script_run "keyctl add encrypted evm-key 'new user:kmk-user 64' \@u";
    assert_script_run "keyctl pipe `/bin/keyctl search \@u encrypted evm-key` > $evmkey_blob";

    assert_script_run "echo -e \"MASTERKEYTYPE='user'\\nMASTERKEY='$userkey_blob'\" > $masterkey_conf";
    assert_script_run "echo -e \"EVMKEY='$evmkey_blob'\" > $evm_conf";

    add_grub_cmdline_settings("evm=fix ima_appraise=fix ima_appraise_tcb", 1);

    power_action('reboot', textmode => 1);
    $self->wait_boot(textmode => 1);
    $self->select_serial_terminal;

    validate_script_output "cat /sys/kernel/security/evm", sub { m/^1$/ };
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
