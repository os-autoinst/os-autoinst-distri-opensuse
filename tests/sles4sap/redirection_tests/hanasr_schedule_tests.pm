# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module is used for scheduling multiple variants of HanaSR failover scenario on primary database.

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use strict;
use warnings FATAL => 'all';
use testapi;
use main_common 'loadtest';
use sles4sap::console_redirection;
use sles4sap::database_hana qw(find_hana_resource_name);
use saputils qw(calculate_hana_topology get_primary_node get_failover_node);
use hacluster qw(set_cluster_parameter);
use Data::Dumper;

=head1 SYNOPSIS

Test module is used for scheduling multiple variants of HanaSR failover scenario on primary database.
At the moment, the code supports only SDAF based deployment, but the dependencies can be removed completely in the future.

B<OpenQA parameters:>

=over

=item B<HANA_AUTOMATED_REGISTER> : Switch Cluster parameter 'AUTOMATED_REGISTER' value. Default: false



=back

=cut

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    my %databases = %{$run_args->{redirection_data}{db_hana}};
    # Connect to any database cluster node to get topology data
    my $target_node = (keys %databases)[0];
    my %target_node_data = %{$databases{$target_node}};
    connect_target_to_serial(
        destination_ip => $target_node_data{ip_address}, ssh_user => $target_node_data{ssh_user}, switch_root => '1');

    my $topology = calculate_hana_topology(input => script_output('SAPHanaSR-showAttr --format=script'));

    # Set AUTOMATED_REGISTER value according to parameter HANA_AUTOMATED_REGISTER with 'false' being the default value
    my $automated_register = get_var('HANA_AUTOMATED_REGISTER') ? 'true' : 'false';
    record_info('AUTOMATED_REGISTER', "Cluster parameter 'AUTOMATED_REGISTER' set to $automated_register");
    set_cluster_parameter(
        resource => find_hana_resource_name(), parameter => 'AUTOMATED_REGISTER', value => $automated_register);

    # No need for open SSH session anymore
    disconnect_target_from_serial();

    my $primary_db = get_primary_node(topology_data => $topology);
    my $primary_site = $topology->{Host}{$primary_db}{site};
    my $failover_db = get_failover_node(topology_data => $topology);
    my $failover_site = $topology->{Host}{$failover_db}{site};
    my %scenarios;
    my @failover_actions = split(",", get_var("HANASR_FAILOVER_SCENARIOS", 'stop,kill'));
    for my $method (@failover_actions) {
        my $test_name = ucfirst($method) . "_primary_DB-$primary_site";
        $scenarios{$test_name} = {
            primary_db => $primary_db,
            failover_db => $failover_db,
            failover_method => $method
        };
        loadtest('sles4sap/redirection_tests/hana_sr_primary_failover', name => $test_name, run_args => $run_args, @_);
        record_info('Load test', "Scheduling Primary DB failover using '$method' method.\n
        Test name: $test_name\n
        Primary site $primary_db will be stopped.\n
        Failover site $failover_db will take over.");

        # Reverse roles and put cluster into original state using same failover method
        $test_name = ucfirst($method) . "_primary_DB-$failover_site";
        $scenarios{$test_name} = {
            primary_db => $failover_db,
            failover_db => $primary_db,
            failover_method => $method
        };
        loadtest('sles4sap/redirection_tests/hana_sr_primary_failover', name => $test_name, run_args => $run_args, @_);
        record_info('Load test', "Scheduling Primary DB failover using '$method' method.\n
        Test name: $test_name\n
        Primary site $failover_db will be stopped.\n
        Failover site $primary_db will take over.");

        # Failover test for replica database
        $test_name = ucfirst($method) . "_failover_DB-$failover_site";
        $scenarios{$test_name} = {
            primary_db => $primary_db,
            failover_db => $failover_db,
            failover_method => $method
        };
        loadtest('sles4sap/redirection_tests/hana_sr_replica_failover', name => $test_name, run_args => $run_args, @_);
        record_info('Load test', "Scheduling failover DB failover using '$method' method.\n
        Test name: $test_name\n
        Failover site $primary_db will be restarted.\n
        Primary site $failover_db will stay intact.");
    }

    $run_args->{scenarios} = \%scenarios;
}

1;
