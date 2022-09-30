# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Setup environment for EVM protection testing
# Note: This case should come after 'ima_setup'
#
# Maintainer: QE Security <none@suse.de>
#
# Tags: poo#53579, poo#100694, poo#102311, poo#102843

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use bootloader_setup qw(add_grub_cmdline_settings replace_grub_cmdline_settings tianocore_disable_secureboot);
use power_action_utils 'power_action';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $key_dir = '/etc/keys';
    my $userkey_blob = "$key_dir/kmk-user.blob";
    my $evmkey_blob = "$key_dir/evm.blob";
    my $masterkey_conf = '/etc/sysconfig/masterkey';
    my $evm_conf = '/etc/sysconfig/evm';

    # Create Kernel Master Key
    assert_script_run "keyctl add user kmk-user '`dd if=/dev/urandom bs=1 count=32 2>/dev/null`' \@u";
    script_run "[ -d $key_dir ] || mkdir $key_dir";
    assert_script_run "keyctl pipe `/bin/keyctl search \@u user kmk-user` > $userkey_blob";

    # Generate EVM key which will be used for HMACs
    assert_script_run "keyctl add encrypted evm-key 'new user:kmk-user 64' \@u";
    assert_script_run "keyctl pipe `/bin/keyctl search \@u encrypted evm-key` > $evmkey_blob";

    assert_script_run "echo -e \"MASTERKEYTYPE='user'\\nMASTERKEY='$userkey_blob'\" > $masterkey_conf";
    assert_script_run "echo -e \"EVMKEY='$evmkey_blob'\" > $evm_conf";

    add_grub_cmdline_settings("evm=fix ima_appraise=fix ima_appraise_tcb", update_grub => 1);

    record_info("bsc#1189988: ", "We need disable secureboot with ima fix mode");
    power_action("reboot", textmode => 1);
    $self->wait_grub(bootloader_time => 200);
    $self->tianocore_disable_secureboot;
    $self->wait_boot(textmode => 1);
    $self->select_serial_terminal;

    validate_script_output "cat /sys/kernel/security/evm", sub { m/^1$/ };
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
