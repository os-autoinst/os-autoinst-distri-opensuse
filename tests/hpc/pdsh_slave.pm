# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: pdsh slave
#    This test is setting up a pdsh scenario according to the testcase
#    described in FATE
# Maintainer: soulofdestiny <mgriessmeier@suse.com>
# Tags: https://fate.suse.com/321714

use base "hpcbase";
use strict;
use testapi;
use lockapi;
use utils;

sub run() {
    my $self      = shift;
    my $host_ip   = get_required_var('HPC_HOST_IP');
    my $master_ip = get_required_var('HPC_MASTER_IP');

    select_console 'root-console';
    $self->setup_static_mm_network($host_ip);

    # stop firewall, so key can be copied
    assert_script_run "rcSuSEfirewall2 stop";

    # set proper hostname
    assert_script_run "hostnamectl set-hostname pdsh-slave";

    # install mrsh
    zypper_call('in munge pdsh');
    barrier_wait("PDSH_INSTALLATION_FINISHED");
    mutex_lock("PDSH_KEY_COPIED");

    # start munge
    assert_script_run('systemctl enable munge.service');
    assert_script_run('systemctl start munge.service');
    barrier_wait("PDSH_MUNGE_ENABLED");
    mutex_lock("MRSH_SOCKET_STARTED");

    # make sure that nobody has permissions for $serialdev to get openQA work properly
    assert_script_run("chmod 666 /dev/$serialdev");

    type_string("su - nobody\n");
    assert_screen 'user-nobody';

    assert_script_run("pdsh -R mrsh -w $master_ip ls");
    barrier_wait("PDSH_SLAVE_DONE");
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
