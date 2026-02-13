# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Utility functions to interact with the IBS Mirror
# Maintainer: QE-SAP <qe-sap@suse.de>

## no critic (RequireFilenameMatchesPackage);

=encoding utf8

=head1 NAME

    IBS Mirror utilities lib

=head1 COPYRIGHT

    Copyright 2025 SUSE LLC
    SPDX-License-Identifier: FSFAP

=head1 AUTHORS

    QE SAP <qe-sap@suse.de>

=cut

package sles4sap::ibsm;

use strict;
use warnings;
use Carp qw(croak);
use Exporter 'import';
use testapi;
use sles4sap::azure_cli;

our @EXPORT = qw(
  ibsm_calculate_address_range
  ibsm_network_peering_azure_create
  ibsm_network_peering_azure_delete
);

=head1 DESCRIPTION

    Package with common methods allowing the SUT to interact with IBSm

=head2 Methods


=head3 ibsm_calculate_address_range

Calculate a main range that can be used in Azure for vnet or in AWS for vpc.
Also calculate a secondary range within the main one for Azure subnet address ranges.
The format is 10.ip2.ip3.0/21 and /24 respectively.
ip2 and ip3 are calculated using the slot number as seed.

=over

=item B<slot> - integer to be used as seed in calculating addresses

=back

=cut

sub ibsm_calculate_address_range {
    my %args = @_;
    croak 'Missing mandatory slot argument' unless $args{slot};
    die "Invalid 'slot' argument - valid values are 1-8192" if ($args{slot} > 8192 || $args{slot} < 1);
    my $offset = ($args{slot} - 1) * 8;

    # addresses are of the form 10.ip2.ip3.0/21 and /24 respectively
    #ip2 gets incremented when it is >=256
    my $ip2 = int($offset / 256);
    #ip3 gets incremented by 8 until it's >=256, then it resets
    my $ip3 = $offset % 256;

    return (
        main_address_range => sprintf("10.%d.%d.0/21", $ip2, $ip3),
        subnet_address_range => sprintf("10.%d.%d.0/24", $ip2, $ip3),
    );
}

sub _get_peering_name {
    my ($prefix, $src_vnet, $dst_vnet) = @_;
    return join('-', ($prefix ? $prefix : ()), $src_vnet, $dst_vnet);
}

sub _get_vnet_name {
    my (%args) = @_;
    my $res = az_network_vnet_get(%args);
    die "Expected exactly one VNET name for resource group $args{resource_group} but found " . scalar(@$res) if scalar(@$res) != 1;
    return $res->[0];
}

=head2 ibsm_network_peering_azure_create

    ibsm_network_peering_azure_create(
        ibsm_rg => 'IBSmRg',
        sut_rg => 'SUTRg',
        name_prefix => 'something');

Create two peering in Azure. Given two resource group names,
this function first calculate two peering names.
The caller can provide a prefix but name also contain the vnet names from the two resource groups.

=over

=item B<ibsm_rg> - Azure resource group of the IBSm

=item B<sut_rg> - Azure resource group of the SUT

=item B<name_prefix> - prefix to be applied at the beginning of each peering name

=back
=cut

sub ibsm_network_peering_azure_create {
    my (%args) = @_;
    foreach (qw(ibsm_rg sut_rg)) { croak("Argument < $_ > missing") unless $args{$_}; }

    my %vnet_names;
    my @peerings = (
        {src => 'sut_rg', dst => 'ibsm_rg'},
        {src => 'ibsm_rg', dst => 'sut_rg'}
    );

    foreach my $p (@peerings) {
        # Retrieve VNET names from Azure. Use argument names ('sut_rg', 'ibsm_rg') as key to same them.
        foreach my $rg_arg (values %$p) {
            $vnet_names{$rg_arg} //= _get_vnet_name(resource_group => $args{$rg_arg}, query => '[].name');
        }

        # Generate the unique name for the peering based on the source and destination VNETs.
        my $name = _get_peering_name($args{name_prefix}, $vnet_names{$p->{src}}, $vnet_names{$p->{dst}});

        # Create the network peering in the specified direction.
        az_network_peering_create(name => $name,
            source_rg => $args{$p->{src}}, source_vnet => $vnet_names{$p->{src}},
            target_rg => $args{$p->{dst}}, target_vnet => $vnet_names{$p->{dst}});
        record_info('PEERING SUCCESS ' . $name,
            "Peering from $args{$p->{src}}.$vnet_names{$p->{src}} to $args{$p->{dst}}.$vnet_names{$p->{dst}} was successful");
    }
}

=head3 ibsm_network_peering_azure_delete

    ibsm_network_peering_azure_delete(
        ibsm_rg => 'IBSmRg',
        sut_rg => 'SUTRg',
        name_prefix => 'something');

Delete the two network peerings between the two provided deployments.
This function is symmetrical to ibsm_network_peering_azure_create.

=over

=item B<ibsm_rg> - Azure resource group of the IBSm

=item B<sut_rg> - Azure resource group of the SUT

=item B<sut_vnet> - substring in the SUT vnet. Optional and only needed if only one specific VNET has to be considered. Most of the time it is get_current_job_id()

=item B<timeout> - default is 5 mins

=item B<name_prefix> - allow the user to prepend name prefix to the peering name to be deleted

=back
=cut

sub ibsm_network_peering_azure_delete {
    my (%args) = @_;
    foreach (qw(sut_rg ibsm_rg)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{timeout} //= bmwqemu::scale_timeout(300);

    my %vnet_names;
    my @peerings = (
        {src => 'sut_rg', dst => 'ibsm_rg'},
        {src => 'ibsm_rg', dst => 'sut_rg'}
    );

    my %rets = (sut_rg => 0, ibsm_rg => 0);
    foreach my $p (@peerings) {
        # Retrieve both src and dst VNET names from Azure.
        # The SUT VNET might require specific filtering based on 'sut_vnet'.
        # We use the argument name ('sut_rg', 'ibsm_rg') as key to save them.
        foreach my $rg_arg (values %$p) {
            if (!$vnet_names{$rg_arg}) {
                # Determine the appropriate JMESPath query for fetching the VNET name.
                my $query = ($rg_arg eq 'sut_rg' && $args{sut_vnet}) ? "[?contains(name,'" . $args{sut_vnet} . "')].name" : '[].name';
                $vnet_names{$rg_arg} = _get_vnet_name(resource_group => $args{$rg_arg}, query => $query);
            }
            else {
                record_info("VNET:$vnet_names{$rg_arg}");
            }
        }

        # Reconstruct the expected peering name to ensure we precisely identify the correct resource.
        my $expected_name = _get_peering_name($args{name_prefix}, $vnet_names{$p->{src}}, $vnet_names{$p->{dst}});

        # List peerings matching the expected name to verify existence and uniqueness.
        my $res = az_network_peering_list(
            resource_group => $args{$p->{src}},
            vnet => $vnet_names{$p->{src}},
            query => "[?contains(name, '$expected_name')].name");
        if (!@$res) {
            # Missing peerings on the IBSm side are logged but skipped to allow cleanup to proceed.
            record_info('NO PEERING', "No peering from $args{$p->{src}} to $args{$p->{dst}} found - skipping deletion.");
            next;
        }

        # Safety check: die if more than one matching peering is found to prevent accidental deletion of unrelated resources.
        die "Expected exactly one peering named '$expected_name' but found " . scalar(@$res) if scalar(@$res) != 1;
        my $peering_name = $res->[0];

        record_info("Destroying peering '$peering_name' from $args{$p->{src}} to $args{$p->{dst}}");
        # Perform the actual deletion of the identified peering resource in Azure.
        $rets{$p->{src}} = az_network_peering_delete(
            name => $peering_name,
            resource_group => $args{$p->{src}},
            vnet => $vnet_names{$p->{src}},
            timeout => $args{timeout});
    }

    record_info("source_ret:'$rets{sut_rg}' target_ret:'$rets{ibsm_rg}'");
    if ($rets{sut_rg} == 0 && $rets{ibsm_rg} == 0) {
        record_info('Peering deletion SUCCESS', 'The peering was successfully destroyed');
        return;
    }
    record_info('Peering destruction FAIL: There may be leftover peering connections, please check - jsc#7487', result => 'fail');
}

1;
