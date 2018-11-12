# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: slurm master
#    This test is setting up slurm master and starts the control node
# Maintainer: soulofdestiny <mgriessmeier@suse.com>
# Tags: https://fate.suse.com/316379, https://progress.opensuse.org/issues/20308

use base "hpcbase";
use strict;
use testapi;
use lockapi;
use utils;

sub run {
    my $self = shift;
    # Get number of nodes
    my $nodes = get_required_var("CLUSTER_NODES");

    # install slurm
    zypper_call('in slurm slurm-munge');

    # Create proper /etc/hosts and /etc/slurm.conf for each node
    my $slurm_slave_nodes = "";
    for (my $node = 1; $node < $nodes; $node++) {
        my $node_name = sprintf("slurm-slave%02d", $node);
        $slurm_slave_nodes = "${slurm_slave_nodes},${node_name}";
    }
    my $config = << "EOF";
sed -i "/^ControlMachine.*/c\\ControlMachine=slurm-master" /etc/slurm/slurm.conf
sed -i "/^NodeName.*/c\\NodeName=slurm-master${slurm_slave_nodes} Sockets=1 CoresPerSocket=1 ThreadsPerCore=1 State=unknown" /etc/slurm/slurm.conf
sed -i "/^PartitionName.*/c\\PartitionName=normal Nodes=slurm-master${slurm_slave_nodes} Default=YES MaxTime=24:00:00 State=UP" /etc/slurm/slurm.conf
EOF
    assert_script_run($_) foreach (split /\n/, $config);

    barrier_wait("SLURM_SETUP_DONE");

    # Copy munge key and slurm conf to all slave nodes
    for (my $node = 1; $node < $nodes; $node++) {
        my $node_name = sprintf("slurm-slave%02d", $node);
        exec_and_insert_password("scp -o StrictHostKeyChecking=no /etc/munge/munge.key root\@${node_name}:/etc/munge/munge.key");
        exec_and_insert_password("scp -o StrictHostKeyChecking=no /etc/slurm/slurm.conf root\@${node_name}:/etc/slurm/slurm.conf");
    }
    # enable and start munge
    $self->enable_and_start('munge');

    # enable and start slurmctld
    $self->enable_and_start('slurmctld');
    systemctl 'status slurmctld';

    # enable and start slurmd since maester also acts as Node here
    $self->enable_and_start('slurmd');
    systemctl 'status slurmd';

    # wait for slave to be ready
    barrier_wait("SLURM_MASTER_SERVICE_ENABLED");
    barrier_wait("SLURM_SLAVE_SERVICE_ENABLED");

    # run the actual test against both nodes
    assert_script_run("srun -N ${nodes} /bin/ls");

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
}

1;
