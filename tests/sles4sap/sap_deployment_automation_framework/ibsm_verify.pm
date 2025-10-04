# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Verify connection between each SUT host and IBSM server IP.

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

package ibsm_verify;

use testapi;
use serial_terminal qw(select_serial_terminal);
use Data::Dumper;
use sles4sap::sap_deployment_automation_framework::naming_conventions;
use sles4sap::console_redirection;
use sles4sap::sap_deployment_automation_framework::deployment;
use sles4sap::console_redirection::redirection_data_tools;
use sles4sap::azure_cli qw(az_network_nic_list);

=head1 NAME

sles4sap/sap_deployment_automation_framework/ibsm_verify.pm - Verify connection between each SUT host and IBSM server IP.

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=head1 DESCRIPTION

Module is used to performs connection checks from each SUT host to IBSM server.

B<The key tasks performed by this module include:>

=over

=item * Collects connection data to all SUT virtual machines required for console redirection

=back

=head1 OPENQA SETTINGS

=over

=item * B<IBSM_RG> : IBSM resource group name

=back
=cut

sub test_flags {
    return {fatal => 1};
}

sub run {
    my ($self, $run_args) = @_;
    unless (get_var('IS_MAINTENANCE')) {
        # Just a safeguard for case the module is in schedule without 'IS_MAINTENANCE' OpenQA setting being set
        record_info('MAINTENANCE OFF', 'OpenQA setting "IS_MAINTENANCE" is disabled, skipping IBSm setup');
        return;
    }
    select_serial_terminal();
    my $redirection_data = sles4sap::console_redirection::redirection_data_tools->new($run_args->{redirection_data});
    my $ibsm_rg = get_required_var('IBSM_RG');
    my $ibsm_ip = ${az_network_nic_list(resource_group => $ibsm_rg,
            query => '"[].ipConfigurations[0].privateIPAddress"')}[0];

    my %sut_hosts = %{$redirection_data->get_sap_hosts};
    my %results;

    for my $host (keys(%sut_hosts)) {
        # Everything is now executed on SUT, not worker VM
        my $ip_addr = $sut_hosts{$host}{ip_address};
        my $user = $sut_hosts{$host}{ssh_user};
        my %host_results;
        die "Redirection data missing. Got:\nIP: $ip_addr\nUSER: $user\n" unless $ip_addr and $user;

        connect_target_to_serial(destination_ip => $ip_addr, ssh_user => $user, switch_root => 'yes');

        $host_results{ibsm_ping} = (script_run("ping -c 3 $ibsm_ip"));

        $results{$host} = \%host_results;
        disconnect_target_from_serial();
    }

    record_info('Results', Dumper(%sut_hosts));
}

1;
