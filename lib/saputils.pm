# SUSE's openQA tests
#
# Copyright 2017-2025 SUSE LLC
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
use Mojo::JSON qw(encode_json decode_json);
use Carp qw(croak);

our @EXPORT = qw(
  calculate_hana_topology
  check_hana_topology
  check_crm_output
  get_primary_node
  get_failover_node
);

=head1 SYNOPSIS

Package with utility functionality for tests on SLES for
SAP Applications.

This package is a stateless library.
To keep this library as generic as possible avoid as much as possible any other dependency usage,
like other base class or test API. Avoid using get_var/set_var at this level.

=cut


=head2 calculate_hana_topology
    calculate_hana_topology(input_format=>[script|json], input => $saphanasr_showAttr_format_input_format_output);

    Expect `SAPHanaSR-showAttr --format=$input_format` as input.
    Returns parsed perl value decoded from json remap output from like :
            Hosts/vmhana01/remoteHost="vmhana02"
            Hosts/vmhana01/sync_state="PRIM"
            Hosts/vmhana01/vhost="vmhana01"
            Hosts/vmhana02/remoteHost="vmhana01"
            Hosts/vmhana02/sync_state="SOK"
            Hosts/vmhana02/vhost="vmhana02"

    output look a like:
    {
          'Host' => {
                      'vmhana01' => {
                                           'clone_state' => 'DEMOTED',
                                           'score' => '100',
                                           'srah' => '-',
                                           'version' => '2.00.077.00.1710325774',
                                           'vhost' => 'vmhana01',
                                           'site' => 'site_a'
                                         },
                      'vmhana02' => {
                                           'clone_state' => 'PROMOTED',
                                           'score' => '150',
                                           'vhost' => 'vmhana02',
                                           'srah' => '-',
                                           'version' => '2.00.077.00.1710325774',
                                           'site' => 'site_b'
                                         }
                    },
          'Site' => {
                      'site_a' => {
                                     'srMode' => 'sync',
                                     'srPoll' => 'SOK',
                                     'mns' => 'vmhana01'
                                   },
                      'site_b' => {
                                     'srPoll' => 'PRIM',
                                     'mns' => 'vmhana02',
                                     'srMode' => 'sync'
                                   }
                    }
        };



=over 1

=item B<input_format> - format of the 'SAPHanaSR-showAttr --format='

=item B<input> - stdout of 'SAPHanaSR-showAttr --format=<input_format>'

=back
=cut


sub calculate_hana_topology {
    my (%args) = @_;
    croak('calculate_hana_topology [ERROR] Argument <input> missing') unless $args{input};
    my $input_format = $args{input_format} || 'script';
    croak("calculate_hana_topology [ERROR] Argument <input_format: $input_format > is not known") unless ($input_format eq 'script' or $input_format eq 'json');

    my %topology;
    my $topology_json;
    my %script_topology;

    if ($input_format eq 'json') {
        $topology_json = $args{input};
    } else {
        my @all_lines = split("\n", $args{input});
        my @hosts_parameters = map { if (/^Hosts/) { s,Hosts/,,; s,",,g; $_ } else { () } } @all_lines;
        my @globals_parameters = map { if (/^Global/) { s,Global/,,; s,",,g; $_ } else { () } } @all_lines;
        my @resources_parameters = map { if (/^Resource/) { s,Resource/,,; s,",,g; $_ } else { () } } @all_lines;

        my @all_hosts = uniq map { (split("/", $_))[0] } @hosts_parameters;
        my @all_globals = uniq map { (split("/", $_))[0] } @globals_parameters;
        my @all_resources = uniq map { (split("/", $_))[0] } @resources_parameters;

        for my $host (@all_hosts) {
            # Only takes parameter and value for lines about one specific host at time
            my %host_parameter = map {
                my ($node, $parameter, $value) = split(/[\/=]/, $_);
                if ($host eq $node) { ($parameter, $value) } else { () }
            } @hosts_parameters;
            $script_topology{$host} = \%host_parameter;
        }


        for my $global (@all_globals) {
            # Takes parameter and value per line in Global
            my %global_parameter = map {
                my ($node, $parameter, $value) = split(/[\/=]/, $_);
                ($parameter, $value);
            } @globals_parameters;
            $script_topology{$global} = \%global_parameter;
        }

        # Remapping from old structure of the 'SAPHana-showAttr --format=script', which is
        # filled to the `$script_topology` from which it's mapped to the new decode_json() like
        # structure to the `$topology`

        # Key `Resource` is dynamic and could be mapped directly
        for my $resource (@all_resources) {
            # Takes parameter and value per line in resource
            my %resource_parameter = map {
                my ($node, $parameter, $value) = split(/[\/=]/, $_);
                ($parameter, $value);
            } @resources_parameters;
            $topology{'Resource'}{$resource} = \%resource_parameter;
        }

        for my $host (@all_hosts) {

            # New structure introduces key 'Site' to which some values are moved and have keys renamed
            # or left defined but empty if it's not defined originally
            $topology{'Site'}{$script_topology{$host}->{'site'}}{'mns'} = defined $host ? $host : '';
            $topology{'Site'}{$script_topology{$host}->{'site'}}{'opMode'} = defined $script_topology{$host}->{'op_mode'} ? $script_topology{$host}->{'op_mode'} : '';
            $topology{'Site'}{$script_topology{$host}->{'site'}}{'srMode'} = defined $script_topology{$host}->{'srmode'} ? $script_topology{$host}->{'srmode'} : '';
            $topology{'Site'}{$script_topology{$host}->{'site'}}{'srPoll'} = defined $script_topology{$host}->{'sync_state'} ? $script_topology{$host}->{'sync_state'} : '';

            # Unfortunately, the new structure lack the key 'node_state' completely, so we need use the
            # new key 'lss' which represents the state of the cluster '4' mean OK '1' means FAILED
            $topology{'Site'}{$script_topology{$host}->{'site'}}{'lss'} = ($script_topology{$host}->{'node_state'} eq 'online' or $script_topology{$host}->{'node_state'} =~ /[1-9]+/) ? '4' : '1';

            # New structure rename key 'Hosts' to the 'Host' and also get keys renamed
            # or left defined but empty if it's not defined originally
            $topology{'Host'}{$host}{'vhost'} = defined $script_topology{$host}->{'vhost'} ? $script_topology{$host}->{'vhost'} : '';
            $topology{'Host'}{$host}{'site'} = defined $script_topology{$host}->{'site'} ? $script_topology{$host}->{'site'} : '';
            $topology{'Host'}{$host}{'srah'} = defined $script_topology{$host}->{'srah'} ? $script_topology{$host}->{'srah'} : '';
            $topology{'Host'}{$host}{'clone_state'} = defined $script_topology{$host}->{'clone_state'} ? $script_topology{$host}->{'clone_state'} : '';
            $topology{'Host'}{$host}{'score'} = defined $script_topology{$host}->{'score'} ? $script_topology{$host}->{'score'} : '';
            $topology{'Host'}{$host}{'version'} = defined $script_topology{$host}->{'version'} ? $script_topology{$host}->{'version'} : '';
        }

        # New structure of key 'Global' with renamed keys
        $topology{'Global'}{'global'}{'cib-last-written'} = defined $script_topology{'global'}->{'cib-time'} ? $script_topology{'global'}->{'cib-time'} : '';
        $topology{'Global'}{'global'}{'maintenance-mode'} = defined $script_topology{'global'}->{'maintenance'} ? $script_topology{'global'}->{'maintenance'} : '';

        # We encode to the JSON to be sure that output is always same
        $topology_json = encode_json(\%topology);
    }
    my $hana_topology = decode_json($topology_json);
    return $hana_topology;
}

=head2 check_hana_topology
    check_hana_topology(input => calculate_hana_topology($saphanasr_showAttr_format_script_output) [, online_str => '12345678']]);

    Expect the output of saputils::calculate_hana_topology as input.
    Uses calculate_hana_topology to get a hash of hashes, and then
    checks the output to make sure that the cluster is working and ready.

    The checks performed are:
    - All node_states are online
    - All sync_states are either SOK or PRIM

=over 2

=item B<input> - return value of calculate_hana_topology

=item B<node_state_match> - string used to match the online state in field node_state.

=back
=cut


sub check_hana_topology {
    my (%args) = @_;
    croak('check_hana_topology [ERROR] Argument <input> missing') unless $args{input};
    my $topology = $args{input};
    my $node_state_match = ($args{node_state_match} eq 'online' or $args{node_state_match} =~ /[1-9]+/) ? '4' : '1';

    my $all_online = 1;
    my $prim_count = 0;
    my $sok_count = 0;
    foreach my $site (keys %{$topology->{Site}}) {
        # first check presence of all fields needed in further tests.
        # If something is missing the topology is considered invalid.
        foreach (qw(lss srPoll)) {
            unless (defined($topology->{Site}->{$site}->{$_})) {
                record_info('check_hana_topology', ' [ERROR] ', "Missing '$_' field in topology output for site $site");
                return 0;
            }
        }

        # Check node_state
        if ($topology->{'Site'}->{$site}->{'lss'} ne $node_state_match) {
            record_info('check_hana_topology', ' [ERROR] ', "node_state: $topology->{'Site'}->{$site}->{'lss'} is not $node_state_match for host $topology->{'Site'}->{$site}->{'mns'} \n");
            $all_online = 0;
            last;
        }

        # Check sync_state
        if ($topology->{'Site'}->{$site}->{'srPoll'} eq 'PRIM') {
            $prim_count++;
        } elsif ($topology->{'Site'}->{$site}->{'srPoll'} eq 'SOK') {
            $sok_count++;
        }
    }

    # Final check for conditions
    record_info('check_hana_topology', "all_online: $all_online prim_count: $prim_count sok_count: $sok_count");
    return ($all_online && $prim_count == 1 && $sok_count == (keys %{$topology->{'Site'}}) - 1);
}

=head2 check_crm_output
    check_crm_output(input => $crm_mon_output);

    input: the output of the command 'crm_mon -r -R -n -N -1'
    output: whether the conditions are met (return 1) or not (return 0)

    Conditions:
    - No resources are in 'Starting' state
    - No 'Failed Resource Actions' present

=over 1

=item B<input> - stdout of 'crm_mon -R -r -n -N -1'

=back
=cut

sub check_crm_output {
    my (%args) = @_;
    croak('check_crm_output [ERROR] Argument <input> missing') unless $args{input};
    my $resource_starting = ($args{input} =~ /:\s*Starting/) ? 1 : 0;
    my $failed_actions = ($args{input} =~ /Failed Resource Actions:/) ? 1 : 0;

    record_info('check_crm_output', "resource_starting:$resource_starting failed_actions:$failed_actions");
    return (($resource_starting != 1) && ($failed_actions != 1) ? 1 : 0);
}

=head2 get_primary_node
    get_primary_node(topology_data=>$topology_data);

    Returns hostname of current primary node obtained from B<calculate_hana_topology()> output.

=over

=item B<topology_data> - Output from `calculate_hana_topology()` function

=back
=cut

sub get_primary_node {
    my (%args) = @_;
    croak('get_primary_node [ERROR] Argument <topology_data> missing') unless $args{topology_data};
    my $topology = $args{topology_data};
    for my $site (keys %{$topology->{Site}}) {
        for my $host (keys %{$topology->{Host}}) {
            return $topology->{'Host'}->{$host}->{'vhost'} if ($topology->{'Host'}->{$host}->{'site'} eq $site && $topology->{'Site'}->{$site}->{'srPoll'} eq 'PRIM');
        }
    }
}

=head2 get_failover_node
    get_failover_node(topology_data=>$topology_data);

    Returns hostname of current failover (replica) node obtained from B<calculate_hana_topology()> output.
    Returns node hostname even if it's in 'SFAIL' state.

=over

=item B<topology_data> - Output from `calculate_hana_topology()` function

=back
=cut

sub get_failover_node {
    my (%args) = @_;
    croak('get_failover_node [ERROR] Argument <topology_data> missing') unless $args{topology_data};
    my $topology = $args{topology_data};
    for my $site (keys %{$topology->{'Site'}}) {
        for my $host (keys %{$topology->{'Host'}}) {
            return $topology->{'Host'}->{$host}->{'vhost'} if ($topology->{'Host'}->{$host}->{'site'} eq $site && grep /$topology->{'Site'}->{$site}->{'srPoll'}/, ('SOK', 'SFAIL'));
        }
    }
}

1;
