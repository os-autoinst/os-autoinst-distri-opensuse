# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;

use testapi;
use utils;

sub run() {
    # TODO instead of hard-overwriting this should be "memorized" and
    # corrected later in "installation/switch_to_upgrade"
    print("within setup_install_previous_and_upgrade - before: " . get_var('VERSION') . ", " . get_var('SP2ORLATER') . "\n");
    set_var('VERSION', '12-SP1');
    set_var('SP2ORLATER', 0);
    set_var('BETA', 0);
    set_var('UPGRADE', 0);
    print("within setup_install_previous_and_upgrade - after: " . get_var('VERSION') . ", " . get_var('SP2ORLATER') . "\n");
    utils::reload_all_needles;
    register_needle_tags("ENV-UPGRADE-0");
    register_needle_tags("ENV-VERSION-12-SP1");
    # TODO I think this does not work as needles tagged with ENV-SP2ORLATER-0
    # are not found
    register_needle_tags("ENV-SP2ORLATER-0");
    utils::cleanup_sle_needles;
    # TODO maybe this helps after the cleanup?
    register_needle_tags("ENV-SP2ORLATER-0");
    register_needle_tags("ENV-UPGRADE-0");
}

1;

# vim: set sw=4 et:
