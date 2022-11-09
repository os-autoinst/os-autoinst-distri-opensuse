# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Execute ansible deployment using qe-sap-deployment project.
# https://github.com/SUSE/qe-sap-deployment

use base 'sles4sap_publiccloud_basetest';
use strict;
use warnings;
use testapi;
use Mojo::File 'path';
use publiccloud::utils;
use sles4sap_publiccloud;
use qesapdeployment;
use serial_terminal 'select_serial_terminal';

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    select_serial_terminal;
    my $ha_enabled = get_required_var("HA_CLUSTER") =~ /false|0/i ? 0 : 1;
    my $instances = $run_args->{instances};

    die("Ansible deploymend FAILED. Check 'qesap*' logs for details.") if qesap_execute(cmd => 'ansible', timeout => 3600, verbose => 1) > 0;
    record_info("FINISHED", "Ansible deployment process finished successfully.");
    return unless $ha_enabled;

    # In case of Hana/HA deployment, detect initial primary and secondary site location
    record_info("HANA chk", "Ansible deployment process finished successfully.");
    foreach my $instance (@$instances) {
        $self->{my_instance} = $instance;
        my $instance_id = $instance->{'instance_id'};
        # Skip instances without HANA db
        next if ($instance_id !~ m/vmhana/);
        $self->wait_for_sync();

        # Define initial state for both sites
        # Site A is always PROMOTED (Master node) after deployment
        my $resource_output = $self->run_cmd(cmd => "crm status full", quiet => 1); record_info("crm out", $resource_output);
        my $master_node = $self->get_promoted_hostname();
        $run_args->{site_a} = $instance if ($instance_id eq $master_node);
        $run_args->{site_b} = $instance if ($instance_id ne $master_node);
    }
    record_info("Instances:", "Detected HANA instances:
    Site A (PRIMARY): $run_args->{site_a}{instance_id}
    Site B: $run_args->{site_b}{instance_id}");
    return 1;
}

1;
