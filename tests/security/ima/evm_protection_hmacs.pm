# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test EVM protection using HMACs
# Note: This case should come after 'evm_setup'
# Maintainer: QE Security <none@suse.de>
# Tags: poo#53579, poo#100694, poo#102311

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use bootloader_setup qw(replace_grub_cmdline_settings tianocore_disable_secureboot);
use power_action_utils 'power_action';

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $fstype = 'ext4';
    my $sample_app = '/usr/bin/yes';
    my $sample_cmd = 'yes --version';

    my $findret = script_output("/usr/bin/find / -fstype $fstype -type f -uid 0 -exec evmctl -a sha256 ima_hash '{}' \\;", 1800, proceed_on_failure => 1);
    # Allow "No such file" message for the files in /proc because they are mutable
    my @finds = split /\n/, $findret;
    $_ =~ m/\/proc\/.*No such file|hash\(sha256\)/ or die "Failed to create security.evm for $_" foreach (@finds);

    validate_script_output "getfattr -m . -d $sample_app", sub {
        # Base64 armored security.evm and security.ima content (50 chars), we
        # do not match the last three ones here for simplicity
        m/security\.evm=[0-9a-zA-Z+\/]{27}.*
          security\.ima=[0-9a-zA-Z+\/]{47}/sxx;
    };

    # Remove security.evm attribute manually, and verify it is empty
    assert_script_run "setfattr -x security.evm $sample_app";
    validate_script_output "getfattr -m security.evm -d $sample_app", sub { m/^$/ };

    replace_grub_cmdline_settings('evm=fix ima_appraise=fix', '', update_grub => 1);

    # We need re-enable the secureboot after removing "ima_appraise=fix" kernel parameter
    power_action('reboot', textmode => 1);
    $self->wait_grub(bootloader_time => 200);
    $self->tianocore_disable_secureboot('re_enable');
    $self->wait_boot(textmode => 1);
    select_serial_terminal;
    my $ret = script_output($sample_cmd, 30, proceed_on_failure => 1);
    die "$sample_app should not have permission to run" if ($ret !~ "\Q$sample_app\E: *Permission denied");
}

sub test_flags {
    return {always_rollback => 1};
}

1;
