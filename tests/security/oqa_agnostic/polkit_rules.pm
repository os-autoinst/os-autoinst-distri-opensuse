# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'polkit rules' go test
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use Utils::Backends;
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
    return {always_rollback => has_snapshots};
}

1;
