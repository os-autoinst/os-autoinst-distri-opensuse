# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module performs variants of HANA secondary site takeover scenario

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use warnings;
use strict;
use testapi;
use serial_terminal qw(select_serial_terminal);
use sles4sap::console_redirection;
use sles4sap::database_hana;
use sles4sap::sap_host_agent qw(saphostctrl_list_instances);
use sles4sap::sapcontrol qw(sapcontrol_process_check sap_show_status_info);
use hacluster qw(wait_for_idle_cluster wait_until_resources_started);
use Data::Dumper;
use Carp qw(croak);

=head1 SYNOPSIS

Module executes variants of 'SAP HANA Secondary site takeover' scenario on Performance-optimized setup.
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
    record_info('Test INFO', "Performing replica DB failover scenario: $failover_method\n
    Failover database '$expected_failover_db' will be disrupted\n
    Primary database '$expected_primary_db' will stay intact. No failover is expected.");

    my %databases = %{$run_args->{redirection_data}{db_hana}};
    my %target_node_data = %{$databases{$expected_failover_db}};

    connect_target_to_serial(
        destination_ip => $target_node_data{ip_address}, ssh_user => $target_node_data{ssh_user}, switch_root => 1);

    check_node_roles(expected_primary => $expected_primary_db, expected_failover => $expected_failover_db);

    # Perform failover on primary
    my $node_roles = get_node_roles();

    # Retrieve database information: DB SID and instance ID
    my @db_data = @{saphostctrl_list_instances(running => 'yes')};
    record_info('DB data', Dumper(@db_data));
    die('Multiple databases on one host not supported') if @db_data > 1;
    my $db_sid = $db_data[0]->{sap_sid};
    my $db_id = $db_data[0]->{instance_id};

    # Perform failover on replica
    record_info('Failover', "Performing failover method '$failover_method' on database '$expected_failover_db'");
    sap_show_status_info(cluster => 1, netweaver => 1, instance_id => $db_id);
    wait_until_resources_started();
    wait_for_idle_cluster();
    hdb_stop(instance_id => $db_id, switch_user => lc($db_sid) . 'adm', command => $failover_method);

    # Wait for replica to get back up again.
    wait_for_failed_resources();
    record_info('DB wait', "Waiting for database node '$node_roles->{failover_node}' to start");
    sapcontrol_process_check(
        instance_id => $db_id, expected_state => 'started', wait_for_state => 'yes', timeout => 600, loop_sleep => 30);
    record_info('DB started', "All database node '$node_roles->{failover_node}' processes are 'GREEN'");
    assert_script_run('crm resource cleanup');

    # Wait for cluster to become ready
    record_info('Cluster wait', 'Waiting for idle cluster');
    wait_until_resources_started();
    wait_for_idle_cluster();
    # check node roles again - They must be same as at the beginning of the test
    check_node_roles(expected_primary => $expected_primary_db, expected_failover => $expected_failover_db);
    record_info('Cluster OK', 'Cluster resources up and running');
    sap_show_status_info(cluster => 1, netweaver => 1, instance_id => $db_id);
    record_info('TEST END', 'Test module finished successfully.');
    disconnect_target_from_serial();
}

1;
