# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test audit function for IMA appraisal
# Note: This case should come after 'ima_appraisal_digital_signatures'
# Maintainer: QE Security <none@suse.de>
# Tags: poo#49568, poo#92347

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use bootloader_setup qw(add_grub_cmdline_settings replace_grub_cmdline_settings);
use power_action_utils 'power_action';

sub audit_verify {
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $sample_app = '/usr/bin/yes';
    my $sample_cmd = 'yes --version';

    systemctl('is-active auditd');
    if (script_run("grep CONFIG_INTEGRITY_TRUSTED_KEYRING=y /boot/config-`uname -r`") == 0) {
        record_soft_failure("bsc#1157432 for SLE15SP2+: CA could not be loaded into the .ima or .evm keyring");
    }
    else {
        # Make sure IMA is in the enforce mode
        validate_script_output "grep -E 'ima_appraise=(fix|log|off)' /etc/default/grub || echo 'IMA enforced'", sub { m/IMA enforced/ };
        assert_script_run("test -e /etc/sysconfig/ima-policy", fail_message => 'ima-policy file is missing');

        # Clear security.ima no matter whether it existing
        script_run "setfattr -x security.ima $sample_app";
        validate_script_output "getfattr -m security.ima -d $sample_app", sub { m/^$/ };

        assert_script_run("echo -n '' > /var/log/audit/audit.log");
        my $ret = script_output($sample_cmd, 30, proceed_on_failure => 1);
        die "$sample_app should not have permission to run" if ($ret !~ "\Q$sample_app\E: *Permission denied");
        validate_script_output "ausearch -m INTEGRITY_DATA", sub { m/\Q$sample_app\E/ };

        # Test both default(no ima_apprais=) and ima_appraise=log situation
        add_grub_cmdline_settings("ima_appraise=log", update_grub => 1);
        power_action("reboot", textmode => 1);
        $self->wait_boot(textmode => 1);
        select_serial_terminal;

        assert_script_run("echo -n '' > /var/log/audit/audit.log");
        assert_script_run "$sample_cmd";
        validate_script_output "ausearch -m INTEGRITY_DATA", sub { m/\Q$sample_app\E/ };
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
