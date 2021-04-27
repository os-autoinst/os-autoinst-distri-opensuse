# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: gnome-tweaks gnome-tweak-tool
# Summary: GNOME Tweak Tool
# - Launch gnome-tweaks and check
# - In case of fail, try gnome-tweak-tool
# - Open fonts dialog
# - Close gnome tweak tool
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    my @gnome_tweak_matches = qw(gnome-tweaks gnome-tweak-tool command-not-found gnome-tweak-extensions-moved);

    mouse_hide(1);
    x11_start_program('gnome-tweaks', target_match => \@gnome_tweak_matches);
    if (match_has_tag('command-not-found')) {
        # GNOME Tweak tool was renamed to GNOME Tweaks during 3.28 dev branch
        # As the new name yielded a 'command-not-found', start as old command
        send_key 'esc';
        x11_start_program('gnome-tweak-tool');
    }
    if (match_has_tag('gnome-tweak-extensions-moved')) {
        # GNOME 40 moved extensions out of tweak tool, pops a warning
        assert_and_click('gnome-tweak-extensions-moved');
    }
    assert_and_click "gnome-tweak-tool-fonts";
    assert_screen "gnome-tweak-tool-fonts-dialog";
    send_key "alt-f4";
}

1;
