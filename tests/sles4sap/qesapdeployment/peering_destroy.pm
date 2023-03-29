# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deployment steps for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use mmapi 'get_current_job_id';
use Mojo::Base 'publiccloud::basetest';
use testapi;
use qesapdeployment;

sub run {
    my $rg = qesap_get_az_resource_group();
    my $vn = qesap_get_vnet($rg);
    my $target_rg = get_required_var('QESAP_TARGET_RESOURCE_GROUP');
    my $target_vn = get_required_var('QESAP_TARGET_VN');
    qesap_delete_az_peering(source_group => $rg, source_vnet => $vn, target_group => $target_rg, target_vnet => $target_vn);
}

1;
