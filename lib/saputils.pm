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
  check_hana_topology
  check_crm_output
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

=head2 check_hana_topology
    check_hana_topology([input => $saphanasr_showAttr_format_script_output]);

    Expect the output of saputils::calculate_hana_topology as input.
    Uses calculate_hana_topology to get a hash of hashes, and then
    checks the output to make sure that the cluster is working and ready.

    The checks performed are:
    - All node_states are online
    - All sync_states are either SOK or PRIM

=cut


sub check_hana_topology {
    my (%args) = @_;
    croak "Missing mandatory 'input' argument" unless $args{input};
    my $topology = $args{input};

    my $all_online = 1;
    my $prim_count = 0;
    my $sok_count = 0;

    foreach my $host (keys %$topology) {
        # Check node_state
        if ($topology->{$host}->{node_state} ne 'online') {
            $all_online = 0;
            last;
        }

        # Check sync_state
        if ($topology->{$host}->{sync_state} eq 'PRIM') {
            $prim_count++;
        } elsif ($topology->{$host}->{sync_state} eq 'SOK') {
            $sok_count++;
        }
    }

    # Final check for conditions
    return ($all_online && $prim_count == 1 && $sok_count == (keys %$topology) - 1);
}

=head2 check_crm_output
    check_crm_output([input => $crm_mon_output]);

    input: the output of the command 'crm_mon -r -R -n -N -1'
    output: whether the conditions are met (return 1) or not (return 0)

    Conditions:
    - No resources are in 'Starting' state
    - No 'Failed Resource Actions' present   

=cut

sub check_crm_output {
    my (%args) = @_;
    croak "Missing mandatory 'input' argument" unless $args{input};
    record_info("cmd_out", $args{input});
    my $resource_started = 1;
    my $failed_actions = 0;

    $resource_started = !($args{input} =~ /:\s*Starting/);
    $failed_actions = ($args{input} =~ /Failed Resource Actions:/);

    return ($resource_started && !$failed_actions);
}

1;
