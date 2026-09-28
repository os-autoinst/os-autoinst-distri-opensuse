# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'polkit rules' go test
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use agnosticTestRunner;

sub run {
    select_serial_terminal;
    my $test = agnosticTestRunner->new({
            language => 'go',
            name => 'testPolkit',
            domain => 'security',
        }
    );

    $test->setup()->run_test()->parse_results()->cleanup();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
