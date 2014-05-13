#!/usr/bin/perl -w

###########################################################
# Test Case:	1248950
# Case Summary: Firefox: Test firefox tabbed brower windows
# Written by:	wnereiz@github
###########################################################

# Needle Tags:
# firefox-open
# firefox_pre-general
# test-firefox_tab-1, test-firefox_tab-2, test-firefox_tab-3
# test-firefox_tab-4, test-firefox_tab-5

# NOTE: Some actions in this case can not be implemented.
# For example, click and drag. So they are not included.

use strict;
use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;
    mouse_hide();

    # Launch firefox
    x11_start_program("firefox");
    assert_screen  "start-firefox", 5 ;
    if ( $vars{UPGRADE} ) { send_key "alt-d"; wait_idle; }    # Don't check for updated plugins
    if ( $vars{DESKTOP} =~ /xfce|lxde/i ) {
        send_key "ret";                                      # Confirm default browser setting popup
        wait_idle;
    }
    send_key "alt-f10";
    sleep 1;                                                # Maximize

    # Opening a new Tabbed Browser.
    send_key "alt-f";
    sleep 1;
    send_key "ret";
    sleep 1;                                                # Open a new tab by menu
    send_key "ctrl-t";                                       # Open a new tab by hotkey
    sleep 2;
    check_screen  "test-firefox_tab-1", 5 ;
    sleep 2;
    send_key "ctrl-w";
    send_key "ctrl-w";                                       # Restore to one tab (Home Page)

    # Confirm that the various menu items pertaining to the Tabbed Browser exist
    # Confirm the page title and url.
    send_key "apostrophe";
    sleep 1;
    type_string "news";
    send_key "esc";
    sleep 1;    # Find News link
    send_key "menu";
    sleep 1;    # Use keyboard to simulate right click the link
    send_key "down";
    send_key "ret";    # "Open link in the New Tab"
    sleep 6;
    send_key "alt-2";
    sleep 5;          # Switch to the new opened tab
    check_screen  "test-firefox_tab-2", 5 ;
    send_key "ctrl-w";
    sleep 1;          # Restore to one tab (Home Page)

    # Test secure sites
    send_key "ctrl-t";
    sleep 1;
    send_key "alt-d";
    sleep 1;
    type_string "http://mozilla.org/\n";
    sleep 10;         # A non-secure site (http)
    check_screen  "test-firefox_tab-3", 5 ;

    send_key "ctrl-t";
    sleep 1;
    send_key "alt-d";
    sleep 1;
    type_string "https://digitalid.verisign.com/\n";
    sleep 10;         # A secure site (https)
    check_screen  "test-firefox_tab-4", 5 ;

    send_key "ctrl-w";
    send_key "ctrl-w";    # Restore to one tab (Home Page)

    # Confirm default settings
    send_key "alt-e";
    sleep 1;
    send_key "n";
    sleep 1;             # Open Preferences
    check_screen  "firefox_pre-general", 5 ;
    sleep 5;
    send_key "right";
    sleep 2;             # Switch to the "Tabs" tab
    check_screen  "test-firefox_tab-5", 5 ;
    sleep 2;

    send_key "left";
    sleep 1;
    send_key "esc";
    sleep 1;             # Restore

    # Restore and close firefox
    send_key "alt-f4";
    sleep 1;                                 # Exit firefox
    send_key "ret";                           # Confirm "save&quit"
    x11_start_program("rm -rf .mozilla");    # Clear profile directory
    sleep 2;

}

1;
# vim: set sw=4 et:
