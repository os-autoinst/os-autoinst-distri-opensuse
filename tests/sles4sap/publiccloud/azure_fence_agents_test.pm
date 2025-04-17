# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module for azure stonith based fencing agent
# Settings:
#   FENCING_MECHANISM - needs to be set  to 'native'
#   PUBLIC_CLOUD_PROVIDER - needs to be set to 'AZURE'
#   AZURE_FENCE_AGENT_CONFIGURATION - set to 'msi' or 'spn'
#   SPN related settings:
#       _SECRET_AZURE_SPN_APPLICATION_ID - application ID for fencing agent
#       _SECRET_AZURE_SPN_APP_PASSWORD - application password used by fencing agent

use strict;
use warnings FATAL => 'all';

use base 'sles4sap_publiccloud_basetest';
use serial_terminal 'select_serial_terminal';
use testapi;
use sles4sap_publiccloud;
use sles4sap::qesap::qesapdeployment;
use Data::Dumper;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;

    # Needed to have peering and ansible state propagated in post_fail_hook
    $self->import_context($run_args);

    my $instances = $self->{instances} = $run_args->{instances};
    my $provider_client = $run_args->{instances}[0]{provider}{provider_client};
    # This test module has only to be scheduled when:
    # - test is on Azure
    # -  fencing mechanism is native
    # In this combination, AZURE_FENCE_AGENT_CONFIGURATION is required
    my $fence_agent_configuration = get_required_var('AZURE_FENCE_AGENT_CONFIGURATION');
    my $resource_group = qesap_az_get_resource_group();
    my $subscription_id = $provider_client->{subscription};
    my @cluster_nodes = @{$self->list_cluster_nodes()};

    die 'Resoruce group not found' unless $resource_group;

    my @fence_agent_cmd_list = (
        'fence_azure_arm',
        "-C \'\'",
        '--action=list',
        "--resourceGroup=$resource_group",
        '--subscriptionId=$SUBSCRIPTION_ID');

    # Setting up credentials as variables so they do not show up in openQA outputs in plaintext
    my @bashrc_vars = ("export SUBSCRIPTION_ID=$subscription_id");

    if ($fence_agent_configuration eq 'spn') {
        my $spn_application_id = get_var('AZURE_SPN_APPLICATION_ID', get_required_var('_SECRET_AZURE_SPN_APPLICATION_ID'));
        my $spn_application_password = get_var('AZURE_SPN_APP_PASSWORD', get_required_var('_SECRET_AZURE_SPN_APP_PASSWORD'));

        push @bashrc_vars, "export SPN_APPLICATION_ID=$spn_application_id";
        push @bashrc_vars, "export SPN_APP_PASSWORD=$spn_application_password";

        my $tenant_id = qesap_az_get_tenant_id($subscription_id);
        die 'Tenant ID is required in case of Azure SPN fencing' unless $tenant_id;
        push @bashrc_vars, "export TENANT_ID=$tenant_id";

        push @fence_agent_cmd_list,
          '--username=$SPN_APPLICATION_ID',
          '--password=$SPN_APP_PASSWORD',
          '--tenantId=$TENANT_ID';
    }

    push @fence_agent_cmd_list, "--$fence_agent_configuration" if $fence_agent_configuration eq 'msi';

    select_serial_terminal;
    # prepare bashrc file - this way credentials are not presented in outputs
    save_tmp_file('bashrc', join("\n", @bashrc_vars));
    assert_script_run('curl ' . autoinst_url . '/files/bashrc -o /tmp/bashrc');

    foreach my $instance (@$instances) {
        $self->{my_instance} = $instance;
        # do not probe VMs that are not part of the cluster
        next unless grep(/^$instance->{instance_id}$/, @cluster_nodes);
        $instance->wait_for_ssh();
        my $scp_cmd = join('', 'scp /tmp/bashrc ',
            $instance->{username},
            '@', $instance->{public_ip},
            ':/home/',
            $instance->{username},
            '/.bashrc');
        assert_script_run($scp_cmd);

        record_info('Test start', "Running test from $instance->{instance_id}.");
        my @nodes_ready = split(/[\n\s]/, $self->run_cmd(cmd => join(' ', @fence_agent_cmd_list)));

        foreach (@cluster_nodes) {
            die "VM '$_' " . uc($fence_agent_configuration) . ' is not configured correctly.'
              unless grep /^$_$/, @nodes_ready;
        }
        $self->display_full_status();
    }
}

1;
