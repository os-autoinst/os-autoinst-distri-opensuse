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

our @EXPORT = qw(
  ibsm_calculate_address_range
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

=item B<SLOT> - integer to be used as seed in calculating addresses

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

1;
