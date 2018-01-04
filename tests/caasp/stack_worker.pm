# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Start worker nodes
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use lockapi;
use caasp;

sub run {
    # Make sure the installation has finished
    if (check_var('FLAVOR', 'CaaSP-DVD-Incidents')) {
        assert_screen('linux-login-casp', 1200);
    }

    # Notify others that installation finished
    barrier_wait "WORKERS_INSTALLED";

    # Wait until controller node finishes
    mutex_lock "CNTRL_FINISHED";
    mutex_unlock "CNTRL_FINISHED";
}

sub post_run_hook {
    # Password is set later on autoyast nodes
    if (get_var 'AUTOYAST') {
        select_console('root-console');
    }
    # Cluster node was rebooted
    elsif (update_scheduled) {
        reset_consoles;
        select_console 'root-console';
    }
    export_cluster_logs;
}

1;
# vim: set sw=4 et:
