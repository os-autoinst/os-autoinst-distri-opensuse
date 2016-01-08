# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


###########################################################
# Test Case:	1248946
# Case Summary: Firefox: Open common URL's in Firefox
# Written by:	wnereiz@github
###########################################################

# Needle Tags:
# firefox-open
# test-firefox_url-novell-1, test-firefox_url-novell-2
# test-firefox_url-wikipedia-1, test-firefox_url-wikipedia-2
# test-firefox_url-googlemaps-1, test-firefox_url-googlemaps-2

use strict;
use base "basetest";
use testapi;

sub run() {
    my $self = shift;
    mouse_hide();
    x11_start_program("firefox");
    assert_screen "start-firefox", 5;
    if (get_var("UPGRADE")) { send_key "alt-d"; wait_idle; }    # Don't check for updated plugins
    if (get_var("DESKTOP") =~ /xfce|lxde/i) {
        send_key "ret";                                         # Confirm default browser setting popup
        wait_idle;
    }
    send_key "alt-f10";                                         # Maximize

    # Open the following URL's in firefox and navigate a few links on each site.

    # http://www.novell.com
    send_key "alt-d";
    sleep 1;
    type_string "https://www.novell.com\n";
    sleep 25;
    check_screen "test-firefox_url-novell-1", 5;

    # Switch to communities and enter the link
    send_key "apostrophe";
    sleep 1;    #open quick find (links only)
    type_string "communities\n";
    sleep 10;
    check_screen "test-firefox_url-novell-2", 5;

    # http://www.wikipedia.org
    send_key "alt-d";
    sleep 1;
    type_string "www.wikipedia.org\n";
    sleep 10;
    check_screen "test-firefox_url-wikipedia-1", 5;

    # Switch to "Deutsch", enter the link
    send_key "tab";
    send_key "tab";    #remove the focus from input box
    send_key "apostrophe";
    sleep 2;           #open quick find (links only)
    type_string "Deutsch\n";
    sleep 7;
    check_screen "test-firefox_url-wikipedia-2", 5;

    # http://maps.google.com
    send_key "alt-d";
    sleep 1;
    type_string "maps.google.com\n";
    sleep 15;
    send_key "tab";    #remove the focus from input box
    check_screen "test-firefox_url-googlemaps-1", 5;
    sleep 2;

    # Switch to "SIGN IN", enter the link
    send_key "apostrophe";
    sleep 2;           #open quick find (links only)
    type_string "sign in\n";
    sleep 7;
    check_screen "test-firefox_url-googlemaps-2", 5;

    # Restore and close firefox
    send_key "alt-f4";
    sleep 1;                                 # Exit firefox
    send_key "ret";                          # Confirm "save&quit"
    x11_start_program("rm -rf .mozilla");    # Clear profile directory
    sleep 2;

}

1;
# vim: set sw=4 et:
