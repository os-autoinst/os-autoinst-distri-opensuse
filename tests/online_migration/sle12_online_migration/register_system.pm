# SLE12 online migration tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Add sle12 online migration testsuite
#    Fixes follow up by the comments
#
#    Apply fully patch system function
#
#    Fix typo and remove redundant comment
#
#    Remove a unnecessary line
# G-Maintainer: mitiao <mitiao@gmail.com>

use base "consoletest";
use strict;
use testapi;
use registration;
use utils;

sub run() {
    my $self = shift;
    select_console 'root-console';

    # SCC_URL was placed to medium types
    # so set SMT_URL here if register system via smt server
    # otherwise must register system via real SCC before online migration
    if (my $u = get_var('SMT_URL')) {
        type_string "echo 'url: $u' > /etc/SUSEConnect\n";
    }

    # register system and addons in textmode for all archs
    if (!is_desktop_installed()) {
        yast_scc_registration;
    }
    else {
        set_var("DESKTOP", 'textmode');
        yast_scc_registration;
        # set back to gnome mode for checking
        # if system boot into desktop correctly after migration
        set_var("DESKTOP", 'gnome');
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
