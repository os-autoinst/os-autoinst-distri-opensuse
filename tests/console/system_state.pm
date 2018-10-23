# SUSE's openQA tests
#
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary:  Export the existing status of running tasks and system load
# for future reference
# Maintainer: Zaoliang Luo <zluo@suse.de>

use base "consoletest";
use testapi;
use utils;
use ipmi_backend_utils 'use_ssh_serial_console';
use strict;

sub run {
    check_var("BACKEND", "ipmi") ? use_ssh_serial_console : select_console 'root-console';
    script_run "ps axf > /tmp/psaxf.log";
    script_run "cat /proc/loadavg > /tmp/loadavg_consoletest_setup.txt";
}

1;
