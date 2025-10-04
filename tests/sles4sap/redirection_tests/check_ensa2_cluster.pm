# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Post deployment screens and checks for ENSA2 cluster

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

package check_ensa2_cluster;
use warnings FATAL => 'all';
use testapi;
use serial_terminal qw(select_serial_terminal);
use sles4sap::console_redirection::console_redirection;
use sles4sap::console_redirection::redirection_data_tools;
use hacluster;
use sles4sap::sap_host_agent qw(saphostctrl_list_instances);
use sles4sap::sapcontrol qw(sapcontrol);

=head1 NAME

sles4sap/redirection_tests/check_ensa2_cluster.pm - Perform checks and display status screens for ENSA2 cluster.

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=head1 DESCRIPTION

Module executes checks and provides status screens for ENSA2 cluster. It is intended to be used on a healthy
cluster, for example after a deployment is finished or at the end of a test sequence. In case of unhealthy cluster,
test will fail.

B<The key tasks performed by this module include:>

=over

=item * Collects connection data to all ENSA2 cluster nodes required for console redirection

=item * Connect to each cluster node in a loop

=item * Wait for cluster to become idle

=item * Collect data about  instances using sapcontrol

=item * Collect output from sapcontrol using B<HACheckConfig> webmethod

=item * Collect output from sapcontrol using B<HACheckFailoverConfig> webmethod

=item * Check cluster state

=item * Disconnect from instance node

=item * Display collected outputs using B<record_info> API call

=back

=head1 OPENQA SETTINGS

=over

=item * B<EXPECTED_SBD_DEVICES_COUNT> : Number of expected SBD devices. Performs check against what is currently found
    on the cluster. Optional.

=back
=cut


sub run {
    my ($self, $run_args) = @_;
    my $redirection_data = sles4sap::console_redirection::redirection_data_tools->new($run_args->{redirection_data});
    my %ensa2_hosts = %{$redirection_data->get_ensa2_hosts};
    unless ($redirection_data->{nw_ers}) {
        record_info('N/A', 'ENSA2 deployment not detected, skipping.');
        return;
    }
    my %results;

    # ENSA2 cluster result collection
    for my $ensa2_host (keys(%ensa2_hosts)) {
        # Everything is now executed on SUT, not worker VM
        my $ip_addr = $ensa2_hosts{$ensa2_host}{ip_address};
        my $user = $ensa2_hosts{$ensa2_host}{ssh_user};
        my %ensa2_instance_results;
        die "Redirection data missing. Got:\nIP: $ip_addr\nUSER: $user\n" unless $ip_addr and $user;

        connect_target_to_serial(destination_ip => $ip_addr, ssh_user => $user, switch_root => 'yes');
        wait_for_idle_cluster();

        my $instance_data = saphostctrl_list_instances(as_root => 'yes', running => 'yes');

        $ensa2_instance_results{'CRM status'} = script_output($crm_mon_cmd, quiet => 1);
        $ensa2_instance_results{'HA Check Config'} = sapcontrol(
            webmethod => 'HACheckConfig',
            instance_id => $instance_data->[0]{instance_id},
            sidadm => $instance_data->[0]{sap_sid},
            return_output => 'yes');
        $ensa2_instance_results{'HA Failover Config'} = sapcontrol(
            webmethod => 'HACheckFailoverConfig',
            instance_id => $instance_data->[0]{instance_id},
            sidadm => $instance_data->[0]{sap_sid},
            return_output => 'yes');

        my $sbd_devices = list_configured_sbd();
        if (get_var('EXPECTED_SBD_DEVICES_COUNT') || get_fencing_type() =~ /sbd/) {
            $ensa2_instance_results{'SBD devices'} = sbd_device_report(
                device_list => $sbd_devices, expected_sbd_devices_count => get_var('EXPECTED_SBD_DEVICES_COUNT'));
        }
        $results{$ensa2_host} = \%ensa2_instance_results;

        check_cluster_state();
        disconnect_target_from_serial();
    }

    record_info('RESULTS');
    for my $ensa2_host (keys(%results)) {
        record_info("STATUS $ensa2_host");
        my $ensa2_host_results = $results{$ensa2_host};
        # Loop over result title and command output
        record_info($_, $ensa2_host_results->{$_}) foreach keys(%{$ensa2_host_results});
        my $sbd_check = $ensa2_host_results->{'SBD check'};
        die($sbd_check) if $sbd_check && $sbd_check =~ /FAIL/;
    }
}

1;
