# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Clean up old network peerings on Azure
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/publiccloud/clean_leftover_peerings.pm - Clean up old network peerings on Azure

=head1 DESCRIPTION

This module cleans up old network peerings in the specified Azure Resource Group.

Its primary tasks are:

- Check if the provider is Azure.
- Verify `IBSM_RG` variable is set.
- Retrieve the VNet name for the resource group.
- Delete old peerings associated with the Resource Group and VNet.

=head1 SETTINGS

=over

=item B<IBSM_RG>

The Azure Resource Group containing the IBSM (Internal Build Service Mirror). Required.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use base 'sles4sap::sles4sap_publiccloud_basetest';
use testapi;
use sles4sap::qesap::azure qw(qesap_az_clean_old_peerings);
use publiccloud::utils qw(is_azure);
use sles4sap::azure_cli;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    return 0 unless (is_azure);
    if (!get_var('IBSM_RG')) {
        record_info('NO IBSM', 'No IBSM_RG variable found. Exiting');
        return 0;
    }
    my $group = get_var('IBSM_RG');
    qesap_az_clean_old_peerings(
        rg => $group,
        vnet => az_network_vnet_get(resource_group => $group, query => "[0].name"));
}

1;
