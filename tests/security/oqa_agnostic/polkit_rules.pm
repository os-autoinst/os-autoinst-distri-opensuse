# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'polkit rules' go test
# Maintainer: QE Security <none@suse.de>

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use security::agnosticTestRunner;

sub run {
    select_serial_terminal;
    my $test = security::agnosticTestRunner->new({
            language => 'go',
            name => 'testPolkit',
        }
    );

    $test->setup()->run_test()->parse_results()->cleanup();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
