# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run FIPS-mode Java crypto tests: JCA provider hashing and elliptic-curve math/ECDSA
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use security::agnosticTestRunner;

sub run {
    select_serial_terminal;
    for my $name (qw(java_hashing java_elliptic)) {
        security::agnosticTestRunner->new({language => 'java', name => $name})
          ->setup()->run_test()->parse_results()->cleanup();
    }
}

sub test_flags {
    return {always_rollback => 0};
}

1;
