# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module for scheduling qesap-deployment related modules.

package hana_sr_schedule_deployment;

use warnings FATAL => 'all';
use base 'sles4sap_publiccloud_basetest';
use testapi;
use main_common 'loadtest';
use publiccloud::utils 'is_azure';

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;

    # Needed to have ansible state propagated in post_fail_hook
    $self->import_context($run_args);

    if (get_var('QESAP_DEPLOYMENT_IMPORT')) {
        loadtest('sles4sap/publiccloud/qesap_reuse_infra', name => 'prepare_existing_infrastructure', run_args => $run_args, @_);
        loadtest('sles4sap/publiccloud/qesap_ansible', name => 'deploy_qesap_ansible', run_args => $run_args, @_);
        loadtest('sles4sap/publiccloud/qesap_prevalidate', name => 'qesap_prevalidate', run_args => $run_args, @_);
    }
    else {
        if (check_var('IS_MAINTENANCE', 1)) {
            loadtest('publiccloud/validate_repos', name => 'validate_repos', run_args => $run_args, @_);
        }
        loadtest('sles4sap/publiccloud/qesap_terraform', name => 'deploy_qesap_terraform', run_args => $run_args, @_);
        if (check_var('IS_MAINTENANCE', 1)) {
            loadtest('sles4sap/publiccloud/clean_leftover_peerings', name => 'clean_leftover_peerings', run_args => $run_args, @_);
        }
        loadtest('sles4sap/publiccloud/qesap_ansible', name => 'deploy_qesap_ansible', run_args => $run_args, @_);
        loadtest('sles4sap/publiccloud/qesap_prevalidate', name => 'qesap_prevalidate', run_args => $run_args, @_);
    }
    if (check_var('FENCING_MECHANISM', 'native') and is_azure) {
        # MSI is preferred method not requiring additional password so it is set to default.
        my $fence_agent_setup_type = uc(get_required_var('AZURE_FENCE_AGENT_CONFIGURATION'));
        my $test_name = "Verify_azure_fence_agent_$fence_agent_setup_type";
        loadtest('sles4sap/publiccloud/azure_fence_agents_test', name => $test_name, run_args => $run_args, @_);
    }
}

1;
