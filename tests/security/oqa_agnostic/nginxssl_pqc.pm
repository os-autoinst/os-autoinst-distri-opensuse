# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run nginx ssl post quantum python test
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use agnosticTestRunner;
use version_utils 'is_sle';
use utils 'zypper_call';
use Utils::Architectures 'is_s390x';

sub run {
    select_serial_terminal;
    if (is_sle('<16')) {
        record_info('SKIP', 'OpenSSL post quantum crypto tests are only available on SLE 16 and later');
        return;
    }

    # prepare test environment
    zypper_call 'in nginx';
    # nginx prints its version to stderr
    my $nginx_version = script_output('nginx -v 2>&1');
    record_info('nginx version', $nginx_version);

    zypper_call 'in python3-pytest';
    my $pytest_version = script_output('pytest --version');
    record_info('Pytest version', $pytest_version);

    my $python_version = script_output('python3 --version');
    record_info('Python version', $python_version);

    if (is_s390x) {
        zypper_call 'in openssl';
    }

    my $openssl_version = script_output('openssl --version');
    record_info('OpenSSL version', $openssl_version);

    # run test, test files (incl. pqc-ssl.conf) are listed by 'runtest -f'
    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testNginxSSLPQC',
            domain => 'security'
        }
    );
    $test->setup()->run_test()->parse_results()->cleanup();
}

1;
