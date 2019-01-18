# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Confirm autoyast has been removed from installation overview
# Maintainer: mkravec <mkravec@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;

# poo#11442
sub run {
    select_console("root-console");
    assert_script_run("[ ! -f /root/autoinst.xml ]");
}

1;
