# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test system recovery after a forced crash
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

qesapdeployment/test_crash.pm - Test system recovery after a forced crash

=head1 DESCRIPTION

Tests the resilience of a cluster node by intentionally triggering
a kernel panic using the 'sysrq-trigger'. It forces one of the HANA nodes to
crash and reboot. The test then verifies that the node comes back online and
the system is in a running state by executing commands via Ansible after the
reboot. This ensures that the VM and its basic services can recover from an
unexpected failure.

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider, which is required for running Ansible commands.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use sles4sap::publiccloud;
use sles4sap::qesap::qesapdeployment;

sub run {
    my ($self) = @_;
    my $provider_setting = get_required_var('PUBLIC_CLOUD_PROVIDER');

    # Not test so much for the moment,
    # just that crash trough Ansible does not hang Ansible execution
    qesap_ansible_cmd(
        cmd => 'sudo echo b > /proc/sysrq-trigger &',
        provider => $provider_setting,
        filter => '"hana[0]"',
        timeout => 300);

    # Check that if comes back to life
    qesap_ansible_cmd(
        cmd => 'echo \"I am back\"',
        provider => $provider_setting,
        filter => '"hana[0]"',
        timeout => 300);

    # Failed units tolerated in 'degraded' state, with the soft failure for each
    my %known_failed_units = (
        'aidecheck.service' => 'bsc#1289744 - aidecheck.service failed at boot',
    );
    my %ansible_args = (provider => $provider_setting, host => '"hana[0]"', root => 1, timeout => 300);

    my $state = qesap_ansible_script_output(%ansible_args, cmd => 'systemctl is-system-running', failok => 1);
    record_info('System state', $state);
    return if $state =~ /^\s*running\s*$/;
    die "System not running after crash: $state" unless $state =~ /^\s*degraded\s*$/;

    # In case of service failures, check for known cases
    my @failed_units = map { (split)[0] } grep { /\S/ } split /\n/,
      qesap_ansible_script_output(%ansible_args, cmd => 'systemctl --failed --no-legend --plain --no-pager');
    my @unknown_units = grep { !exists $known_failed_units{$_} } @failed_units;
    die "Failed units after crash: @unknown_units" if @unknown_units;
    foreach my $reference (@known_failed_units{@failed_units}) { record_soft_failure($reference) }
}

sub post_fail_hook {
    my ($self) = shift;
    # This test module does not have the fatal flag.
    # In case of failure, the next test_ module is executed too.
    # Deployment destroy is delegated to the destroy test module
    $self->SUPER::post_fail_hook;
}

1;
