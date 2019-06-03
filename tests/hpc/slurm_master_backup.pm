# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: slurm cluster initialization
# Maintainer: Sebastian Chlad <sebastian.chlad@suse.com>

use base "hpcbase";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;

sub run {
    my $self  = shift;
    my $nodes = get_required_var("CLUSTER_NODES");

    $self->prepare_user_and_group();
    zypper_call('in nfs-client rpcbind');

    systemctl 'start nfs';
    systemctl 'start rpcbind';

    assert_script_run("showmount -e 10.0.2.1");

    assert_script_run("mkdir -p /shared/slurm");
    assert_script_run("chown -Rcv slurm:slurm /shared/slurm");
    assert_script_run("mount -t nfs -o nfsvers=3 10.0.2.1:/nfs/shared /shared/slurm");

    zypper_call('in slurm slurm-munge');

    barrier_wait("SLURM_SETUP_DONE");
    barrier_wait("SLURM_MASTER_SERVICE_ENABLED");

    # enable and start munge
    $self->enable_and_start('munge');

    # enable and start slurmctld
    $self->enable_and_start('slurmctld');
    systemctl 'status slurmctld';

    # enable and start slurmd since maester also acts as Node here
    $self->enable_and_start('slurmd');
    systemctl 'status slurmd';

    assert_script_run("srun -N ${nodes} /bin/ls");
    assert_script_run("sinfo -N -l");
    assert_script_run("scontrol ping");

    barrier_wait("SLURM_SLAVE_SERVICE_ENABLED");
    barrier_wait("SLURM_MASTER_RUN_TESTS");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    $self->upload_service_log('slurmd');
    $self->upload_service_log('munge');
    $self->upload_service_log('slurmctld');
}

1;
