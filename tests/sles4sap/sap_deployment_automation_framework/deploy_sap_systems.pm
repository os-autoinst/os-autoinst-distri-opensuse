# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Deployment of the SAP systems zone using SDAF automation

use parent 'sles4sap::sap_deployment_automation_framework::basetest';
use Mojo::Base 'publiccloud::basetest';

use strict;
use warnings;
use sles4sap::sap_deployment_automation_framework::deployment
  qw(serial_console_diag_banner load_os_env_variables sdaf_execute_deployment az_login sdaf_deployment_reused);
use sles4sap::sap_deployment_automation_framework::configure_tfvars qw(prepare_tfvars_file);
use sles4sap::sap_deployment_automation_framework::deployment_connector qw(no_cleanup_tag);
use sles4sap::sap_deployment_automation_framework::naming_conventions;
use sles4sap::console_redirection;
use serial_terminal qw(select_serial_terminal);
use testapi;

=head1 SYNOPSIS

Executes SDAF deployment of SAP systems infrastructure (SUT VM and related resources).
No APP installation or configuration is done at this point.

TFVARS file is composed using OpenQA setting B<`SDAF_DEPLOYMENT_SCENARIO`>.
It is defined by list of components delimited by a comma ",".
Example: B<SDAF_DEPLOYMENT_SCENARIO="db_install,db_ha,nw_pas,nw_aas,nw_ensa">

B<Available options are:>

=over

=item * B<db_install> - installation and setup of hana database.
    In combination with B<db_ha>, two databases will be deployed in HanaSR setup.

=item * B<db_ha> - Hana SR setup

=item * B<db_ha> - Hana SR setup

=item * B<nw_pas> - Installation od primary application server (PAS)
    This includes ASCS (optionally ERS) and database load.

=item * B<nw_aas> - Installs additional application server (AAS)

=item * B<nw_ensa> - Installs ERS and sets up ENSA2 scenario

=back
B<Required OpenQA settings:>
    SDAF_DEPLOYMENT_SCENARIO - See above
    SDAF_ENV_CODE - Code for SDAF deployment env.
    PUBLIC_CLOUD_REGION - SDAF internal code for azure region.
    SAP_SID - SAP system ID.
B<Optional OpenQA settings:>
    SDAF_FENCING_MECHANISM - Fencing mechanism. Default: MSI
        Accepted values: 'msi' - MSI fencing agent, 'sbd' - iscsi based SBD device, 'asd' - Azure shared disk as SBD device
    SDAF_ISCSI_DEVICE_COUNT - Number of iSCSI devices to be used for SBD. Default: 1
=cut

sub test_flags {
    return {fatal => 1};
}

sub run {
    my ($self) = @_;
    # Skip module if existing deployment is being re-used
    return if sdaf_deployment_reused();
    serial_console_diag_banner('Module sdaf_deploy_sap_systems.pm : start');
    select_serial_terminal();
    my $env_code = get_required_var('SDAF_ENV_CODE');
    my $sap_sid = get_required_var('SAP_SID');
    my $workload_vnet_code = get_workload_vnet_code();
    my $sdaf_region_code = convert_region_to_short(get_required_var('PUBLIC_CLOUD_REGION'));

    # SAP systems use same VNET as workload zone
    set_var('SDAF_VNET_CODE', $workload_vnet_code);
    # Setup Workload zone openQA variables - used for tfvars template
    set_var('SDAF_RESOURCE_GROUP', generate_resource_group_name(deployment_type => 'sap_system'));

    # From now on everything is executed on Deployer VM (residing on cloud).
    connect_target_to_serial();
    load_os_env_variables();

    my @installed_components = split(',', get_required_var('SDAF_DEPLOYMENT_SCENARIO'));
    my $os;
    # This section is only needed by Azure tests using images uploaded
    if (get_var('PUBLIC_CLOUD_IMAGE_LOCATION')) {
        my $provider = $self->provider_factory();
        $os = $self->{provider}->get_image_id();
    } else {
        $os = get_required_var('PUBLIC_CLOUD_IMAGE_ID');
    }

    # Add no cleanup tag if the deployment should be kept after test finished
    set_var('SDAF_NO_CLEANUP', '"' . no_cleanup_tag() . '" = "1"') if get_var('SDAF_RETAIN_DEPLOYMENT');

    prepare_tfvars_file(deployment_type => 'sap_system', os_image => $os, components => \@installed_components);

    # Custom VM sizing since default VMs are way too large for functional testing
    # Check for details: https://learn.microsoft.com/en-us/azure/sap/automation/configure-extra-disks#custom-sizing-file
    my $config_root_path = get_sdaf_config_path(
        deployment_type => 'sap_system',
        vnet_code => $workload_vnet_code,
        sap_sid => $sap_sid,
        sdaf_region_code => $sdaf_region_code,
        env_code => $env_code);

    my $retrieve_custom_sizing = join(' ', 'curl', '-v', '-fL',
        data_url('sles4sap/sap_deployment_automation_framework/custom_sizes.json'),
        '-o', $config_root_path . '/custom_sizes.json');

    assert_script_run($retrieve_custom_sizing);

    az_login();
    sdaf_execute_deployment(deployment_type => 'sap_system', timeout => 3600);

    my @check_files = (
        "$config_root_path/sap-parameters.yaml",
        get_sdaf_inventory_path(sap_sid => $sap_sid, config_root_path => $config_root_path));
    for my $file (@check_files) {
        record_info('File check', "Check if file '$file' was created by SDAF");
        assert_script_run("cat $file");
    }

    # diconnect the console
    disconnect_target_from_serial();

    # reset temporary variables
    set_var('SDAF_RESOURCE_GROUP', undef);
    set_var('SDAF_VNET_CODE', undef);
    serial_console_diag_banner('Module sdaf_deploy_sap_systems.pm : end');
}

1;
