# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: mrsh master
#    This test is setting up a mrsh scenario according to the testcase
#    described in FATE
# Maintainer: soulofdestiny <mgriessmeier@suse.com>
# Tags: https://fate.suse.com/321722


use base "hpcbase";
use strict;
use testapi;
use lockapi;
use utils;

sub run() {
    my $self     = shift;
    my $host_ip  = get_required_var('HPC_HOST_IP');
    my $slave_ip = get_required_var('HPC_SLAVE_IP');
    barrier_create("MRSH_INSTALLATION_FINISHED", 2);
    barrier_create("MRSH_MUNGE_ENABLED",         2);
    barrier_create("SLAVE_MRLOGIN_STARTED",      2);
    barrier_create("MRSH_MASTER_DONE",           2);

    select_console 'root-console';
    $self->setup_static_mm_network($host_ip);

    # set proper hostname
    assert_script_run "hostnamectl set-hostname mrsh-master";

    # stop firewall
    assert_script_run "rcSuSEfirewall2 stop";

    # install mrsh
    zypper_call('in mrsh mrsh-server');
    barrier_wait("MRSH_INSTALLATION_FINISHED");

    # copy key
    $self->exec_and_insert_password("scp -o StrictHostKeyChecking=no /etc/munge/munge.key root\@$slave_ip:/etc/munge/munge.key");
    mutex_create("MRSH_KEY_COPIED");

    # start munge
    assert_script_run('systemctl enable munge.service');
    assert_script_run('systemctl start munge.service');
    barrier_wait("MRSH_MUNGE_ENABLED");
    barrier_wait("SLAVE_MRLOGIN_STARTED");

    # make sure that nobody has permissions for $serialdev to get openQA work properly
    assert_script_run("chmod 666 /dev/$serialdev");

    # run mrlogin, mrcp, and mrsh (as normal and local user, e.g. nobody)
    type_string("su - nobody\n");
    assert_screen("user-nobody");
    type_string("mrlogin $slave_ip\n");
    assert_screen("mrlogin");
    send_key('ctrl-d');
    assert_screen("mrlogout");
    assert_script_run("mrsh $slave_ip rm -f /tmp/hello");
    assert_script_run("echo \"Hello world!\" >/tmp/hello");
    assert_script_run("mrcp /tmp/hello $slave_ip:/tmp/hello");
    assert_script_run("mrsh $slave_ip cat /tmp/hello");

    barrier_wait("MRSH_MASTER_DONE");
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
