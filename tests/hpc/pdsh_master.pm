# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: pdsh master
#    This test is setting up a pdsh scenario according to the testcase
#    described in FATE
# Maintainer: soulofdestiny <mgriessmeier@suse.com>
# Tags: https://fate.suse.com/321714


use base "hpcbase";
use strict;
use testapi;
use lockapi;
use utils;

sub run {
    my $self     = shift;
    my $slave_ip = get_required_var('HPC_SLAVE_IP');
    barrier_create("PDSH_INSTALLATION_FINISHED", 2);
    barrier_create("PDSH_MUNGE_ENABLED",         2);
    barrier_create("PDSH_SLAVE_DONE",            2);

    select_console 'root-console';
    $self->setup_static_network(get_required_var('HPC_HOST_IP'));

    # set proper hostname
    assert_script_run "hostnamectl set-hostname pdsh-master";

    # stop firewall
    assert_script_run "rcSuSEfirewall2 stop";

    # install mrsh
    zypper_call('in mrsh-server munge');
    barrier_wait("PDSH_INSTALLATION_FINISHED");

    # copy key
    $self->exec_and_insert_password("scp -o StrictHostKeyChecking=no /etc/munge/munge.key root\@$slave_ip:/etc/munge/munge.key");
    mutex_create("PDSH_KEY_COPIED");

    # start munge
    $self->enable_and_start('munge');
    barrier_wait("PDSH_MUNGE_ENABLED");

    $self->enable_and_start('mrshd.socket');
    mutex_create("MRSH_SOCKET_STARTED");
    barrier_wait("PDSH_SLAVE_DONE");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
