# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Public Cloud - Resource Cleanup
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/crash/destroy.pm - Public Cloud Resource Cleanup

=head1 DESCRIPTION

C<destroy.pm> handles the deletion of cloud resources created during the crash test execution
to ensure the environment is cleaned up and to avoid unnecessary costs.

Its primary tasks are:

=over

=item * Identify the cloud provider and region from the test configuration.

=item * Perform cleanup of VM instances, networking, and security groups via C<crash_cleanup>.

=item * Handle optional cleanup of IBSm-related resources if configured.

=back

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

The cloud provider used: 'EC2', 'AZURE', or 'GCE'. Required.

=item B<PUBLIC_CLOUD_REGION>

Cloud region where resources were created. Required.

=item B<PUBLIC_CLOUD_AVAILABILITY_ZONE>

Availability zone for the cloud provider. Required for GCE.

=item B<IBSM_RG>

Azure Resource Group of the IBSm server. Optional.

=item B<IBSM_IP>

IP address of the IBSm server. Optional.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use sles4sap::crash;

sub run {
    my ($self) = @_;
    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my $region = get_required_var('PUBLIC_CLOUD_REGION');

    select_serial_terminal;
    my %cleanup_args = (provider => $provider, region => $region, ibsm_rg => get_var('IBSM_RG'), ibsm_ip => get_var('IBSM_IP'));
    $cleanup_args{availability_zone} = get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE') if $provider eq 'GCE';
    crash_cleanup(%cleanup_args);
}

sub test_flags {
    return {fatal => 1};
}

1;
