# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: slurm master
#    This test is setting up slurm master and starts the control node
# Maintainer: soulofdestiny <mgriessmeier@suse.com>
# Tags: https://fate.suse.com/316379

use base "hpcbase";
use strict;
use testapi;
use lockapi;
use utils;

sub run {
    my $self                      = shift;
    my ($host_ip_without_netmask) = get_required_var('HPC_HOST_IP') =~ /(.*)\/.*/;
    my $slave_ip                  = get_required_var('HPC_SLAVE_IP');
    barrier_create("SLURM_MASTER_SERVICE_ENABLED", 2);
    barrier_create("SLURM_SLAVE_SERVICE_ENABLED",  2);

    select_console 'root-console';
    $self->setup_static_network(get_required_var('HPC_HOST_IP'));

    # stop firewall
    assert_script_run "rcSuSEfirewall2 stop";

    # set proper hostname
    assert_script_run "hostnamectl set-hostname slurm-master";

    # install slurm
    zypper_call('in slurm-munge');

    # create proper /etc/hosts and /etc/slurm.conf
    my $config = << "EOF";
echo -e "$host_ip_without_netmask slurm-master" >> /etc/hosts
echo -e "$slave_ip slurm-slave" >> /etc/hosts
sed -i "/^ControlMachine.*/c\\ControlMachine=slurm-master" /etc/slurm/slurm.conf
sed -i "/^NodeName.*/c\\NodeName=slurm-master,slurm-slave Sockets=1 CoresPerSocket=1 ThreadsPerCore=1 State=unknown" /etc/slurm/slurm.conf
sed -i "/^PartitionName.*/c\\PartitionName=normal Nodes=slurm-master,slurm-slave Default=YES MaxTime=24:00:00 State=UP" /etc/slurm/slurm.conf
EOF
    assert_script_run($_) foreach (split /\n/, $config);

    # copy munge key and slurm conf
    $self->exec_and_insert_password("scp -o StrictHostKeyChecking=no /etc/munge/munge.key root\@$slave_ip:/etc/munge/munge.key");
    $self->exec_and_insert_password("scp -o StrictHostKeyChecking=no /etc/slurm/slurm.conf root\@$slave_ip:/etc/slurm/slurm.conf");

    # enable and start munge
    $self->enable_and_start('munge');

    # enable and start slurmctld
    $self->enable_and_start('slurmctld');
    assert_script_run "systemctl status slurmctld.service";

    # enable and start slurmd since maester also acts as Node here
    $self->enable_and_start('slurmd');
    assert_script_run "systemctl status slurmd.service";

    # wait for slave to be ready
    barrier_wait("SLURM_MASTER_SERVICE_ENABLED");
    barrier_wait("SLURM_SLAVE_SERVICE_ENABLED");

    # run the actual test against both nodes
    assert_script_run("srun -N 2 /bin/ls");

    mutex_create('SLURM_MASTER_RUN_TESTS');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
