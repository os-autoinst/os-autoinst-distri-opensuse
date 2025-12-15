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

    qesap_ansible_cmd(
        cmd => 'sudo systemctl is-system-running',
        provider => $provider_setting,
        filter => '"hana[0]"',
        timeout => 300);
}

sub post_fail_hook {
    my ($self) = shift;
    # This test module does not have the fatal flag.
    # In case of failure, the next test_ module is executed too.
    # Deployment destroy is delegated to the destroy test module
    $self->SUPER::post_fail_hook;
}

1;
