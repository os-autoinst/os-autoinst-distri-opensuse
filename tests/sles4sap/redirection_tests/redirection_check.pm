# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module serves as a simple check for redirection to be working.
#   It loops over all hosts defined in `$run_args->{redirection_data}` and attempts few common OpenQA api calls.
#   For more information read 'README.md'

use parent 'sles4sap::sap_deployment_automation_framework::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use sles4sap::console_redirection;

sub run {
    my ($self, $run_args) = @_;
    my %redirection_data = %{$run_args->{redirection_data}};

    for my $instance_type (keys(%redirection_data)) {

        for my $hostname (keys(%{$redirection_data{$instance_type}})) {
            my %host_data = %{$redirection_data{$instance_type}{$hostname}};
            record_info("Host: $hostname");
            connect_target_to_serial(
                destination_ip => $host_data{ip_address}, ssh_user => $host_data{ssh_user});

            # Check if hostnames matches with what is expected
            # Check API calls: script_output, assert_script_run
            my $hostname_real = script_output('hostname', quiet => 1);
            assert_script_run("echo \$(hostname) > /tmp/hostname_$hostname_real", quiet => 1);
            die "Expected hostname '$hostname' does not match hostname returned '$hostname_real'"
              unless $hostname_real eq $hostname;
            record_info('API check', "script_output: PASS\nassert_script_run: PASS\nhostname match: PASS");

            # Check if connection between SUT and OpenQA instance works
            # Check API calls: save_tmp_file, upload_logs
            upload_logs("/tmp/hostname_$hostname_real");
            save_tmp_file('hostname.txt', $hostname);
            assert_script_run('curl -s ' . autoinst_url . "/files/hostname.txt| grep $hostname", quiet => 1);
            record_info('API check', "upload_logs: PASS\nsave_tmp_file: PASS\nOpenQA connection: PASS");

            disconnect_target_from_serial();
        }
    }
}

1;
