# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: crypto-policies crypto-policies-scripts bind gnutls mozilla-nss mozilla-nss-tools openssl
# Summary: Switch crypto-policies, reboot and check sshd, BIND, GnuTLS and NSS
# - Install the packages needed by the test
# - For each policy: set it, reboot, then run the crypto-policies pytest suite
#   from data/security/openqa_agnostic/python/testCryptoPolicies with
#   CRYPTO_POLICY set, so the suite only checks the active policy
#
# Replaces tests/security/crypto_policies/crypto_policies_tests.pm.
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#208152

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use power_action_utils 'power_action';
use Utils::Backends 'is_pvm';
use package_utils 'install_package';
use agnosticTestRunner;
use utils 'reconnect_mgmt_console';

my %runner_args = (
    language => 'python',
    name => 'testCryptoPolicies',
    domain => 'security',
    run_timeout => 900,
);

sub run {
    my ($self) = @_;
    select_serial_terminal;
    install_package('crypto-policies crypto-policies-scripts bind gnutls mozilla-nss mozilla-nss-tools openssl', trup_reboot => 1);
    # a reboot on transactional systems leaves the VGA root console selected
    select_serial_terminal;

    # Download the test once, it stays in the home directory over the reboots
    my $setup = agnosticTestRunner->new({%runner_args})->setup();
    return if $setup->{skipped};

    for my $policy (qw(LEGACY BSI FUTURE DEFAULT)) {
        $self->set_policy($policy);
        assert_script_run("export CRYPTO_POLICY=$policy");
        # openQA names the external result after the pytest suite, which the
        # runner derives from "name": use one name per policy, but keep the
        # test directory that setup() downloaded
        agnosticTestRunner->new({
                %runner_args,
                name => "testCryptoPolicies_$policy",
                test_dir => '~/testCryptoPolicies',
                result_file => "/tmp/crypto_policies_$policy.xml",
        })->run_test()->parse_results();
    }
    $setup->cleanup();
}

sub set_policy {
    my ($self, $policy) = @_;
    assert_script_run "update-crypto-policies --set $policy";
    power_action('reboot', textmode => 1);
    reconnect_mgmt_console if is_pvm();
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    select_serial_terminal;
    # ensure the current policy has been applied
    validate_script_output 'update-crypto-policies --show', sub { m/$policy/ };
}

1;
