# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: yast2_software_management.pm checks some basic functions like
# "search, pattern, installation summary"
# Make sure it can opened properly and it's basic functions work correctly.
# Maintainer: Zaoliang Luo <zluo@suse.com>

use base "y2x11test";
use strict;
use testapi;

sub run {
    my $self   = shift;
    my $module = "sw_single";

    $self->launch_yast2_module_x11($module);
    assert_screen "yast2-$module-ui", 120;

    # search packages and check package list and technical data
    type_string "ftp";
    assert_and_click "yast2-$module-search";
    assert_screen "yast2-$module-show-packages";
    assert_and_click "yast2-$module-technical-data";
    assert_screen "yast2-$module-td-details";

    # open View, select and show pattern content
    assert_and_click "yast2-$module-view";
    assert_screen "yast2-$module-groups";
    assert_and_click "yast2-$module-pattern";
    assert_screen "yast2-$module-show-pattern";

    # check Installation Summary
    assert_and_click "yast2-$module-summary";
    assert_screen "yast2-$module-show-summary";

    # Exit
    send_key "alt-a";
}

1;
# vim: set sw=4 et:
