# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation of munge package from HPC module and sanity check
# of this package
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>, soulofdestiny <mgriessmeier@suse.com>

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
    barrier_create("MUNGE_INSTALLATION_FINISHED", $nodes);
    barrier_create("MUNGE_SERVICE_ENABLED",       $nodes);
    # Synchronize all slave nodes with master
    mutex_create("MUNGE_MASTER_BARRIERS_CONFIGURED");

    # Install munge and wait for slave
    zypper_call('in munge');
    barrier_wait('MUNGE_INSTALLATION_FINISHED');

    # Copy munge key to all slave nodes
    for (my $node = 1; $node < $nodes; $node++) {
        my $node_name = sprintf("munge-slave%02d", $node);
        $self->exec_and_insert_password("scp -o StrictHostKeyChecking=no /etc/munge/munge.key root\@${node_name}:/etc/munge/munge.key");
    }
    mutex_create('MUNGE_KEY_COPIED');

    # Enable and start service
    $self->enable_and_start('munge');
    barrier_wait("MUNGE_SERVICE_ENABLED");

    # Test if munge works fine
    assert_script_run('munge -n');
    assert_script_run('munge -n | unmunge');
    for (my $node = 1; $node < $nodes; $node++) {
        my $node_name = sprintf("munge-slave%02d", $node);
        $self->exec_and_insert_password("munge -n | ssh ${node_name} unmunge");
    }
    assert_script_run('remunge');
    mutex_create('MUNGE_DONE');
}

sub post_fail_hook {
    my ($self) = @_;
    $self->upload_service_log('munge');
}

1;

