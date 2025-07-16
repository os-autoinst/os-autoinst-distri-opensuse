# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Post deployment screens and checks

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

package check_netweaver;
use strict;
use warnings FATAL => 'all';
use testapi;
use serial_terminal qw(select_serial_terminal);
use sles4sap::console_redirection;
use sles4sap::console_redirection::redirection_data_tools;
use hacluster qw(wait_for_idle_cluster check_cluster_state);
use sles4sap::sap_host_agent qw(saphostctrl_list_instances);
use hacluster qw($crm_mon_cmd);
use sles4sap::sapcontrol qw(sapcontrol);

=head1 NAME

sles4sap/redirection_tests/check_netweaver.pm - Perform checks and display status screens for netweaver instances.

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=head1 DESCRIPTION

Module executes checks and provides status screens for Netweaver instances.

B<The key tasks performed by this module include:>

=over

=item * Collects connection data to all Netweaver instance nodes required for console redirection

=item * Connect to each instance node in a loop

=item * Collect data about Netweaver instances using sapcontrol

=item * Collect SAP related processes using B<ps -ef> command

=item * Collect output from sapcontrol using B<GetProcessList> webmethod

=item * Collect output from sapcontrol using B<GetSystemInstanceList> webmethod

=item * Disconnect from instance node

=item * Display collected outputs using B<record_info> API call

=back

=head1 OPENQA SETTINGS

Test module does not use any OpenQA settings

=cut

sub run {
    my ($self, $run_args) = @_;
    my $redirection_data = sles4sap::console_redirection::redirection_data_tools->new($run_args->{redirection_data});
    my %nw_hosts = %{$redirection_data->get_nw_hosts};
    if (!%nw_hosts) {
        record_info('N/A', 'Netweaver deployment not detected, skipping.');
        return;
    }
    my %results;

    # ENSA2 cluster result collection
    for my $host (keys(%nw_hosts)) {
        # Everything is now executed on SUT, not worker VM
        my $ip_addr = $nw_hosts{$host}{ip_address};
        my $user = $nw_hosts{$host}{ssh_user};
        my %instance_results;
        die "Redirection data missing. Got:\nIP: $ip_addr\nUSER: $user\n" unless $ip_addr and $user;

        connect_target_to_serial(destination_ip => $ip_addr, ssh_user => $user, switch_root => 'yes');
        my $instance_data = saphostctrl_list_instances(as_root => 'yes', running => 'yes');
        # loop commands
        $instance_results{'OS proc'} = script_output('ps -ef| grep sap', quiet => 1);
        $instance_results{'Process list'} = sapcontrol(
            webmethod => 'GetProcessList',
            instance_id => $instance_data->[0]{instance_id},
            sidadm => $instance_data->[0]{sap_sid},
            return_output => 'yes');
        $instance_results{'System instances'} = sapcontrol(
            webmethod => 'GetSystemInstanceList',
            instance_id => $instance_data->[0]{instance_id},
            sidadm => $instance_data->[0]{sap_sid},
            return_output => 'yes');

        $results{$host} = \%instance_results;
        disconnect_target_from_serial();
    }
    record_info('RESULTS');
    for my $host (keys(%results)) {
        record_info("Host: $host");
        my %host_results = %{$results{$host}};
        # Loop over result title and command output
        record_info($_, $host_results{$_}) foreach keys(%host_results);
    }
}

1;
