# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Create a network peering to the IBSm
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

cloud_zypper_patch/network_peering.pm - Create a network peering to the IBSm

=head1 DESCRIPTION

This module establishes a network peering between the test environment and an
IBSm (Infrastructure Build and Support mirror) server. This is necessary to
allow the SUT (System Under Test) to access the repositories hosted on the IBSm.

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider. This module currently only supports 'AZURE'.

=item B<IBSM_RG>

The name of the Azure Resource Group for the IBSm environment. This is
required to create the VNet peering.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use sles4sap::cloud_zypper_patch;

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    zp_azure_netpeering(target_rg => get_required_var('IBSM_RG'));
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    zp_azure_destroy(ibsm_rg => get_required_var('IBSM_RG'));
    $self->SUPER::post_fail_hook;
}

1;
