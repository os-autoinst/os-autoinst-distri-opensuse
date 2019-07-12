# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Slurm accounting - database
#    This test is setting up slurm ctl node with accounting configured
#    (database)
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

    # provision HPC cluster, so the proper rpms are installed,
    # munge key is distributed to all nodes, so is slurm.conf
    # and proper services are enabled and started
    zypper_call('in slurm slurm-munge');

    zypper_call('in nfs-client rpcbind');
    systemctl 'start nfs';
    systemctl 'start rpcbind';
    record_info('show mounts aviable on the supportserver', script_output('showmount -e 10.0.2.1'));
    assert_script_run("mkdir -p /shared/slurm");
    assert_script_run("chown -Rcv slurm:slurm /shared/slurm");
    assert_script_run("mount -t nfs -o nfsvers=3 10.0.2.1:/nfs/shared /shared/slurm");

    $self->prepare_slurm_conf();
    record_info('slurmctl conf', script_output('cat /etc/slurm/slurm.conf'));
    barrier_wait("SLURM_SETUP_DONE");
    $self->distribute_munge_key();
    $self->distribute_slurm_conf();
    $self->enable_and_start('munge');
    $self->enable_and_start('slurmctld');
    systemctl 'status slurmctld';
    $self->enable_and_start('slurmd');
    systemctl 'status slurmd';

    # wait for slave to be ready
    barrier_wait("SLURM_MASTER_SERVICE_ENABLED");
    barrier_wait("SLURM_SLAVE_SERVICE_ENABLED");

    # run basic test against first compute node
    # add sleep; bugzilla#1140403
    sleep(5);
    assert_script_run("srun -w slave-node00 date");

    barrier_wait('SLURM_MASTER_RUN_TESTS');
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
    $self->upload_service_log('slurmdbd');
    upload_logs('/var/log/slurmctld.log');
}

1;
