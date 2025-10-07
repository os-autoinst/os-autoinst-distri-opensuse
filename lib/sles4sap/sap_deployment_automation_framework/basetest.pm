# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
#
# Basetest used for Microsoft SDAF deployment

package sles4sap::sap_deployment_automation_framework::basetest;
use parent 'opensusebasetest';

use strict;
use warnings;
use testapi;
use Exporter qw(import);
use sles4sap::sap_deployment_automation_framework::deployment qw(sdaf_cleanup az_login load_os_env_variables $output_log_file sdaf_upload_logs);
use sles4sap::sap_deployment_automation_framework::deployment_connector;
use sles4sap::sap_deployment_automation_framework::naming_conventions;
use sles4sap::sap_deployment_automation_framework::inventory_tools;
use sles4sap::console_redirection::console_redirection;

our @EXPORT = qw(full_cleanup $serial_regexp_playbook);
our $serial_regexp_playbook = 0;

=head1 SYNOPSIS

Basetest for SDAF deployment. It includes full cleanup routine and post_fail hook.
Post run hook is not necessary as cleanup should not be triggered at the end of each test module.

=cut

=head2 full_cleanup

    full_cleanup();

Function performs full SDAF cleanup. First, it checks which stages of deployment are applied to avoid executing
unnecessary cleanup commands. Cleanup is done in following order:

=over

=item * executes SDAF remover script - destroys existing sap-systems and workload zone deployments

=item * destroys deployer VM and related resources like OS disk, NIC, Security group, etc.

=item *  keeps control plane intact (Control plane must not be deleted)

=back
=cut

sub full_cleanup {
    if (get_var('SDAF_RETAIN_DEPLOYMENT')) {
        record_info('Cleanup OFF', 'OpenQA variable "SDAF_RETAIN_DEPLOYMENT" is active, skipping cleanup.');
        return;
    }

    # Disable any stray redirection being active. This resets the console to the worker VM.
    disconnect_target_from_serial if check_serial_redirection();
    az_login();

    # Check if deployer VM exists and collect required data
    my $deployment_id = find_deployment_id();
    my $deployer_vm_name = $deployment_id ? get_deployer_vm_name(deployment_id => find_deployment_id()) : undef;
    my $deployer_ip = $deployer_vm_name ? get_deployer_ip(deployer_vm_name => $deployer_vm_name) : undef;

    # If deployer exists, check if console redirection is possible
    my $redirection_works;
    if ($deployer_ip) {
        set_var('REDIRECT_DESTINATION_USER', get_var('PUBLIC_CLOUD_USER', 'azureadm'));
        set_var('REDIRECT_DESTINATION_IP', $deployer_ip);
        # Do not fail even if connection is not successful
        $redirection_works = connect_target_to_serial(fail_ok => '1');
    }
    my $sut_cleanup_message
      = $redirection_works
      ? 'Console redirection to Deployer VM does not seem to work. Destroying SUT infrastructure is not possible.'
      : 'Console redirection works, proceeding with SUT cleanup';
    record_info('SUT cleanup', $sut_cleanup_message);

    # Trigger SDAF remover script to destroy 'workload zone' and 'sap systems' resources
    # Clean up all config files, keys, etc.. on deployer VM
    if ($redirection_works) {
        load_os_env_variables();
        az_login();
        sdaf_cleanup();
        disconnect_target_from_serial();    # Exist Deployer console since we are about to destroy it
    }
    # Do not make cleanup fail here, we still need to destroy deployer VM and its resources.
    record_info('SUT cleanup', 'Failed to set up redirection, skipping SDAF cleanup scripts.') unless $redirection_works;

    # Destroys deployer VM and its resources
    destroy_deployer_vm();

    # Clean up orphaned resources inside permanent deployer job group
    # Resource retention time can be controlled by OpenQA parameter: SDAF_DEPLOYER_VM_RETENTION_SEC
    record_info('Remove orphans', 'Cleaning up orphaned resources');
    destroy_orphaned_resources();
    if (my $ret = destroy_orphaned_peerings()) {
        record_info('Retry', 'Delete orphaned peerings failed and retry');
        $ret = destroy_orphaned_peerings();
        if ($ret) {
            die('Delete orphaned peerings failed, please check log and delete manually');
        }
    }
}

sub post_fail_hook {
    my ($self, $run_args) = @_;
    # Flag for uploading SUT losgs if sdaf_execute_playbook() failed
    my $upload_SUT_logs = $serial_regexp_playbook;

    record_info('Post fail', 'Executing post fail hook');
    if (testapi::is_serial_terminal()) {
        # In case playbook/script times out, it will keep occupying the command line,
        # therefore we need to press Ctrl+c to terminate the process.
        # Note:
        #   For playbook please do not use '> ' (or $testapi::distri->{serial_term_prompt})
        #   as there are lots of '> ' in the output of playbook.
        #   For playbook/script 'qr/-\d+-/' is usually the last output from playbook/script execution
        #   For playbook if command contains -v (verbosity) the output may contain 'qr/-\d+-/',
        #   so here uses 'qr/-\d+-Comment/' for regex as 'script_run(xxx, output => xxx)' is used to run playbook
        my $match_re = $testapi::distri->{serial_term_prompt};
        $match_re = qr/-\d+-Comment/ if ($serial_regexp_playbook);
        unless (wait_serial($match_re)) {
            type_string('', terminate_with => 'ETX');
            # Wait for process returns
            wait_serial(qr/-\d+-/);
            type_string("\n");
            if ($serial_regexp_playbook) {
                record_info('Terminated playbook process');
                $serial_regexp_playbook = 0;
                # Upload playbook log file
                upload_logs($sles4sap::sap_deployment_automation_framework::deployment::output_log_file);
            }
            else {
                record_info('Terminated other script process');
            }
        }
    }

    # Disable any stray redirection being active. This resets the console to the worker VM.
    disconnect_target_from_serial if check_serial_redirection();
    az_login();

    # Upload logs before cleanup
    if (get_required_var('TEST') !~ /_deploy_/ || $upload_SUT_logs) {
        # Upload logs appearing in deployer VM
        record_info('Upload logs appearing in deloyer VM');
        # Prepare deployer logs path
        my $sap_sid = get_required_var('SAP_SID');
        my $config_root_path = get_sdaf_config_path(
            deployment_type => 'sap_system',
            vnet_code => get_workload_vnet_code(),
            env_code => get_required_var('SDAF_ENV_CODE'),
            sdaf_region_code => convert_region_to_short(get_required_var('PUBLIC_CLOUD_REGION')),
            sap_sid => $sap_sid);
        my $logs_dir = $config_root_path . '/logs/';
        connect_target_to_serial();

        # Upload deployer logs
        my $qesap_log_find = "find $logs_dir -type f -name '*.zip' 2>/dev/null";
        foreach my $log (split(/\n/, script_output($qesap_log_find, proceed_on_failure => 1))) {
            record_info("Upload file $log");
            upload_logs($log, failok => 1);
        }

        # Upload logs appearing in SUTs
        record_info('Upload logs appearing in SUTs');
        # Prepare redirection data, reset $run_args in case of post_fail_hook being invoked before $run_args is set
        my $inventory_path = get_sdaf_inventory_path(sap_sid => $sap_sid, config_root_path => $config_root_path);
        my $inventory_data = read_inventory_file($inventory_path);
        my $private_key_src_path = get_sut_sshkey_path(config_root_path => $config_root_path);
        $run_args->{sdaf_inventory} = $inventory_data;
        $run_args->{redirection_data} = create_redirection_data(inventory_data => $inventory_data);
        my %redirection_data = %{$run_args->{redirection_data}};
        disconnect_target_from_serial();

        # Prepare ssh config, download ssh private key for accessing SUTs
        my $jump_host_user = get_required_var('REDIRECT_DESTINATION_USER');
        my $jump_host_ip = get_required_var('REDIRECT_DESTINATION_IP');
        my $scp_cmd = join(' ', 'scp ', "$jump_host_user\@$jump_host_ip:$private_key_src_path", $sut_private_key_path);
        assert_script_run($scp_cmd);
        prepare_ssh_config(
            inventory_data => $inventory_data,
            jump_host_ip => $jump_host_ip,
            jump_host_user => $jump_host_user
        );

        # Upload SUTs logs
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

    full_cleanup();
}

1;
