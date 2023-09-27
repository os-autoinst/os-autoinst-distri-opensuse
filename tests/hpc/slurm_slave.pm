# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: HPC_Module: slurm slave
#    This test is setting up a slurm slave and tests if the daemon can start
# Maintainer: Kernel QE <kernel-qa@suse.de>
# Tags: https://fate.suse.com/316379, https://progress.opensuse.org/issues/20308

use Mojo::Base 'hpcbase', -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils;
use hpc::utils 'get_slurm_version';

sub run ($self) {
    select_serial_terminal();
    $self->prepare_user_and_group();
    my $slurm_pkg = get_slurm_version(get_var('SLURM_VERSION', ''));

    # Install slurm
    # $slurm_pkg-munge is installed explicitly since slurm_23_02
    zypper_call("in $slurm_pkg-node $slurm_pkg-munge");

    my %users = (
        'user_1' => 'Sebastian',
        'user_2' => 'Egbert',
        'user_3' => 'Christina',
        'user_4' => 'Jose',
    );

    foreach my $key (keys %{users}) {
        script_run("useradd -m $users{$key}");
    }

    barrier_wait('CLUSTER_PROVISIONED');
    barrier_wait("SLURM_SETUP_DONE");
    barrier_wait('SLURM_SETUP_DBD');
    barrier_wait("SLURM_MASTER_SERVICE_ENABLED");

    # enable and start munge
    $self->enable_and_start('munge');

    # enable and start slurmd
    $self->enable_and_start('slurmd');
    systemctl 'status slurmd';
    barrier_wait("SLURM_SLAVE_SERVICE_ENABLED");

    barrier_wait("SLURM_MASTER_RUN_TESTS");
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook ($self) {
    $self->destroy_test_barriers();
    select_serial_terminal;
    $self->upload_service_log('slurmd');
    $self->upload_service_log('munge');
}

1;
