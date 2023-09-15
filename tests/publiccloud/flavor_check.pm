# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run the instance-flavor-check
# Maintainer: qa-c team <qa-c@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use publiccloud::utils qw(is_byos is_ondemand);
use serial_terminal 'select_serial_terminal';
use utils;

my $log_path = '/var/log/instance_billing_flavor_check';

sub run {
    select_serial_terminal;

    zypper_call('in python-instance-billing-flavor-check') if (script_run('which python-instance-billing-flavor-check') != 0);

    record_info('SMT record', script_output('grep -i smt /etc/hosts'));

    if (is_byos()) {
        validate_script_output('instance-flavor-check || true', sub { m/^BYOS$/m }, fail_message => "The command did not return 'BYOS'.");
        die('The command should return code 11 for BYOS flavor!') if (script_run('instance-flavor-check') != 11);
        validate_script_output("cat $log_path", sub { m/^BYOS$/m }, fail_message => "The log file did not contain 'BYOS'.");
    } elsif (is_ondemand()) {
        validate_script_output('instance-flavor-check || true', sub { m/^PAYG$/m }, fail_message => "The command did not return 'PAYG'.");
        die('The command should return code 10 for PAYG flavor!') if (script_run('instance-flavor-check') != 10);
        validate_script_output("cat $log_path", sub { m/^PAYG$/m }, fail_message => "The log file did not contain 'PAYG'.");
    } else {
        # Check the return code for unknown flavor but fail anyways because we so far have only BYOS or PAYG.
        die('The command should return code 12 for unknown flavor!') if (script_run('instance-flavor-check') != 12);
        die('The flavor is unknown.');
    }
}

sub post_fail_hook {
    script_run("cat $log_path");
}

1;
