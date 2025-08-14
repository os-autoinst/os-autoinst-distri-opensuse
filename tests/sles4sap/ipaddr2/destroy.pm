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

=head1 VARIABLES

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Used to check the public cloud provider. Currently, only 'AZURE' is supported.

=item B<IBSM_RG>

The name of the Azure Resource Group for the IBSm (Infrastructure Build and
Support mirror) environment. If this variable is set, it indicates that a
network peering was established and needs to be cleaned up.

=item B<IPADDR2_DIAGNOSTIC>

If enabled (1), extended deployment logs (e.g., boot diagnostics) are
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
use sles4sap::qesap::qesapdeployment qw (qesap_az_vnet_peering_delete);
use sles4sap::ipaddr2 qw(
  ipaddr2_deployment_logs
  ipaddr2_infra_destroy
  ipaddr2_cloudinit_logs
  ipaddr2_azure_resource_group
  ipaddr2_ip_get);

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    if (my $ibsm_rg = get_var('IBSM_RG')) {
        qesap_az_vnet_peering_delete(source_group => ipaddr2_azure_resource_group(), target_group => $ibsm_rg);
    }
    unless (check_var('IPADDR2_CLOUDINIT', 0)) {
        my %ip = ipaddr2_ip_get(slot => get_var('WORKER_ID'));
        ipaddr2_cloudinit_logs(priv_ip_range => $ip{priv_ip_range});
    }
    ipaddr2_infra_destroy();
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    ipaddr2_deployment_logs() if check_var('IPADDR2_DIAGNOSTIC', 1);
    unless (check_var('IPADDR2_CLOUDINIT', 0)) {
        my %ip = ipaddr2_ip_get(slot => get_var('WORKER_ID'));
        ipaddr2_cloudinit_logs(priv_ip_range => $ip{priv_ip_range});
    }
    if (my $ibsm_rg = get_var('IBSM_RG')) {
        qesap_az_vnet_peering_delete(source_group => ipaddr2_azure_resource_group(), target_group => $ibsm_rg);
    }
    ipaddr2_infra_destroy();
    $self->SUPER::post_fail_hook;
}

1;
