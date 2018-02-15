# SUSE's openQA tests
#
# Copyright (c) 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Wait for support server to start
# Maintainer: Loic Devulder <ldevulder@suse.com> , Anton Smorodskyi <asmorodskyi@suse.com>

use base 'opensusebasetest';
use strict;
use testapi;
use lockapi;

sub run {
    # Support server takes time to complete setup, so we need to wait (a little!) before
    diag "Waiting for support server to complete setup...";

    # Wait for the support_server to finish
    mutex_lock('support_server_ready');
    mutex_unlock('support_server_ready');

    # Now we can wait for barrier to synchronise nodes
    barrier_wait('BARRIER_HA_' . get_var('CLUSTER_NAME')) if get_var("HA_CLUSTER");
}

1;
# vim: set sw=4 et:
