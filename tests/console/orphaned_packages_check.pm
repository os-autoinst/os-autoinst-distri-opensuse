# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check and output orphaned packages
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#19606

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    select_console 'root-console';

    #No orphaned packages list to compare currently, so we simply output the result
    zypper_call('packages --orphaned', log => 'orphaned.log');
    save_screenshot;
}

sub test_flags {
    return {fatal => 1};
}

1;
