# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module serves as a demonstration of executing simple HA/SLES4SAP on-premise libraries on remote host
#   using console redirection.
#   It loops over all hosts defined in `$run_args->{redirection_data}` and executes selected functions on each host.
#   For more information read 'README.md'

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use warnings;
use strict;
use testapi;
use serial_terminal qw(select_serial_terminal);
use sles4sap::console_redirection;
use hacluster qw(check_cluster_state wait_until_resources_started wait_for_idle_cluster);
use saputils;
use Data::Dumper;

sub run {
    my ($self, $run_args) = @_;
    my %redirection_data = %{$run_args->{redirection_data}};

    for my $instance_type (keys(%redirection_data)) {
        next() unless grep /$instance_type/, qw(ha_node db_hana nw_ascs nw_ers);
        for my $hostname (keys(%{$redirection_data{$instance_type}})) {
            my %host_data = %{$redirection_data{$instance_type}{$hostname}};
            connect_target_to_serial(
                destination_ip => $host_data{ip_address}, ssh_user => $host_data{ssh_user}, switch_root => '1');
            # hacluster lib
            record_info('HA wait', 'Waiting for resources to start');
            wait_until_resources_started();
            wait_for_idle_cluster();
            record_info('HA check', 'Checking state of HA cluster resources');
            check_cluster_state();

            # saputils lib
            my $topology = calculate_hana_topology(input => script_output('SAPHanaSR-showAttr --format=script'));
            record_info('Topology', Dumper($topology));

            my $crm_out = check_crm_output(input => script_output('crm_mon -R -r -n -N -1'));
            record_info('CRM check', Dumper($crm_out));

            disconnect_target_from_serial();
        }
    }
}

1;
