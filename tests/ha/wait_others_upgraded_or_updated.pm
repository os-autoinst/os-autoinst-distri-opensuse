# SUSE's openQA tests
#
# Copyright (c) 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Wait for all nodes which are allowed to upgrade or update after.
# Maintainer: Julien Adamek <jadamek@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use hacluster;
use lockapi;

sub run {
    my $cluster_name = get_cluster_name;
    my @word         = (get_required_var('UPDATE_TYPE') eq "update") ? ("Update", "updating", "UPDATED") : ("Upgrade", "upgrading", "UPGRADED");
    if (is_node(1)) {
        record_info("$word[0] done", "Node 1 successfully $word[2]");
        barrier_wait("NODE_$word[2]_${cluster_name}_NODE1");
        record_info("Waiting node 2", "Node 2 is $word[1]");
    }
    for (1 .. get_node_number) {
        barrier_wait("NODE_$word[2]_${cluster_name}_NODE$_");
    }
}

1;
