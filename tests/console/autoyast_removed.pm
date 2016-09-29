# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Confirm autoyast creation is removed from installation overviewResolves poo#11442
# G-Maintainer: mkravec <mkravec@suse.com>

use base "consoletest";
use strict;
use testapi;

# Check autoyast has been removed in SP2 (fate#317970)
sub run() {
    select_console("root-console");
    assert_script_run("[ ! -f /root/autoinst.xml ]");
}

1;
# vim: set sw=4 et:
