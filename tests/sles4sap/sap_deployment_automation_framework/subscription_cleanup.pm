# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test which does general preparation on jumphost by:

=head1 SYNOPSIS

This is not a test module but part of teardown for instances running SDAF
deployment based tests.
Module scans subscription defined by OpenQA settings and destroys resources
left after failed deployment and jobs. This module is supposed to be scheduled
independently from any test scenarios.


=cut

use Mojo::Base 'sles4sap::sap_deployment_automation_framework::basetest';
use strict;
use warnings FATAL => 'all';
use serial_terminal qw(select_serial_terminal);
use testapi;
use sles4sap::sap_deployment_automation_framework::deployment
  qw(az_login check_credentials);
use sles4sap::sap_deployment_automation_framework::subscription_cleanup;


sub run {
    my ($self) = @_;
    select_serial_terminal();
    if (get_var('SDAF_CLEANUP_DRYRUN')) {
        record_info('DRYRUN MODE',
            '"SDAF_CLEANUP_DRYRUN" enabled. No resources will be destroyed');
    }
    az_login();
    assert_script_run('az extension add --name resource-graph --upgrade');
    my $cleanup_result = sles4sap::sap_deployment_automation_framework::subscription_cleanup->new();
    record_info('Collect DATA', 'Collecting data about orphaned resources');
    $cleanup_result->get_orphaned_resource_groups();
    record_info('Destroy groups', 'Destroying orphaned groups');
    $cleanup_result->destroy_orphaned_groups();
    record_info('Destroy VMs', 'Destroying orphaned Deployer VMs');
    $cleanup_result->get_orphaned_resources();
    $cleanup_result->destroy_orphaned_resources();
    $cleanup_result->export_cleanup_report();

    # Report page
    my $results = $cleanup_result->{results};
    my @groups = map { "$_->{name}: " . ($_->{result} // 'not processed') }
      (@{$results->{sap_systems}}, @{$results->{workload_zones}});
    my @vms = map { "$_->{resourceGroup}/$_->{name}: " . ($_->{result} // 'not processed') }
      @{$results->{deployer_vms}};
    record_info('Destroyed groups', @groups ? join("\n", @groups) : 'No orphaned resource groups found');
    record_info('Destroyed VMs', @vms ? join("\n", @vms) : 'No orphaned Deployer VM resources found');

    # Summary is updated by 'export_cleanup_report()'
    my $summary = $cleanup_result->{summary};
    record_info('Summary', join("\n",
            "Found: $summary->{found}",
            "Deleted: $summary->{deleted}",
            "Failed: $summary->{failed}",
            "Skipped: $summary->{skipped}"),
        result => $summary->{failed} ? 'fail' : 'ok');
    # Set test result to failed if one or more deletions failed
    $self->result('fail') if $summary->{failed};
}

sub test_flags {
    return {fatal => 1};
}

1;
