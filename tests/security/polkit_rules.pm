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

    # install go and download test files
    zypper_call 'in go';
    my @files = qw(runtest go.mod main.go utils/utils.go tap/tap.go);
    assert_script_run("mkdir -p ~/testPolkit && cd ~/testPolkit");
    foreach my $file (@files) {
        assert_script_run "curl -O -v --create-dirs " . data_url("security/testPolkit/$file");
    }
    assert_script_run 'mkdir utils tap && mv utils.go utils/ && mv tap.go tap/';

    # run test and generate result file
    assert_script_run("chmod +x ./runtest && ./runtest && mv results.tap /tmp/polkit_rules.tap");

    #cleanup after test
    assert_script_run("cd ~ && rm -rf testPolkit");
    parse_extra_log('TAP', '/tmp/polkit_rules.tap');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
