# Feature tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: [316585] Drop suseRegister
# Maintainer: Ben Chou <bchou@suse.com>
# Tags: tc#1480023

use base "consoletest";
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';

    #Check SUSEConnect is installed
    assert_script_run('rpm -q SUSEConnect');
    save_screenshot;

    #Check suseRegister is not installed
    assert_script_run('! rpm -q suseRegister');
    save_screenshot;
}

1;
