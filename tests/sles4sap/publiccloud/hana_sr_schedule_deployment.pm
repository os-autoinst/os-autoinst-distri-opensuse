# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module for scheduling qesap-deployment related modules.

package hana_sr_schedule_deployment;

use strict;
use warnings FATAL => 'all';
use base 'sles4sap_publiccloud_basetest';
use main_common 'loadtest';
use testapi;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    $self->{network_peering_present} = 1 if ($run_args->{network_peering_present});

    if (get_var('QESAP_DEPLOYMENT_IMPORT')) {
        loadtest('sles4sap/publiccloud/qesap_reuse_infra', name => 'prepare_existing_infrastructure', run_args => $run_args, @_);
        loadtest('sles4sap/publiccloud/qesap_ansible', name => 'verify_infrastructure', run_args => $run_args, @_);
    }
    else {
        loadtest('sles4sap/publiccloud/qesap_terraform', name => 'deploy_qesap_terraform', run_args => $run_args, @_);
        if (check_var('IS_MAINTENANCE', 1)) {
            loadtest('sles4sap/publiccloud/network_peering', name => 'network_peering', run_args => $run_args, @_);
            loadtest('sles4sap/publiccloud/add_server_to_hosts', name => 'add_server_to_hosts', run_args => $run_args, @_);
            loadtest('sles4sap/publiccloud/cluster_add_repos', name => 'cluster_add_repos', run_args => $run_args, @_);
            loadtest('sles4sap/publiccloud/general_patch_and_reboot', name => 'general_patch_and_reboot', run_args => $run_args, @_);
        }
        loadtest('sles4sap/publiccloud/qesap_ansible', name => 'deploy_qesap_ansible', run_args => $run_args, @_);
    }
}

1;
