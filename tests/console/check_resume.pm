# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify that "resume=" kernel parameter is absent in the list of default parameters on Sle15-SP2
# for s390 see https://jira.suse.com/browse/SLE-6926
# Only for s390.

# Maintainer: Jonathan Rivrain <jrivrain@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    assert_script_run("grep -v 'resume=' /proc/cmdline", fail_message => "resume parameter found in /proc/cmdline");
}

1;
