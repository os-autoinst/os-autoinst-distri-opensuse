# Case#1479153 Firefox: Smoke Test

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm");
    type_string "killall -9 firefox;rm -rf .moz*;firefox &>/dev/null &\n";
    sleep 1;
    send_key "ctrl-d";
    assert_screen('firefox-gnome',45);

    # Links navigation
    send_key "/";
    type_string "blogs\n";
    assert_screen('firefox-links_nav-suse_blogs',30);

    # Topsites
    my @topsite = ( 'www.gnu.org', 'www.opensuse.org', 'www.twitter.com' );
    for my $site (@topsite) {
        send_key "esc";
        send_key "alt-d";
        sleep 1;
        type_string $site. "\n";
        assert_screen('firefox-topsite_' . $site, 20);
    }

    # Help
    send_key "alt-h";
    sleep 1;
    send_key "a";
    assert_screen('firefox-help',5);
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
