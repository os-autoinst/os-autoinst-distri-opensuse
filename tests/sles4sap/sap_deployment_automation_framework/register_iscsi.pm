# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Workaround for multiple cloud registration bugs

use Mojo::Base 'sles4sap::sap_deployment_automation_framework::basetest';

package register_iscsi;
use warnings FATAL => 'all';
use testapi;
use serial_terminal qw(select_serial_terminal);
use sles4sap::console_redirection;
use sles4sap::console_redirection::redirection_data_tools;
use sles4sap::sap_deployment_automation_framework::deployment;

sub run {
    my ($self, $run_args) = @_;
    # Whole module is just a workaround for:
    # https://github.com/sdaf-suse/sap-automation/issues/35
    record_soft_failure('gh#35 Workaround: Registering ISCSI - https://github.com/sdaf-suse/sap-automation/issues/35');
    my $redirection_data = sles4sap::console_redirection::redirection_data_tools->new($run_args->{redirection_data});
    my %iscsi_hosts = %{$redirection_data->get_iscsi_hosts};
    for my $host (keys(%iscsi_hosts)) {
        my $ip_addr = $iscsi_hosts{$host}{ip_address};
        my $user = $iscsi_hosts{$host}{ssh_user};
        die "Redirection data missing. Got:\nIP: $ip_addr\nUSER: $user\n" unless $ip_addr and $user;

        connect_target_to_serial(destination_ip => $ip_addr, ssh_user => $user, switch_root => 'yes');

        # check if there are repositories defined
        unless (script_run('sudo zypper lr')) {
            disconnect_target_from_serial();
            next;
        }

        record_info("NO REG: $host", "Host '$host' has registration issues\n" .
              "\n\n### REPOS ###\n" . script_output('sudo zypper lr', proceed_on_failure => 1) .
              "\n\n### SUSEConnect -s ###\n" . script_output('sudo SUSEConnect -s', proceed_on_failure => 1)
        );

        # Re-register - Repair registration on iscsi hosts
        record_info("Register $host", "Repairing registration on $host");
        my @cleanup_retries = (1 .. 3);
        my $cleanup_rc;
        while (shift @cleanup_retries) {
            $cleanup_rc = script_run('sudo registercloudguest --clean', timeout => 180);
            last unless $cleanup_rc;
        }
        collect_guestregister_logs() if $cleanup_rc;
        die 'Registration cleanup attempts failed' if $cleanup_rc;

        my $register_rc;
        my @register_retries = (1 .. 3);
        while (shift @register_retries) {
            $register_rc = script_run('sudo registercloudguest --force-new', timeout => 180);
            last unless $register_rc;
        }
        collect_guestregister_logs() if $register_rc;
        die 'Registration attempts failed. Check logs for details' if $register_rc;
        record_info('Reg OK', 'Registration repaired');

        disconnect_target_from_serial();
    }
}

1;
