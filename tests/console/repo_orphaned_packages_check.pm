# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: *-mini packages must not be delivered in the image
# Maintainer: Michal Nowak <mnowak@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';

    # Check that no *-mini RPM package is present
    assert_script_run('found="$(rpmquery -a \'*-mini\' \'*-MINI\')"; if [[ "$found" ]]; then echo -e "Found -mini package:\n" $found; false; fi');
}

1;
