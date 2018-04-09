# SUSE's openQA tests
#
# Copyright (c) 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check cluster status *after* fencing
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use testapi;
use lockapi;
use hacluster;

sub run {
    my $cluster_name = get_cluster_name;

    # Check cluster state *after* fencing
    barrier_wait("CHECK_AFTER_FENCING_BEGIN_$cluster_name");

    # We need to be sure to be root and, after fencing, the default console on node01 is not root
    select_console 'root-console' if is_node(1);

    # Wait for the cluster to be up on the fenced node
    # We can execute this test on all nodes, so do it as it's easier to code :-)
    assert_script_run 'crm cluster wait_for_startup';

    # And check for the state of the whole cluster
    check_cluster_state;

    barrier_wait("CHECK_AFTER_FENCING_END_$cluster_name");
}

1;
