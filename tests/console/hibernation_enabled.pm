# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify that "resume=" kernel parameter is present in the list of default parameters.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    assert_script_run("grep 'resume=' /proc/cmdline", fail_message => "resume parameter not found in /proc/cmdline");
}

1;
