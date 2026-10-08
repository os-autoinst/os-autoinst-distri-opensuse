# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: HPC Slave
#    This test is setting up an HPC slave node, so that various services
#    are ready to be used
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::migration);
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils;
use version_utils 'is_sle';

sub run {
    my $self = shift;
    my $nodes = get_required_var("CLUSTER_NODES");
    $self->prepare_user_and_group();

    # make sure products are registered; it might happen that the older SPs aren't
    # register with valid scc regcode
    if (get_var("HPC_MIGRATION")) {
        $self->register_products();
        barrier_wait("HPC_PRE_MIGRATION");
    }

    zypper_call('in slurm-munge ganglia-gmond');
    # install slurm-node if sle15, not available yet for sle12
    zypper_call('in slurm-node slurm') if is_sle '15+';

    barrier_wait("HPC_SETUPS_DONE");
    barrier_wait("HPC_MASTER_SERVICES_ENABLED");

    $self->enable_and_start("gmond");
    systemctl("is-active gmond");
    $self->enable_and_start("munge");
    systemctl("is-active munge");
    $self->enable_and_start("slurmd");
    systemctl("is-active slurmd");
    barrier_wait("HPC_SLAVE_SERVICES_ENABLED");
    assert_script_run("srun -N ${nodes} /bin/ls");
    assert_script_run("sinfo -N -l");
    barrier_wait("HPC_MASTER_RUN_TESTS");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal;
    $self->upload_service_log('slurmd');
    $self->upload_service_log('munge');
}

1;
