# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'polkit rules' go test
# Maintainer: QE Security <none@suse.de>

use base 'opensusebasetest';
use testapi;
use utils;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    my @files = qw(runtest go.mod polkit_test.go utils.go);
    # install go and download test files
    zypper_call 'in go gotestsum';
    assert_script_run 'mkdir -p ~/testPolkit && cd ~/testPolkit';
    my $url = data_url("security/testPolkit/");
    assert_script_run 'curl -s ' . join ' ', map { "-O $url/$_" } @files;

    # run test and generate result file
    assert_script_run("chmod +x ./runtest && ./runtest && mv results.xml /tmp/polkit_rules.xml");

    #cleanup after test
    assert_script_run("cd ~ && rm -rf testPolkit");
    parse_extra_log('XUnit', '/tmp/polkit_rules.xml');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
