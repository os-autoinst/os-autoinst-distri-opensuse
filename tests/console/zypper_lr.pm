# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Only do very basic zypper lr test and show repos for easy investigation
# - Prints output of zypper lr --uri to serial console.
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use base "consoletest";
use strict;
use warnings;
use registration;
use version_utils;
use testapi;
use utils 'zypper_call';

sub run {
    select_console 'root-console';
    assert_script_run "zypper lr --uri | tee /dev/$serialdev";
    # Check system version and regiestered addons
    if (get_var('SCC_ADDONS') and is_sle('<=15-sp1') and is_sle('12+') and is_upgrade()) {
        check_registered_system(get_var('VERSION'));
        my $myaddons = get_var('SCC_ADDONS');
        $myaddons =~ s/ltss,?//g;
        check_registered_addons($myaddons);
    }
}

1;
