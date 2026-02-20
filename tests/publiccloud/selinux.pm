# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: PublicCloud specific SELinux smoke tests
# Maintainer: QE-C team <qa-c@suse.de>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use publiccloud::utils qw(is_ec2);

sub run {
    select_serial_terminal;

    # On SAP images, SELinux is expected to be in Permissive mode.
    my $enforcing = get_required_var("FLAVOR") !~ "SAP";

    zypper_call("in selinux-tools");
    # This block can be simplified when bsc#1251802 is resolved.
    if (script_run("selinuxenabled") != 0) {
        if (is_ec2) {
            record_soft_failure("bsc#1251802");
            return;
        }
        die "SELinux is not enabled";
    }
    my $expected = $enforcing ? "Enforcing" : "Permissive";
    validate_script_output("getenforce", sub { $_ =~ m/$expected/i }, fail_message => "SELinux is not in $expected mode");
    # note: ausearch returns with ret=1 if there are no matches.
    validate_script_output("! ausearch -m avc", qr/no matches/, fail_message => "Unexpected SELinux AVC denials");
}

1;
