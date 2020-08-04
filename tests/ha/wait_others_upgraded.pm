# SUSE's openQA tests
#
# Copyright (c) 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Wait for all nodes which are allowed to upgrade after.
# Maintainer: Christian Lanig <clanig@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use hacluster;
use lockapi;

sub run {
    my $cluster_name = get_cluster_name;
    if (is_node(1)) {
        record_info("Upgrade done", "Node 1 successfully upgraded");
        barrier_wait("NODE_UPGRADED_${cluster_name}_NODE1");
        record_info("Waiting node 2", "Node 2 is upgrading");
    }
    for (1 .. get_node_number) {
        barrier_wait("NODE_UPGRADED_${cluster_name}_NODE$_");
    }
}

1;
