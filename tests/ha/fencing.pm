# SUSE's openQA tests
#
# Copyright (c) 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Execute fence command on one of the cluster nodes
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster;

sub run {
    my $cluster_name = get_cluster_name;

    # Check cluster state *before* fencing
    barrier_wait("CHECK_BEFORE_FENCING_BEGIN_$cluster_name");
    check_cluster_state;
    barrier_wait("CHECK_BEFORE_FENCING_END_$cluster_name");

    # Fence the master node
    assert_script_run 'crm -F node fence ' . get_node_to_join if is_node(2);
}

1;
