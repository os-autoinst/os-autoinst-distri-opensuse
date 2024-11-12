# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Check qe-sap-deployment health before start using it.
# https://github.com/SUSE/qe-sap-deployment

use strict;
use warnings;
use base 'sles4sap_publiccloud_basetest';
use testapi;
use publiccloud::utils;
use sles4sap_publiccloud;
use serial_terminal 'select_serial_terminal';
use version_utils 'is_sle';

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;

    # Needed to have peering and ansible state propagated in post_fail_hook
    $self->import_context($run_args);

    my $ha_enabled = get_required_var('HA_CLUSTER') =~ /false|0/i ? 0 : 1;
    select_serial_terminal;

    # Check connectivity to all instances and status of the cluster in case of HA deployment
    my @hana_sites = get_hana_site_names();
    foreach my $instance (@{$self->{instances}}) {
        $self->{my_instance} = $instance;
        my $instance_id = $instance->{'instance_id'};
        # Check ssh connection for all hosts
        $instance->wait_for_ssh(scan_ssh_host_key => 1);

        # Skip instances without HANA db or setup without cluster
        next if ($instance_id !~ m/vmhana/) or !$ha_enabled;

        $self->wait_for_sync();

        # Define initial state for both sites
        # Site A is always PROMOTED (Master node) after deployment
        my $resource_output = $self->run_cmd(cmd => "crm status full", quiet => 1);
        record_info("crm out", $resource_output);
        my $master_node = $self->get_promoted_hostname();

        if ($instance_id eq $master_node) {
            $run_args->{$hana_sites[0]} = $instance;
        }
        else {
            $run_args->{$hana_sites[1]} = $instance;
        }
    }

    # Exit early if not in cluster scenario
    return unless $ha_enabled;

    # Check cluster for overall readiness (nodes online, in sync and crm output contains no failed resources)
    # First make sure that instance in $self->{my_instance} is a hana node
    foreach my $instance (@{$self->{instances}}) {
        $self->{my_instance} = $instance;
        last if ($instance->{instance_id} =~ m/vmhana/);
    }

    # Special 12sp5 handling due to https://bugzilla.suse.com/show_bug.cgi?id=1233026
    if (is_sle('=12-SP5')) {
        my ($rc, $crm_output) = $self->wait_for_cluster(wait_time => 60, max_retries => 10, proceed_on_failure => 1);
        if (!$rc) {
            # Failure: Check for 'TimeoutError' in the output for bsc#1233026
            if ($crm_output =~ /TimeoutError/) {
                record_soft_failure("bsc#1233026 - Error occurred, see previous output: Proceeding despite failure.");
            } else {
                die "Cluster check failed - see previous output.";
            }
        }
    }
    else {
        $self->wait_for_cluster(wait_time => 60, max_retries => 10);
    }

    record_info(
        'Instances:', "Detected HANA instances:
    Site A (PRIMARY): $run_args->{$hana_sites[0]}{instance_id}
    Site B: $run_args->{$hana_sites[1]}{instance_id}"
    );
}

1;
