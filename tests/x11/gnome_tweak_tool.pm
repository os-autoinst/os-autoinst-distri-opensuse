# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: GNOME Tweak Tool
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use strict;
use testapi;

sub run {
    my @gnome_tweak_matches = qw(gnome-tweaks gnome-tweak-tool command-not-found);

    mouse_hide(1);
    x11_start_program('gnome-tweaks', target_match => \@gnome_tweak_matches);
    if (match_has_tag('command-not-cound')) {
        # GNOME Tweak tools was renamed to GNOME tweaks during 3.28 dev branch
        # AS the new name yielded a 'command-not-found', starts as old command
        x11_start_program('gnome-tweak-tools');
    }
    assert_and_click "gnome-tweak-tool-fonts";
    assert_screen "gnome-tweak-tool-fonts-dialog";
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
