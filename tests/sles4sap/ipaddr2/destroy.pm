# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Destroy the SUT for the ipaddr2 test
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

ipaddr2/destroy.pm - Destroy the infrastructure for the ipaddr2 test

=head1 DESCRIPTION

This module is responsible for cleaning up and destroying all the Azure
resources created for the ipaddr2 test.

Its main tasks are:

- If a network peering was established with an IBSm (Infrastructure Build and
  Support mirror) environment, it deletes the peering connection.
- It destroys the entire Azure Resource Group, which contains all VMs,
  networks, and other resources created by the C<deploy.pm> module.

This module is typically the last one to run in the test suite.

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Used to check the public cloud provider. Currently, only 'AZURE' is supported.

=item B<IBSM_RG>

The name of the Azure Resource Group for the IBSm (Infrastructure Build and
Support mirror) environment. If this variable is set, it indicates that a
network peering was established and needs to be cleaned up.

=item B<IPADDR2_DIAGNOSTIC>

If enabled (1), extended deployment logs (for example, boot diagnostics) are
collected on failure.

=item B<IPADDR2_CLOUDINIT>

This variable's state affects log collection on failure. If not set to 0
(default is enabled), cloud-init logs are collected.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use mmapi qw( get_current_job_id );
use sles4sap::ibsm qw( ibsm_network_peering_azure_delete );
use sles4sap::ipaddr2 qw(
  ipaddr2_bastion_pubip
  ipaddr2_infra_destroy
  ipaddr2_azure_resource_group
  ipaddr2_cleanup
  ipaddr2_logs_collect
  ipaddr2_logs_cloudinit
  ipaddr2_ssh_intrusion_detection);

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    my $bastion_ip = ipaddr2_bastion_pubip();

    ipaddr2_ssh_intrusion_detection(bastion_ip => $bastion_ip);
    ipaddr2_logs_cloudinit(bastion_ip => $bastion_ip) unless (check_var('IPADDR2_CLOUDINIT', 0));
    ipaddr2_logs_collect(bastion_ip => $bastion_ip);

    if (my $ibsm_rg = get_var('IBSM_RG')) {
        ibsm_network_peering_azure_delete(
            sut_rg => ipaddr2_azure_resource_group(),
            sut_vnet => get_current_job_id(),
            ibsm_rg => $ibsm_rg);
    }
    ipaddr2_infra_destroy();
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    ipaddr2_logs_collect();
    ipaddr2_cleanup(
        diagnostic => get_var('IPADDR2_DIAGNOSTIC', 0),
        cloudinit => get_var('IPADDR2_CLOUDINIT', 1),
        ibsm_rg => get_var('IBSM_RG'));
    $self->SUPER::post_fail_hook;
}

1;
