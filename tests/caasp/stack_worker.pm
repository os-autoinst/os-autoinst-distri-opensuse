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
use lockapi 'barrier_wait';
use autotest 'query_isotovideo';
use caasp;

sub run {
    # Notify others that installation finished
    if (get_var 'DELAYED') {
        barrier_wait 'DELAYED_NODES_ONLINE';
    }
    else {
        barrier_wait "NODES_ONLINE";
    }
    pause_until 'CNTRL_FINISHED';
}

sub post_run_hook {
    # Some nodes were removed & powered off during test run
    return if query_isotovideo('backend_is_shutdown');

    # Wait until password is set from admin node
    pause_until('AUTOYAST_PW_SET') if get_var('AUTOYAST');

    # Redraw login screen
    send_key 'ret';

    # Node could be rebooted during stack tests
    if (check_screen 'linux-login-casp', 7) {
        reset_consoles;
        select_console 'root-console';
    }
    export_cluster_logs;
}

1;
