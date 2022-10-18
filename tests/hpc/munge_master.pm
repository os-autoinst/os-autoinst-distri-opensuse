# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Installation of munge package from HPC module and sanity check
# of this package
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'hpcbase', -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils;

sub run ($self) {
    # Get number of nodes
    my $nodes = get_required_var("CLUSTER_NODES");

    # Install munge and wait for slave
    zypper_call('in munge');
    barrier_wait('MUNGE_INSTALLATION_FINISHED');

    # Copy munge key to all slave nodes
    for (my $node = 1; $node < $nodes; $node++) {
        my $node_name = sprintf("munge-slave%02d", $node);
        exec_and_insert_password("scp -o StrictHostKeyChecking=no /etc/munge/munge.key root\@${node_name}:/etc/munge/munge.key");
    }
    barrier_wait('MUNGE_KEY_COPIED');

    # Enable and start service
    $self->enable_and_start('munge');
    barrier_wait("MUNGE_SERVICE_ENABLED");

    # Test if munge works fine
    assert_script_run('munge -n');
    assert_script_run('munge -n | unmunge');
    for (my $node = 1; $node < $nodes; $node++) {
        my $node_name = sprintf("munge-slave%02d", $node);
        exec_and_insert_password("munge -n | ssh ${node_name} unmunge");
    }
    assert_script_run('remunge');
    barrier_wait('MUNGE_DONE');
}

sub post_fail_hook ($self) {
    $self->destroy_test_barriers();
    select_serial_terminal;
    $self->upload_service_log('munge');
}

1;

