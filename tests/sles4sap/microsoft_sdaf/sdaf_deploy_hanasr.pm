# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary:  Executed installation of SAP components using SDAF ansible playbooks according to:
#           https://learn.microsoft.com/en-us/azure/sap/automation/tutorial#sap-application-installation

use parent 'sles4sap::microsoft_sdaf_basetest';
use strict;
use warnings;
use sles4sap::sdaf_library;
use sles4sap::console_redirection;
use serial_terminal qw(select_serial_terminal);
use testapi;

sub test_flags {
    return {fatal => 1};
}

sub run {
    serial_console_diag_banner('Module sdaf_deploy_hanasr.pm : start');
    my $sap_sid = get_required_var('SAP_SID');
    my $vnet_code = get_required_var('SDAF_WORKLOAD_VNET_CODE');

    connect_target_to_serial();
    load_os_env_variables();

    sdaf_execute_playbook(playbook_filename=>'pb_get-sshkey.yaml', sap_sid=>$sap_sid, vnet_code=>$vnet_code);
    sdaf_execute_playbook(playbook_filename=>'playbook_00_validate_parameters.yaml', sap_sid=>$sap_sid, vnet_code=>$vnet_code);
    sdaf_execute_playbook(playbook_filename=>'playbook_01_os_base_config.yaml', sap_sid=>$sap_sid, vnet_code=>$vnet_code);
    sdaf_execute_playbook(playbook_filename=>'playbook_02_os_sap_specific_config.yaml', sap_sid=>$sap_sid, vnet_code=>$vnet_code);
    sdaf_execute_playbook(playbook_filename=>'playbook_04_00_00_db_install.yaml', sap_sid=>$sap_sid, vnet_code=>$vnet_code);

    disconnect_target_from_serial();
    serial_console_diag_banner('Module sdaf_deploy_hanasr.pm : stop');
}

1;
