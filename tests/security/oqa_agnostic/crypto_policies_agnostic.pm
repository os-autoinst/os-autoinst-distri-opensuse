# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: crypto-policies crypto-policies-scripts bind gnutls mozilla-nss mozilla-nss-tools openssl
# Summary: Switch crypto-policies, reboot and check sshd, BIND, GnuTLS and NSS
# - Install the packages needed by the test
# - For each policy (LEGACY, BSI, FUTURE, CNSA-1.0, DEFAULT): set it, reboot,
#   then run the crypto-policies pytest suite from
#   data/security/openqa_agnostic/python/testCryptoPolicies with
#   CRYPTO_POLICY set, so the suite only checks the active policy
# - Skip CNSA-1.0, and log why, when the installed crypto-policies package
#   does not ship it
#
# Replaces tests/security/crypto_policies/crypto_policies_tests.pm.
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#208152, poo#210675

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

    # DEFAULT is the last one, so the system ends with the default policy
    for my $policy (qw(LEGACY BSI FUTURE CNSA-1.0 DEFAULT)) {
        # Only newer crypto-policies packages ship CNSA-1.0 (jsc#PED-16928)
        next if $policy eq 'CNSA-1.0' && !policy_shipped($policy);
        $self->set_policy($policy);
        assert_script_run("export CRYPTO_POLICY=$policy");
        # openQA names the external result after the pytest suite, which the
        # runner derives from "name": use one name per policy, but keep the
        # test directory that setup() downloaded. The openQA XUnit parser
        # drops the part of the name after the first dot, so do not use dots.
        (my $id = $policy) =~ tr/.-/__/;
        agnosticTestRunner->new({
                %runner_args,
                name => "testCryptoPolicies_$id",
                test_dir => '~/testCryptoPolicies',
                result_file => "/tmp/crypto_policies_$id.xml",
        })->run_test()->parse_results();
    }
    $setup->cleanup();
}

sub policy_shipped {
    my ($policy) = @_;
    return 1 if script_run("test -f /usr/share/crypto-policies/policies/$policy.pol") == 0;
    my $package = script_output('rpm -q crypto-policies', proceed_on_failure => 1);
    record_info("$policy skipped", "$package does not ship the $policy policy, skip it");
    return 0;
}

sub set_policy {
    my ($self, $policy) = @_;
    assert_script_run "update-crypto-policies --set $policy";
    power_action('reboot', textmode => 1);
    reconnect_mgmt_console if is_pvm();
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    select_serial_terminal;
    # ensure the current policy has been applied
    validate_script_output 'update-crypto-policies --show', sub { m/^\Q$policy\E\s*$/m };
}

1;
