# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: slurm slave
#    This test is setting up a slurm slave and tests if the daemon can start
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
    my $master_ip                 = get_required_var('HPC_MASTER_IP');

    select_console 'root-console';
    $self->setup_static_network(get_required_var('HPC_HOST_IP'));

    # stop firewall, so key can be copied
    assert_script_run "rcSuSEfirewall2 stop";

    # set proper hostname
    assert_script_run "hostnamectl set-hostname slurm-slave";

    # create proper /etc/hosts
    assert_script_run("echo -e \"$host_ip_without_netmask slurm-slave\" >> /etc/hosts");
    assert_script_run("echo -e \"$master_ip slurm-master\" >> /etc/hosts");

    # install slurm
    zypper_call('in slurm-munge');

    barrier_wait("SLURM_MASTER_SERVICE_ENABLED");

    # enable and start munge
    $self->enable_and_start('munge');

    # enable and start slurmd
    $self->enable_and_start('slurmd');
    assert_script_run "systemctl status slurmd.service";
    barrier_wait("SLURM_SLAVE_SERVICE_ENABLED");

    mutex_lock("SLURM_MASTER_RUN_TESTS");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
