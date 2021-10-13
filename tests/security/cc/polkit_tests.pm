# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'polkit-tests' test case of 'audit-test' test suite
# Maintainer: rfan1 <richard.fan@suse.com>, Liu Xiaojing <xiaojing.liu@suse.com>
# Tags: poo#95762

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use audit_test qw(run_testcase compare_run_log);

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # PASSWD is needed by polkit_success
    script_run("export PASSWD=$testapi::password");

    # In cc role based system,polkit-agent-helper-1 needs to be setuid root.
    # Authentication is required to set the statically configured local
    # hostname, as well as the pretty hostname.
    my $results = script_run("journalctl -u dracut-pre-pivot | grep 'crypto checks done'");
    if (!$results) {
        assert_script_run('chmod u+s /usr/lib/polkit-1/polkit-agent-helper-1');
    }

    run_testcase('polkit-tests');

    # Compare current test results with baseline
    my $result = compare_run_log('polkit_tests');
    $self->result($result);
}

sub test_flags {
    return {no_rollback => 1};
}

1;
