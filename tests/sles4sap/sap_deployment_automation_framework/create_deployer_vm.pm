# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module for creating SDAF Deployer VM by cloning existing OS snapshot, containing all SDAF tools.
#   Snapshot is a permanent clone of original Deployer disk and must be created beforehand.
#   This test module expects it to already exists with default name 'deployer_snapshot_latest' or defined by
#   OpenQA parameter SDAF_DEPLOYER_SNAPSHOT

# Required OpenQA variables:
# 'SDAF_DEPLOYER_RESOURCE_GROUP' Existing deployer resource group - part of the permanent cloud infrastructure.

# Optional:
# 'SDAF_DEPLOYER_SNAPSHOT' define existing snapshot name to be used as a source
# 'SDAF_DEPLOYER_MACHINE' override default value for VM size

use parent 'sles4sap::sap_deployment_automation_framework::basetest';
use strict;
use warnings;
use sles4sap::sap_deployment_automation_framework::deployment
  qw(serial_console_diag_banner az_login sdaf_deployment_reused);
use sles4sap::sap_deployment_automation_framework::deployment_connector qw(get_deployer_ip no_cleanup_tag);
use sles4sap::sap_deployment_automation_framework::naming_conventions qw(generate_deployer_name);
use sles4sap::azure_cli qw(az_disk_create);
use serial_terminal qw(select_serial_terminal);
use mmapi qw(get_current_job_id);
use testapi;

sub test_flags {
    return {fatal => 1};
}

sub run {
    # Skip module if existing deployment is being re-used
    return if sdaf_deployment_reused();
    select_serial_terminal();
    serial_console_diag_banner('Module sdaf_clone_deployer.pm : start');

    my $deployer_resource_group = get_required_var('SDAF_DEPLOYER_RESOURCE_GROUP');
    my $snapshot_source_disk = get_var('SDAF_DEPLOYER_SNAPSHOT', 'deployer_snapshot_latest');
    my $deployer_vm_size = get_var('SDAF_DEPLOYER_MACHINE', 'Standard_B2als_v2');    # Small VM to control costs
    my $new_deployer_vm_name = generate_deployer_name();
    my $deployer_disk_name = "$new_deployer_vm_name\_OS";

    # VM resource tags are used for sharing information between test modules and test jobs
    # 'deployment_id' (equals test ID) tag identifies which test used the VM for deployment.
    # Check SYNOPSIS section of: sles4sap::sap_deployment_automation_framework::deployment_connector
    # for more details
    my @deployment_tags = ('deployment_id=' . get_current_job_id());

    # Add no cleanup tag if the deployment should be kept after test finished
    push @deployment_tags, no_cleanup_tag() . "=1" if get_var('SDAF_RETAIN_DEPLOYMENT');

    az_login();
    record_info('VM create', "Creating deployer vm with parameters:\n
    Resource group: $deployer_resource_group\n
    VM name: $new_deployer_vm_name\n
    VM size: $deployer_vm_size
    Cloned snapshot:$snapshot_source_disk\n");

    # Create OS disk from snapshot
    az_disk_create(
        resource_group => $deployer_resource_group,
        name => $deployer_disk_name,
        source => $snapshot_source_disk,
        tags => join(' ', @deployment_tags)
    );

    # Create new VM clone
    my $vm_create_cmd = join(' ', 'az vm create',
        "--resource-group $deployer_resource_group",
        "--name $new_deployer_vm_name",
        "--attach-os-disk $deployer_disk_name",
        "--size $deployer_vm_size",
        "--os-type Linux",
        "--tags " . join(' ', @deployment_tags)    # This tag is used to find correct deployer VM by other modules
    );
    assert_script_run($vm_create_cmd, timeout => 600);

    # Collect deployer IP to be shown in the result page
    # get_deployer_ip() also checks VM is listening to SSH port. This serves as an availability check.
    my $deployer_ip = get_deployer_ip(deployer_resource_group => $deployer_resource_group,
        deployer_vm_name => $new_deployer_vm_name);

    die 'Deployer public IP address not found or is not listening to SSH port.' unless $deployer_ip;
    record_info('VM created', "Deployer VM was created with public IP: $deployer_ip");
    serial_console_diag_banner('Module sdaf_clone_deployer.pm : stop');
}

1;
