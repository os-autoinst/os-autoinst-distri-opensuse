# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Initialize mutexes and barriers for multi-machine synchronization.
#
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use base qw(opensusebasetest);
use testapi;
use lockapi;
use mmapi;

sub run {
    my @nodes_list = split(/,/, get_required_var('NODES_LIST'));
    my $barriers_number = @nodes_list + 1;    # master should be added

    die 'Barriers initialization should be done only on master node!'
      unless get_var('HOSTNAME', '') =~ /master/;

    # Create all needed barrier
    barrier_create('BARRIER_K8S_VALIDATION', $barriers_number);
    barrier_create('NETWORK_SETUP_DONE', $barriers_number);
    barrier_create('NETWORK_CHECK_DONE', $barriers_number);
    barrier_create('FILES_READY', $barriers_number);
    barrier_create('TEST_FRAMEWORK_DONE', $barriers_number);

    # Create a final mutex to signal all jobs that barriers are ready to use
    # Must be used with mutex_wait() before any barrier_wait() calls in the jobs
    # Taken from ha/barriers_init
    # Create also a 'wait_nodes' mutex to sync the shutdown of all servers
    mutex_create($_) foreach ('barriers_ready', 'wait_nodes');


    # Wait for all children to start
    # Children are server/test suites that use the PARALLEL_WITH variable
    wait_for_children_to_start();
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;
