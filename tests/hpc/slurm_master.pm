# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: slurm master
#    This test is setting up slurm master and starts the control node
# Maintainer: soulofdestiny <mgriessmeier@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use lockapi;

sub run() {
    # set proper hostname
    assert_script_run "hostnamectl set-hostname slurm-master";

    # setup slurm master
    script_run "groupadd -r slurm";
    script_run "useradd -r -g slurm -d /var/run/slurm -s /bin/false -c \"SLURM Workload Manager\" slurm";
    assert_script_run 'sed -i "/^ControlMachine.*/c\ControlMachine=slurm-master" /etc/slurm/slurm.conf';
    script_run "cat /etc/slurm/slurm.conf | grep Control";

    # enable and start slurmctld
    assert_script_run "systemctl enable slurmctld.service";
    assert_script_run "systemctl start slurmctld.service";
    assert_script_run "systemctl status slurmctld.service";
    barrier_wait('SLURMCTLD_STARTED');
    barrier_wait('SLURMD_STARTED');
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
