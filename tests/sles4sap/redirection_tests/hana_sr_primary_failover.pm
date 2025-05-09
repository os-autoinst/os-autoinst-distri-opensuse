# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module performs variants of HANA primary site takeover scenario

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use warnings;
use strict;
use testapi;
use serial_terminal qw(select_serial_terminal);
use sles4sap::console_redirection;
use hacluster qw(wait_for_idle_cluster wait_until_resources_started show_cluster_parameter);
use sles4sap::sap_host_agent qw(saphostctrl_list_instances );
use sles4sap::database_hana;
use sles4sap::sapcontrol qw(sapcontrol_process_check sap_show_status_info);
use Carp qw(croak);
use Data::Dumper;

=head1 SYNOPSIS

Module executes variants of 'SAP HANA Primary site takeover' scenario on Performance-optimized setup.
Variants of the tests are described here: https://documentation.suse.com/sbp/sap-15/html/SLES4SAP-hana-sr-guide-PerfOpt-15/index.html#cha.s4s.test-cluster
Currently supported variants include Stopping database using 'HDB stop' command and killing DB processes with 'HDB kill -x'.
It is not possible to use this module as standalone but rather scheduling it via 'loadtest' API

=cut

sub run {
    my ($self, $run_args) = @_;
    my @supported_scenarios = ('stop', 'kill');
    my %scenario = %{$run_args->{scenarios}{$self->{name}}};
    my $expected_primary_db = $scenario{primary_db};
    my $expected_failover_db = $scenario{failover_db};
    my $failover_method = $scenario{failover_method};

    croak "Failover type $failover_method not supported" unless grep /$failover_method/, @supported_scenarios;
    record_info('Test INFO', "Performing primary DB failover scenario: $failover_method\n
    Primary database '$expected_failover_db' will be disrupted\n
    Failover database '$expected_primary_db' will take over as a primary.\n ");

    # Connect to one of the DB nodes and collect topology data
    my %databases = %{$run_args->{redirection_data}{db_hana}};
    for ($expected_primary_db, $expected_failover_db) {
        croak("Console redirection: Missing SSH connection data for database $_\nGot:\n" . Dumper(\%databases))
          unless $databases{$_};
    }

    my %target_node_data = %{$databases{$expected_primary_db}};
    connect_target_to_serial(
        destination_ip => $target_node_data{ip_address}, ssh_user => $target_node_data{ssh_user}, switch_root => 1);
    check_node_roles(expected_primary => $expected_primary_db, expected_failover => $expected_failover_db);

    # Retrieve database information: DB SID and instance ID
    my @db_data = @{saphostctrl_list_instances(running => 'yes')};
    record_info('DB data', Dumper(@db_data));
    die('Multiple databases on one host not supported') if @db_data > 1;
    my $db_sid = $db_data[0]->{sap_sid};
    my $db_id = $db_data[0]->{instance_id};

    # Perform failover on primary
    record_info('Failover', "Performing failover method '$failover_method' on database '$expected_primary_db'");
    my $node_roles = get_node_roles();
    sap_show_status_info(cluster => 1, netweaver => 1, instance_id => $db_id);
    wait_until_resources_started();
    wait_for_idle_cluster();
    hdb_stop(instance_id => $db_id, switch_user => lc($db_sid) . 'adm', command => $failover_method);

    # Wait for takeover
    record_info('Takeover', "Waiting for node '$node_roles->{failover_node}' to become primary");
    wait_for_failed_resources();
    wait_for_takeover(target_node => $node_roles->{failover_node});

    # Register and start replication
    my $automatic_register = show_cluster_parameter(resource => find_hana_resource_name(), parameter => 'AUTOMATED_REGISTER');
    if ($automatic_register eq 'true') {
        record_info('REG: Auto', "Parameter: AUTOMATED_REGISTER=true\nNo action to be done");
    }
    else {
        record_info('REG: Manual', "Parameter: AUTOMATED_REGISTER=false\nRegistration will be done manually");
        # Failed Primary node will be registered for replication after takeover
        register_replica(target_hostname => $node_roles->{primary_node}, instance_id => $db_id, switch_user => lc($db_sid) . 'adm');
    }

    # cleanup resources
    assert_script_run('crm resource cleanup');

    # Wait for database processes to start
    record_info('DB wait', "Waiting for database node '$node_roles->{primary_node}' to start");
    sapcontrol_process_check(
        instance_id => $db_id, expected_state => 'started', wait_for_state => 'yes', timeout => 600, loop_sleep => 60);
    record_info('DB started', "All database node '$node_roles->{primary_node}' processes are 'GREEN'");

    # Wait for cluster co come up
    record_info('Cluster wait', 'Waiting for cluster to come up');
    wait_until_resources_started();
    wait_for_idle_cluster();
    record_info('Cluster OK', 'Cluster resources up and running');
    sap_show_status_info(cluster => 1, netweaver => 1, instance_id => $db_id);

    disconnect_target_from_serial();
}

1;
