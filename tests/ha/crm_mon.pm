# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check cluster status in crm_mon
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use testapi;
use lockapi;
use hacluster;

sub run {
    # Synchronize nodes
    barrier_wait("MON_INIT_$cluster_name");

    # Show cluster informations
    assert_script_run "$crm_mon_cmd";
    assert_script_run 'crm_mon -1 | grep \'partition with quorum\'';
    assert_script_run 'crm_mon -s | grep "$(crm node list | wc -l) nodes online"';

    # Synchronize nodes
    barrier_wait("MON_CHECKED_$cluster_name");
}

1;
# vim: set sw=4 et:
