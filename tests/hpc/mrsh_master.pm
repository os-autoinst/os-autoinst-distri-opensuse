# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
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
use warnings;
use testapi;
use lockapi;
use utils;

sub run {
    my $self = shift;
    # Get number of nodes
    my $nodes = get_required_var("CLUSTER_NODES");

    # install mrsh
    zypper_call('in mrsh mrsh-server');
    barrier_wait("MRSH_INSTALLATION_FINISHED");

    # Copy munge key to all slave nodes
    for (my $node = 1; $node < $nodes; $node++) {
        my $node_name = sprintf("mrsh-slave%02d", $node);
        exec_and_insert_password("scp -o StrictHostKeyChecking=no /etc/munge/munge.key root\@${node_name}:/etc/munge/munge.key");
    }
    barrier_wait("MRSH_KEY_COPIED");

    # start munge
    $self->enable_and_start('munge');
    barrier_wait("MRSH_MUNGE_ENABLED");
    barrier_wait("SLAVE_MRLOGIN_STARTED");

    # make sure that nobody has permissions for $serialdev to get openQA work properly
    assert_script_run("chmod 666 /dev/$serialdev");

    select_console('root-console');
    # run mrlogin, mrcp, and mrsh (as normal and local user, e.g. nobody)
    $self->switch_user('nobody');
    for (my $node = 1; $node < $nodes; $node++) {
        my $node_name = sprintf("mrsh-slave%02d", $node);
        type_string("mrlogin ${node_name} \n");
        assert_screen("mrlogin");
        send_key('ctrl-d');
        assert_screen("mrlogout");
        assert_script_run("mrsh ${node_name}  rm -f /tmp/hello");
        assert_script_run("echo \"Hello world!\" >/tmp/hello");
        assert_script_run("mrcp /tmp/hello ${node_name}:/tmp/hello");
        assert_script_run("mrsh ${node_name}  cat /tmp/hello");
    }
    barrier_wait("MRSH_MASTER_DONE");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    $self->upload_service_log('munge');
}

1;
