# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Prepare instance data and verifications.
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/publiccloud/qesap_instances_preparation.pm - Prepare PC instance object data and verify hostnames

=head1 DESCRIPTION

This module processes the instances created by the previous deployment step.
It collects IP addresses, verifies that hostnames match the expected names from the infrastructure definition,
and ensures SSH connectivity.
It also configures native fencing permissions for Azure when using Managed Service Identity (MSI).

Its primary tasks are:

=over

=item - Create and populate the PublicCloud instance object data with environment informations and data from terraform output.

=item - Verify connectivity and hostname consistency for all instances.

=item - Setup Azure native fencing permissions for MSI configurations.

=item - Initialize SSH options for future CLI interactions.

=back

=head1 SETTINGS

=over

=item B<FENCING_MECHANISM>

Used to determine if native fencing is needed.

=item B<AZURE_FENCE_AGENT_CONFIGURATION>

Check if 'msi' is used for Azure fencing.

=item B<PUBLIC_CLOUD_PROVIDER>

CSP provider name (used for CSP-specific validation).

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

package qesap_instances_preparation;

use base 'sles4sap::publiccloud_basetest';
use testapi;
use publiccloud::ssh_interactive 'select_host_console';
use serial_terminal 'select_serial_terminal';
use publiccloud::utils qw(is_azure is_gce);
use sles4sap::publiccloud;
use sles4sap::qesap::qesapdeployment;
use sles4sap::qesap::azure;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    my $provider = $run_args->{my_provider} or die "No provider in run_args";
    $self->{provider} = $provider;

    # Select console on the host (not the PC instance) to reset 'TUNNELED',
    # otherwise select_serial_terminal() will be failed
    select_host_console();
    select_serial_terminal();

    my $instances = create_instance_data(provider => $provider);
    foreach my $instance (@$instances) {
        record_info 'Instance', join(' ', 'IP: ', $instance->public_ip, 'Name: ', $instance->instance_id);
        $self->{my_instance} = $instance;
        $self->set_cli_ssh_opts;
        my $expected_hostname = $instance->{instance_id};
        # We need to scan for the SSH host key as the Ansible later
        $instance->update_instance_ip();
        $instance->wait_for_ssh();

        my $real_hostname = $instance->ssh_script_output(cmd => 'hostname', username => 'cloudadmin');
        # We expect hostnames reported by terraform to match the actual hostnames in Azure and GCE
        die "Expected hostname $expected_hostname is different than actual hostname [$real_hostname]"
          if ((is_azure() || is_gce()) && ($expected_hostname ne $real_hostname));

        if (get_var('FENCING_MECHANISM') eq 'native' && is_azure() && check_var('AZURE_FENCE_AGENT_CONFIGURATION', 'msi')) {
            qesap_az_setup_native_fencing_permissions(
                vm_name => $instance->instance_id,
                resource_group => qesap_az_get_resource_group());
        }
    }

    $self->{instances} = $run_args->{instances} = $instances;
    $self->{instance} = $run_args->{my_instance} = $run_args->{instances}[0];
    $self->{provider} = $run_args->{my_provider} = $provider;
    record_info('Preparation OK');
}

1;
