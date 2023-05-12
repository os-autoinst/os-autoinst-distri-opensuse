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
    qesap_az_vnet_peering_delete(source_group => qesap_az_get_resource_group(),
        target_group => get_required_var('IBSM_RG'));
}

1;
