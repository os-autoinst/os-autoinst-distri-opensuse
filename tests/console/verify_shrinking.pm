# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary: Check if AutoYaST displayed a warning about shrinking partitions
# to make them fit (bsc#1078418).
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use parent 'y2_module_consoletest';
use testapi;

sub run {
    assert_script_run("zgrep \"Some additional space\" /var/log/YaST2/y2log*.gz",
        fail_message => "There where no warnings for partition shrinking in y2log");
}

1;
