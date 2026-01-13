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

=head2 ibsm_network_peering_azure_create

    ibsm_network_peering_azure_create(ibsm_rg => 'IBSmMyRg');

Create bidirectional network peering in Azure

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
    foreach ('ibsm', 'sut') {
        my $res = az_network_vnet_get(resource_group => $args{$_ . '_rg'}, query => '[].name');
        $vnet_names{$_} = $res->[0];
    }

    my @peering_name;
    push @peering_name, $args{name_prefix} if ($args{name_prefix});
    push @peering_name, $vnet_names{sut};
    push @peering_name, $vnet_names{ibsm};
    az_network_peering_create(name => join('-', @peering_name),
        source_rg => $args{sut_rg}, source_vnet => $vnet_names{sut},
        target_rg => $args{ibsm_rg}, target_vnet => $vnet_names{ibsm});
    record_info('PEERING SUCCESS ' . join('-', @peering_name),
        "Peering from $args{sut_rg}.$vnet_names{sut} SUT was successful");

    @peering_name = ();
    push @peering_name, $args{name_prefix} if ($args{name_prefix});
    push @peering_name, $vnet_names{ibsm};
    push @peering_name, $vnet_names{sut};
    az_network_peering_create(name => join('-', @peering_name),
        source_rg => $args{ibsm_rg}, source_vnet => $vnet_names{ibsm},
        target_rg => $args{sut_rg}, target_vnet => $vnet_names{sut});
    record_info('PEERING SUCCESS ' . join('-', @peering_name),
        "Peering from $args{ibsm_rg}.$vnet_names{ibsm} server was successful");
}

=head3 ibsm_network_peering_azure_delete

    Delete all the network peering between the two provided deployments.

=over

=item B<ibsm_rg> - Azure resource group of the IBSm

=item B<sut_rg> - Azure resource group of the SUT

=item B<sut_vnet> - substring in the SUT vnet. Optional and only needed if only one specific VNET has to be considered. Most of the time it is get_current_job_id()

=item B<query> - valid jmespath https://jmespath.org/ (default: '[].name'), optional

=item B<timeout> - default is 5 mins

=back
=cut

sub ibsm_network_peering_azure_delete {
    my (%args) = @_;
    foreach (qw(sut_rg ibsm_rg)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{timeout} //= bmwqemu::scale_timeout(300);
    $args{query} //= '[].name';

    # Take care to keep all the query to always return a json list, even if of a sigle element,
    # and not a string.
    my $vnet_get_query = '[].name';
    my $res = az_network_vnet_get(resource_group => $args{sut_rg},
        query => $args{sut_vnet} ? "[?contains(name,'" . $args{sut_vnet} . "')].name" : $vnet_get_query);
    my $sut_vnet = $res->[0];

    $res = az_network_vnet_get(resource_group => $args{ibsm_rg},
        query => $vnet_get_query);
    my $ibsm_vnet = $res->[0];

    $res = az_network_peering_list(resource_group => $args{sut_rg}, vnet => $sut_vnet, query => $args{query});
    my $peering_name = $res->[0];
    if (!$peering_name) {
        record_info('NO PEERING',
            "No peering between $args{sut_rg} and resources belonging to the current job to be destroyed!");
        return;
    }

    my $source_ret = 0;
    record_info("Destroying SUT->IBSM peering '$peering_name'");
    if ($args{sut_rg}) {
        $source_ret = az_network_peering_delete(
            name => $peering_name,
            resource_group => $args{sut_rg},
            vnet => $sut_vnet,
            timeout => $args{timeout});
    }
    else {
        record_info('NO PEERING',
            "No peering between SUT and IBSM - maybe it wasn't created, or the resources have been destroyed.");
    }
    $res = az_network_peering_list(resource_group => $args{ibsm_rg}, vnet => $ibsm_vnet, query => $args{query});

    $peering_name = $res->[0];
    record_info("Destroying IBSM->SUT peering '$peering_name'");
    my $target_ret = az_network_peering_delete(
        name => $peering_name,
        resource_group => $args{ibsm_rg},
        vnet => $ibsm_vnet,
        timeout => $args{timeout});

    record_info("source_ret:'$source_ret' target_ret:'$target_ret'");
    if ($source_ret == 0 && $target_ret == 0) {
        record_info('Peering deletion SUCCESS', 'The peering was successfully destroyed');
        return;
    }
    record_info('Peering destruction FAIL: There may be leftover peering connections, please check - jsc#7487', result => 'fail');
}

1;
