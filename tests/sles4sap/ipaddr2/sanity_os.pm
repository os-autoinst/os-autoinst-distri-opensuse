# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Perform OS and cluster sanity checks for the ipaddr2 test
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

ipaddr2/sanity_os - Perform OS and cluster sanity checks for the ipaddr2 test

=head1 DESCRIPTION

This module performs a series of sanity checks on the deployed infrastructure
for the ipaddr2 test. It verifies both the operating system (OS) configuration
of the SUT (System Under Test) VMs and the basic health of the Pacemaker cluster.

The OS-level checks verify network configuration, connectivity between nodes,
SSH key setup for the configured user, systemd state, and cloud-init status.

The cluster-level checks validate the overall status of the Pacemaker cluster
and ensure all configured resources are running as expected.

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider. This module currently only supports 'AZURE'.

=item B<IPADDR2_ROOTLESS>

Determines the user context for the SSH sanity checks. If set to 1, it validates
the configuration for a rootless cluster setup (using the 'cloudadmin' user).
If set to 0 or not defined (default), it validates the configuration for a
cluster running as 'root'.

=item B<IPADDR2_DIAGNOSTIC>

If enabled (1), extended deployment logs (for example, boot diagnostics) are collected on failure.

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

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use sles4sap::ipaddr2 qw(
  ipaddr2_bastion_pubip
  ipaddr2_os_sanity
  ipaddr2_cleanup
  ipaddr2_logs_collect);

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    my $bastion_ip = ipaddr2_bastion_pubip();

    # Default for ipaddr2_os_sanity is cloudadmin.
    # It has to know about it to decide which ssh are expected in internal VMs
    my %sanity_args = (bastion_ip => $bastion_ip);
    $sanity_args{user} = 'root' unless check_var('IPADDR2_ROOTLESS', '1');
    ipaddr2_os_sanity(%sanity_args);
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
