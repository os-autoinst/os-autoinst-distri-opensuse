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
    # Notify others that installation finished
    if (get_var 'DELAYED_WORKER') {
        mutex_create "DELAYED_WORKER_INSTALLED";
    }
    else {
        barrier_wait "WORKERS_INSTALLED";
    }

    # Wait until controller node finishes
    mutex_lock "CNTRL_FINISHED";
    mutex_unlock "CNTRL_FINISHED";
}

sub post_run_hook {
    # Cluster was rebooted during stack tests
    reset_consoles;
    select_console 'root-console';

    export_cluster_logs;
}

1;
