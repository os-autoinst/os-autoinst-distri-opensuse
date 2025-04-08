# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test which does general preparation on jumphost by:
#   - preparing file with OS env variables that are required by SDAF
#   - preparing directory structure and cloning repositories

# Required OpenQA variables:
#     'SDAF_ENV_CODE'  Code for SDAF deployment env.
#     'SDAF_DEPLOYER_VNET_CODE' Deployer virtual network code.
#     'PUBLIC_CLOUD_REGION' SDAF internal code for azure region.
#     'SAP_SID' SAP system ID.
#     'SDAF_DEPLOYER_RESOURCE_GROUP' Existing deployer resource group - part of the permanent cloud infrastructure.

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use strict;
use warnings;
use sles4sap::sap_deployment_automation_framework::deployment;
use sles4sap::console_redirection;
use serial_terminal qw(select_serial_terminal);
use testapi;

sub test_flags {
    return {fatal => 1};
}

# Test uses OpenQA variables as default values for various library functions.
# Fail asap if those variables are missing.
sub check_required_vars {
    my @variables = qw(
      SDAF_ENV_CODE
      SDAF_DEPLOYER_VNET_CODE
      PUBLIC_CLOUD_REGION
      SAP_SID
      SDAF_DEPLOYER_RESOURCE_GROUP
    );
    get_required_var($_) foreach @variables;
}

sub run {
    # Skip module if existing deployment is being re-used
    return if sdaf_deployment_reused();
    serial_console_diag_banner('Module sdaf_deployer_setup.pm : start');
    select_serial_terminal();

    # From now on everything is executed on Deployer VM (residing on cloud).
    connect_target_to_serial();

    my $subscription_id = az_login();
    set_common_sdaf_os_env(subscription_id => $subscription_id);
    prepare_sdaf_project();
    record_info('Jumphost ready');

    # Do not leave connection hanging around between modules.
    disconnect_target_from_serial();
    serial_console_diag_banner('Module sdaf_deployer_setup.pm : end');
}

1;
