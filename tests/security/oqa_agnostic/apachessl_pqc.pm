# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run apache ssl post quantum python test
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use security::agnosticTestRunner;
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
    zypper_call 'in apache2';
    my $apache_version = script_output('httpd -v');
    record_info('Apache version', $apache_version);

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

    # prepare test data
    record_info('preparing test data');
    my $data_url = data_url('security/openqa_agnostic/python/testApacheSSLPQC');
    my $test_dir = '~/testApacheSSLPQC';
    assert_script_run "mkdir -p $test_dir";
    assert_script_run "curl -s -o $test_dir/pqc-ssl.conf $data_url/pqc-ssl.conf";

    # run test
    my $test = security::agnosticTestRunner->new({
            language => 'python',
            name => 'testApacheSSLPQC',
            files => 'runtest apache_pqc_ssl_test.py'
        }
    );
    $test->setup()->run_test()->parse_results()->cleanup();
}

1;
