# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: HPC extended tests for some functional specifics
#    This module is meant to provide some specific tests for migrated
#    HPC system. As such this module is not taking care of installing
#    any components, as it is assumed that those components have been
#    already installed on the HPC cluster.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'hpcbase', -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils;

sub run {
    my $nodes = get_required_var("CLUSTER_NODES");

    record_info('Post migration tests');
    barrier_wait('HPC_POST_MIGRATION_TESTS');

    assert_script_run("srun -N ${nodes} /bin/ls");
    assert_script_run("sinfo -N -l");
    barrier_wait('HPC_POST_MIGRATION_TESTS_RUN');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook ($self) {
    select_serial_terminal;
    $self->upload_service_log('slurmd');
    $self->upload_service_log('munge');
    $self->upload_service_log('slurmctld');
    $self->upload_service_log('slurmdbd');
    upload_logs('/var/log/slurmctld.log');
}

1;
