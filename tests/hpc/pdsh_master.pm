# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
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
use warnings;
use testapi;
use lockapi;
use utils;

sub run {
    my $self = shift;

    # Get number of nodes
    my $nodes = get_required_var("CLUSTER_NODES");

    # Install mrsh
    zypper_call('in mrsh-server munge');
    barrier_wait("PDSH_INSTALLATION_FINISHED");

    # Copy munge key to all slave nodes
    for (my $node = 1; $node < $nodes; $node++) {
        my $node_name = sprintf("pdsh-slave%02d", $node);
        exec_and_insert_password("scp -o StrictHostKeyChecking=no /etc/munge/munge.key root\@${node_name}:/etc/munge/munge.key");
    }
    barrier_wait("PDSH_KEY_COPIED");

    # Start munge
    $self->enable_and_start('munge');
    barrier_wait("PDSH_MUNGE_ENABLED");

    $self->enable_and_start('mrshd.socket');
    barrier_wait("MRSH_SOCKET_STARTED");
    barrier_wait("PDSH_SLAVE_DONE");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    $self->upload_service_log('mrshd');
    $self->upload_service_log('munge');
}

1;
