# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary:  Executes list of playbooks compiled according to defined scenario.
#           https://learn.microsoft.com/en-us/azure/sap/automation/tutorial#sap-application-installation
# Playbooks can be found in SDAF repo: https://github.com/Azure/sap-automation/tree/main/deploy/ansible

use parent 'sles4sap::sap_deployment_automation_framework::basetest';
use strict;
use warnings;
use sles4sap::sap_deployment_automation_framework::deployment;
use sles4sap::sap_deployment_automation_framework::naming_conventions;
use sles4sap::console_redirection qw(connect_target_to_serial disconnect_target_from_serial);
use sles4sap::sap_deployment_automation_framework::configure_tfvars qw(validate_components);
use serial_terminal qw(select_serial_terminal);
use testapi;
use publiccloud::utils 'is_byos';

=head1 SYNOPSIS

Executes list of SDAF ansible playbooks according to defined scenario:
          https://learn.microsoft.com/en-us/azure/sap/automation/tutorial#sap-application-installation
Playbooks can be found in SDAF repo: https://github.com/Azure/sap-automation/tree/main/deploy/ansible

List of executed playbooks is compiled using OpenQA setting B<`SDAF_DEPLOYMENT_SCENARIO`>.
It is defined by list of components delimited by a comma ",".
Example: B<SDAF_DEPLOYMENT_SCENARIO="db_install,db_ha,nw_pas,nw_aas,nw_ensa">

B<Available options are:>

=over

=item * B<db_install> - installation and setup of hana database.
    In combination with B<db_ha>, two databases will be deployed in HanaSR setup.

=item * B<db_ha> - Hana SR setup

=item * B<nw_pas> - Installation od primary application server (PAS)
    This includes ASCS (optionally ERS) and database load.

=item * B<nw_aas> - Installs additional application server (AAS)

=item * B<nw_ensa> - Installs ERS and sets up ENSA2 scenario

=back
B<Required OpenQA variables:>
    SDAF_ENV_CODE  Code for SDAF deployment env.
    PUBLIC_CLOUD_REGION SDAF internal code for azure region.
    SAP_SID SAP system ID.
    SDAF_DEPLOYER_RESOURCE_GROUP Existing deployer resource group - part of the permanent cloud infrastructure.
    SDAF_DEPLOYMENT_SCENARIO Defines comma delimited list of installed SAP components.

Optional:
    'SDAF_ANSIBLE_VERBOSITY_LEVEL' Override default verbosity for 'ansible-playbook'.

=cut

sub test_flags {
    return {fatal => 1};
}

sub run {
    # Skip module if existing deployment is being re-used
    return if sdaf_deployment_reused();

    serial_console_diag_banner('Module sdaf_deploy_hanasr.pm : start');
    my $sap_sid = get_required_var('SAP_SID');
    my $sdaf_config_root_dir = get_sdaf_config_path(
        deployment_type => 'sap_system',
        vnet_code => get_workload_vnet_code(),
        env_code => get_required_var('SDAF_ENV_CODE'),
        sdaf_region_code => convert_region_to_short(get_required_var('PUBLIC_CLOUD_REGION')),
        sap_sid => $sap_sid);
    my $sut_private_key_path = get_sut_sshkey_path(config_root_path => $sdaf_config_root_dir);
    # setup = combination of all components chosen for installation
    my @setup = split(/,/, get_required_var('SDAF_DEPLOYMENT_SCENARIO'));
    validate_components(components => \@setup);

    # List of playbooks (and their options) to be executed.
    # Playbook description is here as well: https://learn.microsoft.com/en-us/azure/sap/automation/run-ansible?tabs=linux
    my @execute_playbooks = @{playbook_settings(components => \@setup)};
    my @playbook_list = map { $_->{playbook_filename} } @execute_playbooks;

    record_info('Playbook list', "Following playbooks will be executed:\n" . join("\n", @playbook_list));

    connect_target_to_serial();
    load_os_env_variables();
    # Some playbooks use azure cli
    az_login();

    for my $playbook_options (@execute_playbooks) {
        $sles4sap::sap_deployment_automation_framework::basetest::serial_regexp_playbook = 1;
        sdaf_execute_playbook(%{$playbook_options}, sdaf_config_root_dir => $sdaf_config_root_dir);
        $sles4sap::sap_deployment_automation_framework::basetest::serial_regexp_playbook = 0;

        # tasks needed to be run after playbook 'pb_get-sshkey.yaml'
        if ($playbook_options->{playbook_filename} =~ /pb_get-sshkey/) {
            # Check if SSH key was created by playbook
            record_info('File check', "Check if SSH key '$sut_private_key_path' was created by SDAF");
            assert_script_run("test -f $sut_private_key_path");

            # BYOS image registration must happen before executing any other playbooks
            sdaf_register_byos(
                sap_sid => $sap_sid,
                sdaf_config_root_dir => $sdaf_config_root_dir,
                scc_reg_code => get_required_var('SCC_REGCODE_SLES4SAP'))
              if is_byos() || get_var('PUBLIC_CLOUD_FORCE_REGISTRATION');
        }

    }

    # Display deployment information
    ansible_show_status(sdaf_config_root_dir => $sdaf_config_root_dir, scenarios => \@setup);

    disconnect_target_from_serial();
    serial_console_diag_banner('Module sdaf_deploy_hanasr.pm : stop');
}

1;
