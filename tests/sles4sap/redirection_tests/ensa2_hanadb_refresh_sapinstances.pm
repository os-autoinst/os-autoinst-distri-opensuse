# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module tests ENSA2 Central Services with HANA DB - refresh sapinstance ASCS & ERS.
#   After refresh no failover happens, fail count stays at 0, cluster is healthy.

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use warnings;
use strict;
use testapi;
use serial_terminal qw(select_serial_terminal);
use sles4sap::console_redirection;
use hacluster qw(execute_crm_resource_refresh_and_check);
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
    # Disconnect from deployer VM
    disconnect_target_from_serial();

    # Get scs instance data
    my %instance_data_scs = %{$redirection_data{nw_ascs}};
    my $instance_hostname_scs = (keys(%instance_data_scs))[0];
    my $ip_scs = $instance_data_scs{$instance_hostname_scs}{ip_address};
    my $user_scs = $instance_data_scs{$instance_hostname_scs}{ssh_user};
    # Get ers instance data
    my %instance_data_ers = %{$redirection_data{nw_ers}};
    my $instance_hostname_ers = (keys(%instance_data_ers))[0];
    my $ip_ers = $instance_data_ers{$instance_hostname_ers}{ip_address};
    my $user_ers = $instance_data_ers{$instance_hostname_ers}{ssh_user};

    # Test refresh sapinstance resource: ASCS
    # Connect to scs VM
    connect_target_to_serial(destination_ip => $ip_scs, ssh_user => $user_scs, switch_root => 1);
    # Refresh resource test
    execute_crm_resource_refresh_and_check(instance_type => 'ASCS', instance_id => $instance_id_scs, instance_hostname => $instance_hostname_scs);
    # Disconnect from scs VM
    disconnect_target_from_serial();

    # Test refresh sapinstance resource: ERS
    # Connect to ers VM
    connect_target_to_serial(destination_ip => $ip_ers, ssh_user => $user_ers, switch_root => 1);
    # Refresh resource test
    execute_crm_resource_refresh_and_check(instance_type => 'ERS', instance_id => $instance_id_ers, instance_hostname => $instance_hostname_ers);
    # Disconnect from ers VM
    disconnect_target_from_serial();
}

1;
