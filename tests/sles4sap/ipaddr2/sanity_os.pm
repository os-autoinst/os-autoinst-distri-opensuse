# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Perform OS and cluster sanity checks for the ipaddr2 test
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

ipaddr2/sanity_os - Perform OS and cluster sanity checks for the ipaddr2 test

=head1 DESCRIPTION

This module performs verifies the operating system (OS) configuration
of the SUT.

The OS-level checks verify network configuration, connectivity between nodes,
SSH key setup for the configured user, systemd state, and cloud-init status.

=head1 VARIABLES

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider. This module currently only supports 'AZURE'.

=item B<IPADDR2_ROOTLESS>

Determines the user context for the SSH sanity checks. If set to 1, it validates
the configuration for a rootless cluster setup (using the 'cloudadmin' user).
If set to 0 or not defined (default), it validates the configuration for a
cluster running as 'root'.

=item B<IPADDR2_DIAGNOSTIC>

If enabled (1), extended deployment logs (e.g., boot diagnostics) are collected on failure.

=item B<IPADDR2_CLOUDINIT>

This variable's state affects log collection on failure. If not set to 0 (default is enabled),
cloud-init logs are collected, assuming it was used during deployment.

=item B<IBSM_RG>

The name of the Azure Resource Group for the IBSm (Infrastructure Build and Support mirror)
environment. If this variable is set, it indicates that a network peering was
established. This module uses it in the C<post_fail_hook> to clean up the
peering connection if the test fails.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use sles4sap::qesap::qesapdeployment qw (qesap_az_vnet_peering_delete);
use sles4sap::ipaddr2 qw(
  ipaddr2_bastion_pubip
  ipaddr2_deployment_logs
  ipaddr2_infra_destroy
  ipaddr2_cloudinit_logs
  ipaddr2_os_sanity
  ipaddr2_azure_resource_group
  ipaddr2_ip_get);

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    my $bastion_ip = ipaddr2_bastion_pubip();
    my %ip = ipaddr2_ip_get(slot => get_var('WORKER_ID'));

    # Default for ipaddr2_os_sanity is cloudadmin.
    # It has to know about it to decide which ssh are expected in internal VMs
    my %sanity_args = (bastion_ip => $bastion_ip, priv_ip_range => $ip{priv_ip_range});
    $sanity_args{user} = 'root' unless check_var('IPADDR2_ROOTLESS', '1');
    ipaddr2_os_sanity(%sanity_args);
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
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
