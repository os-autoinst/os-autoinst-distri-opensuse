# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Create network peering with IBSm for the crash test environment.

=head1 NAME

crash/network_peering.pm - Create a network peering with an IBSm server

=head1 DESCRIPTION

This module establishes a network peering between the crash test SUT and an
IBSm server, and configures the SUT to use the IBSm for software repositories.

Supported cloud providers are Azure (VNet Peering via B<IBSM_RG>),
GCP (NCC Spoke via B<IBSM_NCC_HUB>) and AWS (Transit Gateway via B<IBSM_IPRANGE>).

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Cloud provider: C<AZURE>, C<GCE> or C<EC2>.

=item B<IBSM_IP>

The IP address of the IBSm server. Added to C</etc/hosts> on the SUT.

=item B<IBSM_RG>

Azure Resource Group of the IBSm environment. Required for Azure.

=item B<IBSM_NCC_HUB>

Full NCC hub resource URI of the IBSm environment. Required for GCE.

=item B<IBSM_IPRANGE>

The IP range of the IBSm environment. Required for EC2.

=item B<IBSM_PRJ_TAG>

The project tag used to identify the Transit Gateway. Used for EC2.

=item B<INCIDENT_REPO>

An optional, comma-separated list of incident-specific repository URLs.

=item B<REPO_MIRROR_HOST>

The hostname to redirect to the IBSm. Defaults to C<download.suse.de>.

=back

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use sles4sap::crash qw(
  crash_network_peering_create
  crash_cleanup);

sub run {
    my ($self) = @_;
    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');

    select_serial_terminal;

    my %peering_args = (
        provider => $provider,
        ibsm_ip => get_required_var('IBSM_IP'),
        region => get_required_var('PUBLIC_CLOUD_REGION'),
        incident_repos => get_var('INCIDENT_REPO', ''),
        repo_host => get_var('REPO_MIRROR_HOST', 'download.suse.de'));

    if ($provider eq 'AZURE') {
        $peering_args{ibsm_rg} = get_required_var('IBSM_RG');
    }
    elsif ($provider eq 'GCE') {
        $peering_args{ibsm_ncc_hub} = get_required_var('IBSM_NCC_HUB');
        $peering_args{project} = get_required_var('PUBLIC_CLOUD_GOOGLE_PROJECT_ID');
        $peering_args{availability_zone} = get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE');
    }
    elsif ($provider eq 'EC2') {
        $peering_args{ibsm_ip_range} = get_required_var('IBSM_IPRANGE');
        $peering_args{ibsm_prj_tag} = get_var('IBSM_PRJ_TAG');
    }

    crash_network_peering_create(%peering_args);
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    my $provider = get_var('PUBLIC_CLOUD_PROVIDER');
    if ($provider) {
        my %clean_args = (provider => $provider, region => get_var('PUBLIC_CLOUD_REGION'), ibsm_rg => get_var('IBSM_RG'), ibsm_ip => get_var('IBSM_IP'));
        $clean_args{availability_zone} = get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE') if $provider eq 'GCE';
        crash_cleanup(%clean_args);
    }
    $self->SUPER::post_fail_hook;
}

1;
