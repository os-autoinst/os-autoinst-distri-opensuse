# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Post deployment screens and checks

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

package check_hana_database;
use warnings FATAL => 'all';
use testapi;
use serial_terminal qw(select_serial_terminal);
use sles4sap::console_redirection;
use sles4sap::console_redirection::redirection_data_tools;
use hacluster;
use sles4sap::database_hana qw(hdb_info);
use sles4sap::sap_host_agent qw(saphostctrl_list_instances);

=head1 NAME

sles4sap/redirection_tests/check_hana_database.pm - Perform checks and display status screens for HANA DB cluster.

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=head1 DESCRIPTION

Module executes checks and provides status screens for HANA database cluster. It is intended to be used on a healthy
cluster, for example after a deployment is finished or at the end of a test sequence. In case of unhealthy cluster,
test will fail.

B<The key tasks performed by this module include:>

=over

=item * Collects connection data to Hana database nodes required for console redirection

=item * Connect to each Hana database node in a loop

=item * Wait for cluster to become idle

=item * Collect data about database instances

=item * Collect content from file B</etc/os-release>

=item * Collect B<SAPHanaSR-showAttr> command output

=item * Collect B<crm_mon> command output

=item * Collect B<HDB info> command output

=item * In case of SBD based fencing is detected, collect data about SBD devices and perform optional check.

=item * Check cluster state

=item * Disconnect from database node

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
    my %database_hosts = %{$redirection_data->get_databases};
    if (!%database_hosts) {
        record_info('N/A', 'Database deployment not detected, skipping.');
        return;
    }
    my %results;

    # DB cluster result collection
    for my $host (keys(%database_hosts)) {
        # Everything is now executed on SUT, not worker VM
        my $ip_addr = $database_hosts{$host}{ip_address};
        my $user = $database_hosts{$host}{ssh_user};
        my %db_instance_results;
        die "Redirection data missing. Got:\nIP: $ip_addr\nUSER: $user\n" unless $ip_addr and $user;
        connect_target_to_serial(destination_ip => $ip_addr, ssh_user => $user, switch_root => 'yes');
        wait_for_idle_cluster();

        my $instance_data = saphostctrl_list_instances(as_root => 'yes', running => 'yes');

        # Collected results will be displayed at the end of the module
        $db_instance_results{Release} = script_output('cat /etc/os-release', quiet => 1);
        $db_instance_results{'System Replication'} = script_output('SAPHanaSR-showAttr', quiet => 1);
        $db_instance_results{'CRM status'} = script_output($crm_mon_cmd, quiet => 1);
        $db_instance_results{'HDB info'} = hdb_info(switch_user => $instance_data->[0]{sidadm}, quiet => 'true');

        my $sbd_devices = list_configured_sbd();
        if (get_var('EXPECTED_SBD_DEVICES_COUNT') || get_fencing_type() =~ /sbd/) {
            $db_instance_results{'SBD devices'} = sbd_device_report(
                device_list => $sbd_devices, expected_sbd_devices_count => get_var('EXPECTED_SBD_DEVICES_COUNT'));
        }
        $results{$host} = \%db_instance_results;

        check_cluster_state();
        disconnect_target_from_serial();
    }

    for my $db_host (keys(%results)) {
        record_info("STATUS $db_host");
        my $host_results = $results{$db_host};
        # Loop over result title and command output
        record_info($_, $host_results->{$_}) foreach keys(%{$host_results});
        my $sbd_check = $host_results->{'SBD devices'};
        die($sbd_check) if $sbd_check && $sbd_check =~ /FAIL/;
    }
}

1;
