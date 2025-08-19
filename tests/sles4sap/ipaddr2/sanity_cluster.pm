# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Perform cluster sanity checks for the ipaddr2 test
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

ipaddr2/sanity_cluster.pm - Perform cluster sanity checks for the ipaddr2 test

=head1 DESCRIPTION

This module runs sanity checks specifically on the Pacemaker cluster created
for the ipaddr2 test. It verifies the cluster's health, ensuring that it is
properly configured and all resources are in the expected state.

It primarily calls the C<ipaddr2_cluster_sanity> function from the shared
library to perform the checks.


=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider. This module currently only supports 'AZURE'.

=item B<IPADDR2_DIAGNOSTIC>

If enabled (1), extended deployment logs (for example, boot diagnostics) are
collected on failure.

=item B<IPADDR2_CLOUDINIT>

This variable's state affects log collection on failure. If not set to 0
(default is enabled), cloud-init logs are collected.

=item B<IBSM_RG>

The name of the Azure Resource Group for the IBSm (Infrastructure Build and
Support mirror) environment. If this variable is set, the C<post_fail_hook>
will clean up the network peering on failure.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use sles4sap::qesap::qesapdeployment qw (qesap_az_vnet_peering_delete);
use sles4sap::ipaddr2 qw(
  ipaddr2_bastion_pubip
  ipaddr2_cluster_sanity
  ipaddr2_deployment_logs
  ipaddr2_infra_destroy
  ipaddr2_cloudinit_logs
  ipaddr2_azure_resource_group
);

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    my $bastion_ip = ipaddr2_bastion_pubip();
    ipaddr2_cluster_sanity(bastion_ip => $bastion_ip);
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    ipaddr2_deployment_logs() if check_var('IPADDR2_DIAGNOSTIC', 1);
    ipaddr2_cloudinit_logs() unless check_var('IPADDR2_CLOUDINIT', 0);
    if (my $ibsm_rg = get_var('IBSM_RG')) {
        qesap_az_vnet_peering_delete(source_group => ipaddr2_azure_resource_group(), target_group => $ibsm_rg);
    }
    ipaddr2_infra_destroy();
    $self->SUPER::post_fail_hook;
}

1;
