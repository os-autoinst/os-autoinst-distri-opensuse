# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Setup peering between SUT VNET and IBSm VNET

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use testapi;
use serial_terminal qw(select_serial_terminal);
use qam qw(get_test_repos);
use sles4sap::azure_cli;
use sles4sap::sap_deployment_automation_framework::naming_conventions;
use sles4sap::sap_deployment_automation_framework::deployment;
use sles4sap::console_redirection;

=head1 NAME

sles4sap/sap_deployment_automation_framework/ibsm_configure.pm - Setup connection between ISBM and Workload zone VNETs.

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=head1 DESCRIPTION

Test module sets up network peering between tests workload zone and IBSm VNET.

B<The key tasks performed by this module include:>

=over

=item * Verifies if test module was executed with 'IS_MAINTENANCE' OpenQA setting and returns if IBSm connection is not required.

=item * Collects data required for creating network peerings

=item * Creates resources for two way peering between two VNETs

=item * Creates DNS zone and record for all SUTs to access ISBM host using FQDN defined by OpenQA setting B<'REPO_MIRROR_HOST'>

=item * Verifies if peering resources were created

=back

=head1 OPENQA SETTINGS

=over

=item * B<IBSM_RG> : IBSm resource group name

=item * B<IS_MAINTENANCE> : Define if test scenario includes applying maintenance updates

=item * B<REPO_MIRROR_HOST> : IBSm repository hostname

=back
=cut

sub test_flags {
    return {fatal => 1};
}

sub run {
    unless (get_var('IS_MAINTENANCE')) {
        # Just a safeguard for case the module is in schedule without 'IS_MAINTENANCE' OpenQA setting being set
        record_info('MAINTENANCE OFF', 'OpenQA setting "IS_MAINTENANCE" is disabled, skipping IBSm setup');
        return;
    }
    my $env_code = get_required_var('SDAF_ENV_CODE');
    my $sap_sid = get_required_var('SAP_SID');
    my $workload_vnet_code = get_workload_vnet_code();
    my $sdaf_region_code = convert_region_to_short(get_required_var('PUBLIC_CLOUD_REGION'));
    my $config_root_path = get_sdaf_config_path(
        deployment_type => 'sap_system',
        vnet_code => $workload_vnet_code,
        sap_sid => $sap_sid,
        sdaf_region_code => $sdaf_region_code,
        env_code => $env_code);

    my @repo_list = get_test_repos();

    # From now on everything is executed on Deployer VM (residing on cloud).
    connect_target_to_serial();
    load_os_env_variables();

    # Retrieve playbook and place it to the standard playbook directory
    my $playbook_filename = 'patch_and_reboot.yml';
    my $playbook_file = playbook_dir() . "/$playbook_filename";
    my $cmd_playbook_fetch = join(' ', 'curl', '-v', '-fL',
        data_url("sles4sap/sap_deployment_automation_framework/patch_and_reboot.yml"),
        '-o', $playbook_file);
    assert_script_run($cmd_playbook_fetch);
    record_info('Patching', "All systems are about to be patched using playbook '$playbook_file'");
    # Execute playbook.
    sdaf_execute_playbook(
        playbook_filename=>$playbook_filename,
        sdaf_config_root_dir=>$config_root_path,
        additional_args=>{ 'extra-vars'=>'repo_list=' . join(',', @repo_list) }
    );
    record_info('Patching OK', "All systems are patched using playbook '$playbook_file'. Reboot was performed afterwards");
    # disconnect the console
    disconnect_target_from_serial();
}

1;