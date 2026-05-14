# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
# Summary: Run zypper patch and reboot
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/crash/patch_system.pm - Apply system patches to the SUT

=head1 DESCRIPTION

C<patch_system.pm> performs a standard system update on the SUT (System Under Test) by executing C<zypper patch> and then rebooting the system. This ensures that all updates, including kernel updates, are correctly applied and active before subsequent crash testing.

Its primary tasks are:

=over

=item * Identify the cloud provider and region for the SUT.

=item * Apply system patches and reboot the SUT via C<crash_patch_system>.

=item * Wait for the SUT to come back online after the reboot.

=back

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Cloud provider used: 'EC2', 'AZURE', or 'GCE'. Required.

=item B<PUBLIC_CLOUD_REGION>

Cloud region where the SUT is deployed. Required.

=item B<PUBLIC_CLOUD_AVAILABILITY_ZONE>

Availability zone for the cloud provider. Required for GCE.

=item B<IBSM_RG>

Azure Resource Group of the IBSm server. Optional (used in cleanup).

=item B<IBSM_IP>

IP address of the IBSm server. Optional (used in cleanup).

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use sles4sap::crash;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my %crash_args = (
        provider => $provider,
        region => get_required_var('PUBLIC_CLOUD_REGION')
    );
    $crash_args{availability_zone} = get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE') if $provider eq 'GCE';

    crash_patch_system(%crash_args);
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my %clean_args = (provider => $provider, region => get_required_var('PUBLIC_CLOUD_REGION'), ibsm_rg => get_var('IBSM_RG'), ibsm_ip => get_var('IBSM_IP'));
    $clean_args{availability_zone} = get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE') if $provider eq 'GCE';
    crash_cleanup(%clean_args);
    $self->SUPER::post_fail_hook;
}

1;
