# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Public Cloud - Resource Cleanup
# This module deletes the Azure resource group to:
# - Free up cloud resources
# - Avoid additional cost
# - Clean up the environment
# It's also implemented as a post_fail_hook to ensure resources
# are deleted even if a test module fails.

use Mojo::Base 'publiccloud::basetest';
use testapi;
use mmapi 'get_current_job_id';
use serial_terminal 'select_serial_terminal';


sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    my $rg = get_required_var('RG');
    record_info('AZURE CLEANUP', "Deleting resource group: $rg");
    assert_script_run("az group delete --name $rg -y", timeout => 600);
    assert_script_run("az group wait --name $rg --deleted");
    record_info('Done', 'Test finished');
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
