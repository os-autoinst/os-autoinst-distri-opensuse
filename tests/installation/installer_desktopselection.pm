# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "y2logsstep";
use testapi;

sub run() {
    assert_screen "desktop-selection";
    my $d = get_var('DESKTOP_MINIMALX_INSTONLY') ? "minimalx" : get_var('DESKTOP');
    if ($d ne "kde" && $d ne "gnome") {
        assert_and_click "select_desktop_other";    # open other desktop selection - followed by the real desktop selection
    }
    assert_and_click "select_desktop_$d";
    assert_screen "$d-selected";
    send_key $cmd{next};
}

1;
# vim: set sw=4 et:
