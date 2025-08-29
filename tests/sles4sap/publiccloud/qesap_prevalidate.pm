# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Check qe-sap-deployment health before start using it.
# https://github.com/SUSE/qe-sap-deployment

use base 'sles4sap_publiccloud_basetest';
use testapi;
use publiccloud::utils;
use sles4sap_publiccloud;
use serial_terminal 'select_serial_terminal';

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
        $instance->update_instance_ip();
        $instance->wait_for_ssh();

        # Skip instances without HANA db or setup without cluster
        next if ($instance_id !~ m/vmhana/) or !$ha_enabled;

        # check zypper ref for errors
        $self->check_zypper_ref();

        # Output the version of tool 'SAPHanaSR-showAttr'
        record_info('SAPHanaSR version number', $self->saphanasr_showAttr_version());

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
    $self->wait_for_cluster(wait_time => 60, max_retries => 10);

    record_info(
        'Instances:', "Detected HANA instances:
    Site A (PRIMARY): $run_args->{$hana_sites[0]}{instance_id}
    Site B: $run_args->{$hana_sites[1]}{instance_id}"
    );
}

1;
