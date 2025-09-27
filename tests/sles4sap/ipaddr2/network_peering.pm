# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Create network peering with IBSm
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

ipaddr2/network_peering.pm - Create a network peering with an IBSm server

=head1 DESCRIPTION

This module establishes a network peering between the ipaddr2 test
environment and an IBSm server.

The module performs two main tasks:

- It creates an Azure VNet peering between the test's virtual network and the
  IBSm's virtual network.
- It configures the SUT (System Under Test) VMs to use the IBSm for software
  repositories by adding an entry to `/etc/hosts` and configuring any specified
  incident repositories.

=head1 SETTINGS

=over

=item B<IBSM_RG>

The name of the Azure Resource Group for the IBSm environment. This is
required to create the VNet peering.

=item B<IBSM_IP>

The IP address of the IBSm server. This is required to add an entry to the
`/etc/hosts` file on the SUT VMs, redirecting repository traffic.

=item B<INCIDENT_REPO>

An optional, comma-separated list of incident-specific repository URLs. If provided,
these repositories will be added to the SUTs' package manager configuration.

=item B<REPO_MIRROR_HOST>

The hostname of the repository server to be redirected to the IBSm.
Defaults to `download.suse.de`.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use sles4sap::ipaddr2 qw(
  ipaddr2_network_peering_create
  ipaddr2_repos_add_server_to_hosts
  ipaddr2_cleanup
  ipaddr2_logs_collect);

sub run {
    my ($self) = @_;

    select_serial_terminal;

    # Create network peering
    ipaddr2_network_peering_create(ibsm_rg => get_required_var('IBSM_RG'));

    ipaddr2_repos_add_server_to_hosts(
        ibsm_ip => get_required_var('IBSM_IP'),
        incident_repos => get_var('INCIDENT_REPO', ''),
        repo_host => get_var('REPO_MIRROR_HOST', 'download.suse.de'));
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
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
