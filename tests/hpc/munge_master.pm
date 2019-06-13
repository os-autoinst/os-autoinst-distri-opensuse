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

    # Install munge and wait for slave
    zypper_call('in munge');
    barrier_wait('MUNGE_INSTALLATION_FINISHED');

    # Copy munge key to all nodes
    $self->distribute_munge_key();
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

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    $self->upload_service_log('munge');
}

1;

