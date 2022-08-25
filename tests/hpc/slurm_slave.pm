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
use lockapi;
use utils;
use version_utils 'is_sle';

sub run ($self) {
    $self->prepare_user_and_group();

    # Install slurm
    zypper_call('in slurm-munge');
    # install slurm-node if sle15, not available yet for sle12
    zypper_call('in slurm-node') if is_sle '15+';

    if (get_required_var('EXT_HPC_TESTS')) {
        zypper_ar(get_required_var('DEVEL_TOOLS_REPO'), no_gpg_check => 1);
        zypper_call('in iputils python');
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
    $self->select_serial_terminal;
    $self->upload_service_log('slurmd');
    $self->upload_service_log('munge');
}

1;
