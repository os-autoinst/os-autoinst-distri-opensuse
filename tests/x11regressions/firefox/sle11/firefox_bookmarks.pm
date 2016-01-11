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
# Test Case:	1248956
# Case Summary: Firefox: Test bookmarks in firefox
# Written by:	wnereiz@github
###########################################################

# Needle Tags:
# firefox-open
# test-firefox_bookmarks-open, test-firefox_bookmarks-add01, test-firefox_bookmarks-add02
# test-firefox_bookmarks-folder, test-firefox_bookmarks-new, test-firefox_bookmarks-surf
# test-firefox_bookmarks-delete
# test-firefox_bookmarks-edit01, test-firefox_bookmarks-edit02, test-firefox_bookmarks-edit03

use strict;
use base "basetest";
use testapi;

sub run() {
    my $self = shift;
    mouse_hide();

    # Launch firefox
    x11_start_program("firefox");
    assert_screen "start-firefox", 5;
    if (get_var("UPGRADE")) { send_key "alt-d"; wait_idle; }    # Don't check for updated plugins
    if (get_var("DESKTOP") =~ /xfce|lxde/i) {
        send_key "ret";                                         # Confirm default browser setting popup
        wait_idle;
    }
    send_key "alt-f10";
    sleep 1;                                                    # Maximize

    #View bookmarks
    send_key "ctrl-b";
    sleep 1;
    send_key "alt-s";
    sleep 1;                                                    #Search (To avoid using "Tab" as much as possible)
    type_string "Getting";
    sleep 3;
    send_key "tab";
    send_key "down";                                            #Focus on the "Getting Start" bookmark
    send_key "ret";
    sleep 10;                                                   #Open the bookmark
    check_screen "test-firefox_bookmarks-open", 5;
    send_key "ctrl-b";
    sleep 2;                                                    #Close bookmarks sidebar

    #Add bookmarks
    send_key "f6";
    type_string "www.google.com\n";
    sleep 3;
    send_key "ctrl-d";
    sleep 1;                                                    #Add bookmark
    check_screen "test-firefox_bookmarks-add01", 5;
    send_key "ret";
    send_key "ctrl-b";
    sleep 1;                                                    #Open sidebar
    send_key "tab";
    send_key "down";
    send_key "ret";
    sleep 2;                                                    #Unfold Bookmarks Menu
    check_screen "test-firefox_bookmarks-add02", 5;
    send_key "ctrl-b";
    sleep 2;                                                    #Close bookmarks sidebar

    #New Folder
    send_key "ctrl-b";
    sleep 1;                                                    #Open sidebar
    send_key "tab";
    send_key "right";                                           #Unfold Bookmarks Toolbar
    send_key "down";
    send_key "up";
    sleep 1;                                                    #Make focus
    send_key "menu";
    sleep 1;                                                    #Right click menu
    send_key "f";
    sleep 1;                                                    #New Folder
    send_key "alt-n";
    sleep 1;
    send_key "ctrl-a";
    type_string "suse-test\n";
    sleep 1;                                                    #Input folder name
    check_screen "test-firefox_bookmarks-folder", 5;

    #New bookmarks
    send_key "menu";
    sleep 1;                                                    #Right click menu
    send_key "b";
    sleep 1;                                                    # New Bookmark
    send_key "alt-n";
    send_key "ctrl-a";                                          #Name
    type_string "Free Software Foundation";
    send_key "alt-l";                                           #Location
    type_string "http://www.fsf.org/\n";
    sleep 1;                                                    #Add
    send_key "right";
    sleep 1;                                                    #Unfolder
    check_screen "test-firefox_bookmarks-new", 5;

    #Surf bookmarks
    send_key "down";                                            #Focus on new created bookmark
    send_key "ret";
    sleep 5;
    check_screen "test-firefox_bookmarks-surf", 5;

    #Delete bookmarks
    send_key "alt-s";                                           #Search field
    type_string "Free\n";
    sleep 1;
    send_key "tab";
    send_key "down";                                            #Focus on the bookmark to be deleted
    send_key "menu";
    sleep 1;
    send_key "d";
    sleep 1;                                                    #Delete
    send_key "alt-s";
    send_key "delete";
    sleep 1;                                                    #Cancel searched
    check_screen "test-firefox_bookmarks-delete", 5;

    #Edit bookmark proerties
    send_key "ctrl-shift-o";
    sleep 2;
    check_screen "test-firefox_bookmarks-edit01", 5;
    send_key "down";
    send_key "ret";                                             #Bookmarks Menu
    foreach (1 .. 5) { send_key "down"; }                       #Move to Google bookmark we created at the beginning
    sleep 2;
    send_key "alt-n";                                           #Name
    type_string "Google Maps";
    sleep 1;
    send_key "alt-l";                                           #Location
    type_string "https://maps.google.com";
    sleep 1;
    send_key "alt-f4";
    sleep 1;                                                    #Close bookmarks window
    check_screen "test-firefox_bookmarks-edit02", 5;
    sleep 1;
    send_key "alt-s";
    type_string "Maps";
    sleep 1;
    send_key "tab";
    send_key "down";
    sleep 1;                                                    #Focus on "Google Maps" bookmark
    send_key "ret";
    sleep 5;                                                    #Load the bookmark
    check_screen "test-firefox_bookmarks-edit03", 5;
    sleep 1;

    # Restore and close firefox
    x11_start_program("killall -9 firefox");                    # Exit firefox
    x11_start_program("rm -rf .mozilla");                       # Clear profile directory
    sleep 2;
}

1;
# vim: set sw=4 et:
