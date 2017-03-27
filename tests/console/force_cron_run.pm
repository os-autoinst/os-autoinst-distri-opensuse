# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Avoid suprises later and run the cron jobs explicitly
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "consoletest";
use strict;
use testapi;

# check if sshd works
sub run() {
    select_console 'root-console';

    assert_script_run "bash -x /usr/lib/cron/run-crons", 1000;
    sleep 3;    # some head room for the load average to rise
    script_run "top; echo TOP-DONE-\$? > /dev/$serialdev", 0;
    # let the load settle
    assert_screen 'top-load-decreased', 1000;
    send_key 'q';
    wait_serial 'TOP-DONE';
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;
# vim: set sw=4 et:
