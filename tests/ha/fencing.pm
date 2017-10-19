# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Execute fence command on one of the cluster nodes
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use testapi;
use lockapi;
use hacluster;

sub run {
    barrier_wait("BEFORE_FENCING_$cluster_name");
    if (is_node(2)) {
        # Fence the node
        assert_script_run 'crm -F node fence ' . get_var('HA_CLUSTER_JOIN');

        # Wait a little to be sure that fence command is on his way
        sleep 60;
    }
    else {
        reset_consoles;
    }

    # Do a check of the cluster with a screenshot
    save_state;
}

1;
# vim: set sw=4 et:
