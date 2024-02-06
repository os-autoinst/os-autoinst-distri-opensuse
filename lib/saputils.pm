# SUSE's openQA tests
#
# Copyright 2017-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Functions for SAP tests
# Maintainer: QE-SAP <qe-sap@suse.de>

## no critic (RequireFilenameMatchesPackage);
package saputils;

use strict;
use warnings;
use Exporter 'import';
use testapi;
use List::MoreUtils qw(uniq);
use Carp qw(croak);

our @EXPORT = qw(
  calculate_hana_topology
);

=head1 SYNOPSIS

Package with utility functionality for tests on SLES for
SAP Applications.

This package is a stateless library.
To keep this library as generic as possible avoid as much as possible any other dependency usage,
like other baseclass or testapi. Avoid using get_var/set_var at this level.

=cut


=head2 calculate_hana_topology
    calculate_hana_topology([input => $saphanasr_showAttr_format_script_output]);

    Expect `SAPHanaSR-showAttr --format=script` as input.
    Parses this input, returns a hash of hashes containing values for each host.

    Output like:
            Hosts/vmhana01/remoteHost="vmhana02"
            Hosts/vmhana01/sync_state="PRIM"
            Hosts/vmhana01/vhost="vmhana01"
            Hosts/vmhana02/remoteHost="vmhana01"
            Hosts/vmhana02/sync_state="SOK"
            Hosts/vmhana02/vhost="vmhana02"
    result in
    {
        vmhana01 => {
            remoteHost => 'vmhana02',
            sync_state => 'PRIM',
            vhost => 'vmhana01',
        },
        vmhana02 => {
            remoteHost => 'vmhana01',
            sync_state => 'SOK',
            vhost => 'vmhana02',
        },
    }
=cut


sub calculate_hana_topology {
    my (%args) = @_;
    croak "Missing mandatory 'input' argument" unless $args{input};
    record_info("cmd_out", $args{input});
    my %topology;
    my @all_parameters = map { if (/^Hosts/) { s,Hosts/,,; s,",,g; $_ } else { () } } split("\n", $args{input});
    my @all_hosts = uniq map { (split("/", $_))[0] } @all_parameters;

    for my $host (@all_hosts) {
        # Only takes parameter and value for lines about one specific host at time
        my %host_parameters = map {
            my ($node, $parameter, $value) = split(/[\/=]/, $_);
            if ($host eq $node) { ($parameter, $value) } else { () }
        } @all_parameters;
        $topology{$host} = \%host_parameters;
    }

    return \%topology;
}

1;
