# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run libgcrypt extended FIPS and sign/verify pytest test
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use agnosticTestRunner;
use package_utils 'install_package';

sub run {
    select_serial_terminal;

    install_package("gcc libgcrypt-devel crypto-policies-scripts", trup_continue => 1);

    my $libgcrypt_version = script_output(q(rpm -q --queryformat '%{VERSION}' libgcrypt20));
    record_info('libgcrypt', "version $libgcrypt_version");
    my $libgcrypt_devel_version = script_output(q(rpm -q --queryformat '%{VERSION}' libgcrypt-devel));
    record_info('libgcrypt-devel', "version $libgcrypt_devel_version");

    # Provide the C sources the Python test needs to compile
    my $data_prefix = 'security';
    for my $src (qw(libgcrypt-fips-check.c libgcrypt-sign-verify.c)) {
        assert_script_run("curl -o /tmp/$src " . data_url("$data_prefix/$src"), 90);
    }

    # Pass FIPS env vars so the pytest test can branch on mode
    my %env;
    $env{FIPS_ENV_MODE} = '1' if check_var('FIPS_ENV_MODE', '1');
    $env{FIPS_ENABLED} = '1' if check_var('FIPS_ENABLED', '1');
    if (%env) {
        my $exports = join(' ', map { "$_=$env{$_}" } keys %env);
        assert_script_run("export $exports");
    }

    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testLibgcryptExtended',
            domain => 'security',
        }
    );

    $test->setup()->run_test()->parse_results()->cleanup();
}

1;
