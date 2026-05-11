# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run openssl post quantum go test
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use security::agnosticTestRunner;
use version_utils 'is_sle';

sub run {
    select_serial_terminal;
    if (is_sle('<15-SP7')) {
        record_info('SKIP', 'OpenSSL post quantum crypto tests are only available on SLE 15-SP7 and later');
        return;
    }
    record_info('openssl version:', script_output('rpm -q openssl'));
    my $test = security::agnosticTestRunner->new({
            language => 'python',
            name => 'testPostQuantumCrypto',
        }
    );
    $test->setup()->run_test()->parse_results()->cleanup();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
