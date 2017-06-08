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

sub run() {
    # Notify others that installation finished
    barrier_wait "WORKERS_INSTALLED";
    # Wait until controller node finishes
    barrier_wait "CNTRL_FINISHED";
}

sub post_run_hook {
    # Workers installed using autoyast have no password - bsc#1030876
    return if get_var('AUTOYAST');

    script_run "journalctl > journal.log", 90;
    upload_logs "journal.log";
}

1;
# vim: set sw=4 et:
