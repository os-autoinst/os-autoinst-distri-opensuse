# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary:  Check if all users has some value in the password field
# (bsc#973639, bsc#974220, bsc#971804 and bsc#965852)
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use parent 'y2_module_consoletest';
use testapi;

sub run {
    assert_script_run("! getent shadow | grep -E \"^[^:]+::\"",
        fail_message => "Not all users have defined passwords");
}

1;
