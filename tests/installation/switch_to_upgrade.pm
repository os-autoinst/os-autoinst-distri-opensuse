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
    # TODO see tests/installation/setup_install_previous_and_upgrade.pm:
    # Instead of hardcoding it should be set to the previous value before the
    # installation of previous OS version
    set_var('VERSION', '12-SP2');
    set_var('UPGRADE', 1);
    set_var('SP2ORLATER', '1');
    set_var('BETA', '1');
    utils::reload_all_needles;
    unregister_needle_tags("ENV-VERSION-12-SP1");
    unregister_needle_tags("ENV-SP2ORLATER-0");
    register_needle_tags("ENV-VERSION-12-SP2");
    register_needle_tags("ENV-SP2ORLATER-1");
    utils::cleanup_sle_needles;
}

1;

# vim: set sw=4 et:
