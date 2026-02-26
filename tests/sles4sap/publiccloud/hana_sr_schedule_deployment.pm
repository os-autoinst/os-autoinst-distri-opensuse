# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Test module for scheduling qesap-deployment related modules.
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/publiccloud/hana_sr_schedule_deployment.pm - Schedules the deployment of the test environment.

=head1 DESCRIPTION

This module schedules a sequence of other test modules to deploy the necessary
test environment. The deployment process can be customized based on the provided
settings. It can either create a new infrastructure using Terraform and configure it
with Ansible, or it can reuse an existing infrastructure. It also performs
pre-validation checks and, if configured, tests the Azure fence agent.

=head1 SETTINGS

=over

=item B<QESAP_DEPLOYMENT_IMPORT>

If set, the module will schedule tests to reuse an existing infrastructure
instead of creating a new one.

=item B<IS_MAINTENANCE>

If set to '1', additional maintenance-related tests are scheduled, such as
repository validation and cleaning up leftover network peerings.

=item B<FENCING_MECHANISM>

If set to 'native' and the provider is Azure, it schedules a test to verify
the Azure fence agent configuration.

=item B<AZURE_FENCE_AGENT_CONFIGURATION>

Specifies the configuration method for the Azure fence agent (e.g., 'msi', 'spn').
This is used to name the fence agent test.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

package hana_sr_schedule_deployment;

use base 'sles4sap::publiccloud_basetest';
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
        loadtest('sles4sap/publiccloud/qesap_configure', name => 'qesap_configure', run_args => $run_args, @_);
        loadtest('sles4sap/publiccloud/qesap_terraform', name => 'deploy_qesap_terraform', run_args => $run_args, @_);
        loadtest('sles4sap/publiccloud/qesap_instances_preparation', name => 'qesap_instances_preparation', run_args => $run_args, @_);
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
