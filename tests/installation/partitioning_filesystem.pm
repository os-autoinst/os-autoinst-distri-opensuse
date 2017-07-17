# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Partition setup via partition proposal menu
# Maintainer: Richard Brown <rbrownccb@opensuse.org>

use strict;
use base "y2logsstep";
use testapi;

sub run {

    my $fs = get_var('FILESYSTEM');

    # click the button
    assert_and_click 'edit-proposal-settings';

    if (get_var('PARTITIONING_WARNINGS')) {
        assert_screen 'proposal-will-overwrite-manual-changes';
        send_key 'alt-y';
    }
    # select the combo box
    assert_and_click 'default-root-filesystem';

    # select filesystem
    assert_and_click "filesystem-$fs";
    assert_screen "$fs-selected";
    assert_and_click 'ok-button';

    # make sure we're back from the popup
    assert_screen 'edit-proposal-settings';

    mouse_hide;
}

1;
# vim: set sw=4 et:
