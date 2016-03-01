# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1479153 Firefox: Smoke Test

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-gnome', 45);

    # Links navigation
    send_key "/";
    sleep 1;
    type_string "blogs\n";
    sleep 1;
    assert_screen('firefox-links_nav-suse_blogs', 50);

    # Topsites
    my @topsite = ('www.gnu.org', 'www.opensuse.org');
    for my $site (@topsite) {
        send_key "esc";
        send_key "alt-d";
        sleep 1;
        type_string $site. "\n";
        assert_screen('firefox-topsite_' . $site, 65);
    }

    # Help
    send_key "alt-h";
    sleep 1;
    send_key "a";
    assert_screen('firefox-help', 5);
    send_key "esc";

    # Exit
    send_key "alt-f4";
    if (check_screen('firefox-save-and-quit', 4)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
