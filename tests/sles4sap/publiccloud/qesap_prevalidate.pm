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
use version_utils qw(check_version);

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
        $instance->wait_for_ssh;

        # Skip instances without HANA db or setup without cluster
        next if ($instance_id !~ m/vmhana/) or !$ha_enabled;

        # Example usage of pacemaker_version
        my $pacemaker_version = $self->pacemaker_version();
        record_info('PACEMAKER VERSION', $pacemaker_version);
        if (check_version('>=2.1.7', $pacemaker_version)) {
            record_info("PACEMAKER >= 2.1.7");
        }
        else {
            record_info("PACEMAKER < 2.1.7");
        }
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

    return unless $ha_enabled;

    record_info(
        'Instances:', "Detected HANA instances:
    Site A (PRIMARY): $run_args->{$hana_sites[0]}{instance_id}
    Site B: $run_args->{$hana_sites[1]}{instance_id}"
    );
}

1;
