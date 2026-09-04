# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run OQS Provider openssl agnostic test verifying post-quantum key
#          generation, signing, and signature verification.
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use version_utils 'package_version_cmp';
use agnosticTestRunner;

# Older providers predate the algorithm names and the '-provider oqs' CLI handling
# the test relies on, so there is nothing meaningful to assert against them.
use constant MIN_OQS_VERSION => '0.4.0';

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # zypper se exits with 104 when no package matches the search term
    if (script_run('zypper se oqs-provider') == 104) {
        record_info('Skipped', 'oqs-provider is not available in the configured repositories');
        return;
    }
    zypper_call('in openssl oqs-provider');

    my $oqs_version = script_output(q(rpm -q --queryformat '%{VERSION}' oqs-provider));
    if (package_version_cmp($oqs_version, MIN_OQS_VERSION) < 0) {
        record_info('Skipped', "oqs-provider $oqs_version is older than the required " . MIN_OQS_VERSION);
        return;
    }
    record_info('oqs-provider', "version $oqs_version");

    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testOqsProvider',
            domain => 'security',
        }
    );
    $test->setup()->run_test()->parse_results()->cleanup();
}

1;
