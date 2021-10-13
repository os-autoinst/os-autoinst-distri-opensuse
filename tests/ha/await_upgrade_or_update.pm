# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Wait for all nodes which are allowed to upgrade or update before.
# Maintainer: Julien Adamek <jadamek@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use hacluster;
use lockapi;

sub run {
    my $cluster_name = get_cluster_name;
    my @word = (get_required_var('UPDATE_TYPE') eq "update") ? ("Update", "updating", "UPDATED") : ("Upgrade", "upgrading", "UPGRADED");
    record_info("$word[0] node 1", "$word[0] has started for node 1") if is_node(1);

    if (is_node(2)) {
        record_info("Waiting node 1", "Node 1 is $word[1]");
        barrier_wait("NODE_$word[2]_${cluster_name}_NODE1");
        record_info("$word[0] node 2", "$word[0] has started for node 2");
    }
}

1;
