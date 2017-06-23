# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
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

sub run() {
    my $self                      = shift;
    my $host_ip                   = get_required_var('HPC_HOST_IP');
    my ($host_ip_without_netmask) = $host_ip =~ /(.*)\/.*/;
    my $master_ip                 = get_required_var('HPC_MASTER_IP');

    select_console 'root-console';
    $self->setup_static_mm_network($host_ip);

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
    assert_script_run "systemctl enable munge.service";
    assert_script_run "systemctl start munge.service";

    # enable and start slurmd
    assert_script_run "systemctl enable slurmd.service";
    assert_script_run "systemctl start slurmd.service";
    assert_script_run "systemctl status slurmd.service";
    barrier_wait("SLURM_SLAVE_SERVICE_ENABLED");

    mutex_lock("SLURM_MASTER_RUN_TESTS");
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
