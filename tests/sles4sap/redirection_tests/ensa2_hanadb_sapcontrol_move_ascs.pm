# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module tests ENSA2 Central Services with HANA DB - Use sapcontrol to move ASCS.
#   It runs sapcontrol related commands on remote host using console redirection.
#   For more information read 'README.md'

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use warnings;
use strict;
use testapi;
use serial_terminal qw(select_serial_terminal);
use sles4sap::console_redirection;
use hacluster qw(check_cluster_state wait_until_resources_started wait_for_idle_cluster crm_check_resource_location);
use sles4sap::sap_deployment_automation_framework::deployment qw(load_os_env_variables get_sdaf_instance_id);
use saputils;

sub run {
    my ($self, $run_args) = @_;
    my %redirection_data = %{$run_args->{redirection_data}};

    # Connect to deployer VM (by default) to load env variables and get get instance IDs
    connect_target_to_serial();
    load_os_env_variables();
    my $instance_id_scs = get_sdaf_instance_id(pattern => 'SCS');
    my $instance_id_ers = get_sdaf_instance_id(pattern => 'ERS');
    # Disonnect from deployer VM
    disconnect_target_from_serial();

    # Get scs instance data
    my %instance_data_scs = %{$run_args->{redirection_data}{nw_ascs}};
    my $instance_hostname_scs = (keys(%instance_data_scs))[0];
    my $ip_scs = $instance_data_scs{$instance_hostname_scs}{ip_address};
    my $user_scs = $instance_data_scs{$instance_hostname_scs}{ssh_user};
    # Get ers instance data
    my %instance_data_ers = %{$run_args->{redirection_data}{nw_ers}};
    my $instance_hostname_ers = (keys(%instance_data_ers))[0];
    my $ip_ers = $instance_data_ers{$instance_hostname_ers}{ip_address};
    my $user_ers = $instance_data_ers{$instance_hostname_ers}{ssh_user};

    # Connect to scs VM
    connect_target_to_serial(destination_ip => $ip_scs, ssh_user => $user_scs, switch_root => 1);
    # Check for idle cluster and no failed resources
    record_info('Cluster wait', 'Waiting for resources to start');
    wait_until_resources_started();
    wait_for_idle_cluster();
    record_info('Cluster check', 'Checking state of cluster resources');
    check_cluster_state();

    # Execute ASCS failover from ASCS to ERS
    record_info('Failover', "Executing 'HAFailoverToNode'. Failover from $instance_hostname_scs to $instance_hostname_ers");
    execute_failover(instance_id => $instance_id_scs, instance_user => $user_scs, instance_type => 'ASCS', wait_for_target => $instance_hostname_ers);
    # Disonnect from scs VM
    disconnect_target_from_serial();

    # Execute ASCS failover: repeat whole failover and return ASCS to original node
    # Connect to ers VM
    connect_target_to_serial(destination_ip => $ip_ers, ssh_user => $user_ers, switch_root => 1);
    record_info('Failover', "Executing 'HAFailoverToNode'. Failover from $instance_hostname_ers to $instance_hostname_scs");
    execute_failover(instance_id => $instance_id_scs, instance_user => $user_scs, instance_type => 'ASCS', wait_for_target => $instance_hostname_scs);
    # Disonnect from ers VM
    disconnect_target_from_serial();

    # Final check
    # Connect to scs VM
    connect_target_to_serial(destination_ip => $ip_scs, ssh_user => $user_scs, switch_root => 1);
    # Execute web method checks
    webmethod_checks($instance_id_scs, $user_scs);
    # Disconnect from scs VM
    disconnect_target_from_serial();
}

1;
