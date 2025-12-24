# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test module for azure stonith based fencing agent
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

azure_fence_agents_test.pm - Test module for azure stonith based fencing agent

=head1 DESCRIPTION

This module tests the Azure fence agent. It verifies that the fence agent,
configured with either MSI (Managed Service Identity) or SPN (Service Principal Name),
can successfully list the cluster nodes. This ensures that the fencing mechanism
is correctly configured and operational.

=head1 SETTINGS

=over

=item B<FENCING_MECHANISM>

Specifies the fencing mechanism. Must be set to 'native' for this test.

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider. Must be set to 'AZURE' for this test.

=item B<AZURE_FENCE_AGENT_CONFIGURATION>

Specifies the Azure fence agent configuration method. Can be 'msi' or 'spn'.

=item B<_SECRET_AZURE_SPN_APPLICATION_ID>

The application ID for the Service Principal Name (SPN) used by the fencing agent.
Required when B<AZURE_FENCE_AGENT_CONFIGURATION> is 'spn'.

=item B<_SECRET_AZURE_SPN_APP_PASSWORD>

The application password for the Service Principal Name (SPN) used by the fencing agent.
Required when B<AZURE_FENCE_AGENT_CONFIGURATION> is 'spn'.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use base 'sles4sap_publiccloud_basetest';
use serial_terminal 'select_serial_terminal';
use testapi;
use sles4sap_publiccloud;
use sles4sap::qesap::qesapdeployment;
use sles4sap::qesap::azure;
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

        my $tenant_id = az_account_show(query => 'tenantId');
        die "Returned output '$tenant_id' does not match ID pattern" unless (az_validate_uuid_pattern(uuid => $tenant_id));
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
        $instance->update_instance_ip();
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
