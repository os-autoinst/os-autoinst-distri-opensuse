# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Start HA support server and check network connectivity
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'hacluster';
use strict;
use testapi;
use lockapi;
use mmapi;

sub run {
    # Support server takes time to complete setup, so we need to wait (a little!) before
    diag "Waiting for support server to complete setup...";

    # Wait for the support_server to finish
    mutex_lock('support_server_ready');
    mutex_unlock('support_server_ready');

    # Now we can wait for barrier to synchronize nodes
    barrier_wait('BARRIER_HA_' . get_var('CLUSTER_NAME'));
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

sub post_fail_hook {
    my $self = shift;

    # Save a screenshot before trying further measures which might fail
    save_screenshot;

    # Try to save logs as a last resort
    $self->export_logs();
}

1;
# vim: set sw=4 et:
