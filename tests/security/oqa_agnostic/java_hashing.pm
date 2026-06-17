# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'java hashing' FIPS JCA provider test
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use security::agnosticTestRunner;

sub run {
    select_serial_terminal;
    my $test = security::agnosticTestRunner->new({
            language => 'java',
            name => 'java_hashing',
        }
    );

    $test->setup()->run_test()->parse_results()->cleanup();
}

sub test_flags {
    return {always_rollback => 0};
}

1;
