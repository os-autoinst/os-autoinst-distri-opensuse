# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC master
#    This test is aiming at comprehensive HPC testing. That means
#    that most components of the HPC product should be installed and
#    configured. At the same time it is expected that the HPC cluster
#    set-up is fairly complex, so that NFS shares are mounted, required
#    database(s) are ready to be used, some data is being populated to
#    the databases, artificial users are added etc.
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
    # and all the set-up is done, including external services, like NFS etc.
    record_info('Start installing all components');
    zypper_call('in slurm slurm-munge ganglia-gmetad ganglia-gmond ganglia-gmetad-skip-bcheck');
    zypper_call('in nfs-client rpcbind');
    record_info('Installation done');

    record_info('System set-up: prepare needed configuration');
    $self->mount_nfs();
    $self->prepare_slurm_conf();
    record_info('slurmctl conf', script_output('cat /etc/slurm/slurm.conf'));
    barrier_wait("HPC_SETUPS_DONE");

    record_info('System set-up: enable & start services');
    $self->distribute_munge_key();
    $self->distribute_slurm_conf();
    $self->enable_and_start("munge");
    systemctl("is-active munge");
    $self->enable_and_start("slurmctld");
    systemctl("is-active slurmctld");
    $self->enable_and_start("slurmd");
    systemctl("is-active slurmd");
    $self->enable_and_start("gmetad");
    systemctl("is-active gmetad");
    record_info('System set-up: finished');

    # wait for slave nodes to be ready
    barrier_wait("HPC_MASTER_SERVICES_ENABLED");
    $self->enable_and_start("gmond");
    systemctl("is-active gmond");
    barrier_wait("HPC_SLAVE_SERVICES_ENABLED");

    ## Check if all nodes are pingable
    $self->check_nodes_availability();

    # run basic test against first compute node
    assert_script_run('sinfo -N -l');
    assert_script_run('sinfo  -o \"%P %.10G %N\"');

    ## TODO: Add multi-compontent tests, i.e. mpirun jobs scheduled with slurm
    # and scheduled by various users AND check if they are recorded well in the db

    barrier_wait('HPC_MASTER_RUN_TESTS');
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
