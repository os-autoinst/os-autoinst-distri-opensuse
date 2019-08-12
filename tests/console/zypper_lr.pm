# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Only do very basic zypper lr test and show repos for easy investigation
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use base "consoletest";
use strict;
use warnings;
use registration;
use testapi;
use utils 'zypper_call';

sub run {
    select_console 'root-console';
    assert_script_run "zypper lr --uri | tee /dev/$serialdev";
    # Check system version
    if (get_var('VERSION')) {
        check_registered_system(get_var('VERSION'));
    }

    if (get_var('SCC_ADDONS')) {
        my $myaddons = get_var('SCC_ADDONS');
        $myaddons =~ s/ltss,?//g;
        check_registered_addons($myaddons);
    }
}

1;
