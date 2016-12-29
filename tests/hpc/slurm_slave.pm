# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: slurm slave
#    This test is setting up a slurm slave and tests if the daemon can start
# Maintainer: soulofdestiny <mgriessmeier@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use lockapi;

sub run() {
    # set proper hostname
    assert_script_run "hostnamectl set-hostname slurm-slave";

    # setup slurm slave
    script_run "groupadd -r slurm";
    script_run "useradd -r -g slurm -d /var/run/slurm -s /bin/false -c \"SLURM Workload Manager\" slurm";

    assert_script_run 'sed -i "/^ControlMachine.*/c\ControlMachine=slurm-master" /etc/slurm/slurm.conf';
    script_run "cat /etc/slurm/slurm.conf | grep Control";

    assert_script_run 'sed -i "/^NodeName.*/c\NodeName=slurm-slave Sockets=2 CoresPerSocket=8 ThreadsPerCore=2 State=UNKNOWN" /etc/slurm/slurm.conf';
    assert_script_run 'sed -i "/^PartitionName.*/c\PartitionName=normal Nodes=slurm-slave Default=YES MaxTime=24:00:00 State=UP" /etc/slurm/slurm.conf';
    script_run "cat /etc/slurm/slurm.conf | grep NodeName";
    script_run "cat /etc/slurm/slurm.conf | grep PartitionName";

    # wait for control-node to be started
    barrier_wait('SLURMCTLD_STARTED');

    # enable and start slurmd
    assert_script_run "systemctl enable slurmd.service";
    assert_script_run "systemctl start slurmd.service";
    assert_script_run "systemctl status slurmd.service";
    barrier_wait('SLURMD_STARTED');

}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
