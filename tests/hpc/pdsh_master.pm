# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: HPC_Module: pdsh master
#    This test is setting up a pdsh scenario according to the testcase
#    described in FATE
# Maintainer: Kernel QE <kernel-qa@suse.de>
# Tags: https://fate.suse.com/321714

use Mojo::Base 'hpcbase', -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils;

sub run ($self) {
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

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook ($self) {
    $self->destroy_test_barriers();
    select_serial_terminal;
    $self->upload_service_log('mrshd');
    $self->upload_service_log('munge');
}

1;
