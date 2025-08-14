# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test IMA appraisal using hashes
# Maintainer: QE Security <none@suse.de>
# Tags: poo#53579, poo#100694, poo#102311

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use bootloader_setup qw(add_grub_cmdline_settings replace_grub_cmdline_settings);
use power_action_utils 'power_action';
use security::secureboot qw(handle_secureboot);

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $fstype = 'ext4';
    my $sample_app = '/usr/bin/yes';
    my $sample_cmd = 'yes --version';

    my ($kver) = script_output('uname -r') =~ /(\d+\.\d+)\.\d+-*/;
    assert_script_run "echo $kver";
    my $tcb_cmdline = ($kver lt 4.13) ? 'ima_appraise_tcb' : 'ima_policy=appraise_tcb';

    add_grub_cmdline_settings("ima_appraise=fix $tcb_cmdline", update_grub => 1);
    power_action("reboot", textmode => 1);
    handle_secureboot($self, 'disable');
    select_serial_terminal;

    my $findret = script_output("find / -fstype $fstype -type f -uid 0 -exec sh -c \"< '{}'\" \\;", 900, proceed_on_failure => 1);

    # Allow "No such file" message for the files in /proc because they are mutable
    my @finds = split /\n/, $findret;
    $_ =~ m/\/proc\/.*No such file/ or die "Failed to create security.ima for $_" foreach (@finds);

    validate_script_output "getfattr -m security.ima -d $sample_app", sub {
        # Base64 armored security.ima content (50 chars), we do not match the last
        # three ones here for simplicity
        m/security\.ima=[0-9a-zA-Z+\/]{47}/;
    };

    # Remove security.ima attribute manually, and verify it is empty
    assert_script_run "setfattr -x security.ima $sample_app";
    validate_script_output "getfattr -m security.ima -d $sample_app", sub { m/^$/ };

    replace_grub_cmdline_settings('ima_appraise=fix', '', update_grub => 1);

    # We need re-enable the secureboot after removing "ima_appraise=fix" kernel parameter
    power_action('reboot', textmode => 1);
    handle_secureboot($self, 'enable');
    select_serial_terminal;

    my $ret = script_output($sample_cmd, 30, proceed_on_failure => 1);
    die "$sample_app should not have permission to run" if ($ret !~ "\Q$sample_app\E: *Permission denied");
}

sub test_flags {
    return {always_rollback => 1};
}

1;
