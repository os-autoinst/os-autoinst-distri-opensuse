# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module for azure stonith based fencing agent
# Settings:
#   FENCING_MECHANISM - needs to be set  to 'native'
#   PUBLIC_CLOUD_PROVIDER - needs to be set to 'AZURE'
#   AZURE_FENCE_AGENT_CONFIGURATION - set to 'msi' or 'spn' (default value: msi)
#   SPN related settings:
#       _SECRET_AZURE_SPN_APPLICATION_ID - application ID for fencing agent
#       _SECRET_AZURE_SPN_APP_PASSWORD - application password used by fencing agent

use strict;
use warnings FATAL => 'all';

use base 'sles4sap_publiccloud_basetest';
use serial_terminal 'select_serial_terminal';
use testapi;
use sles4sap_publiccloud;
use qesapdeployment;
use Data::Dumper;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    my $instances = $self->{instances} = $run_args->{instances};
    my $provider_client = $run_args->{instances}[0]{provider}{provider_client};
    my $fence_agent_configuration = get_var('AZURE_FENCE_AGENT_CONFIGURATION', 'msi');
    my $resource_group = qesap_az_get_resource_group();
    my $subscription_id = $provider_client->{subscription};
    my $tenant_id = check_var('AZURE_FENCE_AGENT_CONFIGURATION', 'spn') ? qesap_az_get_tenant_id($subscription_id) : '';
    my $spn_application_id = get_var('_SECRET_AZURE_SPN_APPLICATION_ID');
    my $spn_application_password = get_var('_SECRET_AZURE_SPN_APP_PASSWORD');
    my @cluster_nodes = @{$self->list_cluster_nodes()};

    die 'Resoruce group not found' unless $resource_group;
    die 'Tenant ID is required in case of Azure SPN fencing' if check_var('AZURE_FENCE_AGENT_CONFIGURATION', 'spn') and !$tenant_id;
    # Setting up credentials as variables so they do not show up in openQA outputs in plaintext
    my $bashrc_vars = "export SUBSCRIPTION_ID=$subscription_id
        export TENANT_ID=$tenant_id
        export SPN_APPLICATION_ID=$spn_application_id
        export SPN_APP_PASSWORD=$spn_application_password";

    my $fence_agent_cmd = join(' ',
        'fence_azure_arm',
        "-C \'\'",
        '--action=list',
        "--resourceGroup=$resource_group",
        '--subscriptionId=$SUBSCRIPTION_ID');

    $fence_agent_cmd = join(' ', $fence_agent_cmd, "--$fence_agent_configuration",) if $fence_agent_configuration eq 'msi';
    $fence_agent_cmd = join(' ', $fence_agent_cmd,
        '--username=$SPN_APPLICATION_ID',
        '--password=$SPN_APP_PASSWORD',
        '--tenantId=$TENANT_ID') if $fence_agent_configuration eq 'spn';

    select_serial_terminal;
    # prepare bashrc file - this way credentials ar enot presented in outputs
    save_tmp_file('bashrc', $bashrc_vars);
    assert_script_run('curl ' . autoinst_url . '/files/bashrc -o /tmp/bashrc');

    foreach my $instance (@$instances) {
        $self->{my_instance} = $instance;
        # do not probe VMs that are nto a part of cluster
        next unless grep(/^$instance->{instance_id}$/, @cluster_nodes);
        my $scp_cmd = join('', 'scp /tmp/bashrc ',
            $instance->{username},
            '@', $instance->{public_ip},
            ':/home/',
            $instance->{username},
            '/.bashrc');
        assert_script_run($scp_cmd);

        record_info('Test start', "Running test from $instance->{instance_id}.");
        my @nodes_ready = split(/[\n\s]/, $self->run_cmd(cmd => $fence_agent_cmd));

        foreach (@cluster_nodes) {
            die "VM '$_' " . uc($fence_agent_configuration) . ' is not configured correctly.'
              unless grep /^$_$/, @nodes_ready;
        }
        $self->display_full_status();
    }
}

1;
