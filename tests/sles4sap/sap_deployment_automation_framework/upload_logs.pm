# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary:  Upload logs. SDAF log collection might need to be expanded beyond deployment logs.
#   Logs to be collected:
#   - crm report
#   - logs appearing in deloyer VM:
#     for example:
#     azureadm@labsecedep10deploy00:/tmp/Azure_SAP_Automated_Deployment_1885/WORKSPACES/SYSTEM/LAB-SECE-1885-QES/logs> ls
#       QES_DBLOAD.zip  QES_ERS.zip  QES_SCS.zip
#   - Those only appear after NW related installation, but include sapinst log.
#   - The logs that are collected in HANA and NW jobs
#   - Supportconfig

use parent 'sles4sap::sap_deployment_automation_framework::basetest';
use strict;
use warnings;
use sles4sap::sap_deployment_automation_framework::deployment;
use sles4sap::sap_deployment_automation_framework::naming_conventions;
use sles4sap::console_redirection qw(connect_target_to_serial disconnect_target_from_serial);
use testapi;

sub test_flags {
    return {fatal => 1};
}

sub run {
    my ($self, $run_args) = @_;
    my %redirection_data = %{$run_args->{redirection_data}};
    my $sap_sid = get_required_var('SAP_SID');
    my $sdaf_config_root_dir = get_sdaf_config_path(
        deployment_type => 'sap_system',
        vnet_code => get_workload_vnet_code(),
        env_code => get_required_var('SDAF_ENV_CODE'),
        sdaf_region_code => convert_region_to_short(get_required_var('PUBLIC_CLOUD_REGION')),
        sap_sid => $sap_sid);
    my $logs_dir = $sdaf_config_root_dir . '/logs/';

    # Upload logs appearing in deloyer VM
    connect_target_to_serial();
    my $str = script_output("ls $logs_dir", proceed_on_failure => 1);
    if ($str !~ /No such file or directory/) {
        record_info("Upload files under $logs_dir: $str");
        my @files = split(/\s+/, $str);
        foreach my $file (@files) {
            upload_logs($logs_dir . $file, failok => 1);
        }
    }
    disconnect_target_from_serial();

    # Upload logs appearing in SUT
    for my $instance_type (keys(%redirection_data)) {
        next() unless grep /$instance_type/, qw(db_hana nw_ers nw_ascs);
        for my $hostname (keys(%{$redirection_data{$instance_type}})) {
            my %host_data = %{$redirection_data{$instance_type}{$hostname}};
            connect_target_to_serial(
                destination_ip => $host_data{ip_address}, ssh_user => $host_data{ssh_user}, switch_root => '1');
            sdaf_upload_logs(hostname => $hostname, sap_sid => $sap_sid);
            disconnect_target_from_serial();
        }
    }
}

1;
