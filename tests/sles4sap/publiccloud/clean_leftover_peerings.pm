# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deployment steps for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>

use strict;
use warnings;
use base 'sles4sap_publiccloud_basetest';
use testapi;
use qesapdeployment;
use publiccloud::utils qw(is_azure is_ec2);

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    if (is_azure) {
        if (!get_var('IBSM_RG')) {
            record_info('NO IBSM', 'No IBSM_RG variable found. Exiting');
            return 0;
        }
        my $group = get_var('IBSM_RG');
        my $vnet_name = qesap_az_get_vnet($group);
        qesap_az_clean_old_peerings(rg => $group, vnet => $vnet_name);
    }
}

1;
