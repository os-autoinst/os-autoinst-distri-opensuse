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
# Test Case:	1248955
# Case Summary: Firefox - Autofill
# Written by:	wnereiz@github
###########################################################

# Needle Tags:
# firefox-open
# test-firefox_autocomplete-1
# firefox_autocomplete-testpage, firefox_autocomplete-testpage_filled

use strict;
use base "x11regressiontest";
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

    # Open testing webpage for autocomplete
    send_key "f6";
    type_string "debugtheweb.com/test/passwordautocomplete.asp\n";
    sleep 4;
    check_screen "firefox_autocomplete-testpage", 5;

    send_key "tab";
    send_key "tab";
    sleep 1;                                                    # Focus to Username input field
    type_string "suse-test";
    send_key "tab";
    sleep 1;                                                    # Password field
    type_string "testpassword";
    send_key "tab";                                             # "Standard Submit" button
    send_key "ret";
    sleep 3;

    check_screen "fierfox_autocomplete-1", 5;

    send_key "alt-r";
    send_key "alt-r";
    send_key "ret";                                             #Remember Password
    sleep 5;
    send_key "alt-f4";
    sleep 1;                                                    #Close browser
    send_key "ret";
    sleep 2;                                                    # confirm "save&quit"

    #Launch firefox again
    x11_start_program("firefox");
    sleep 5;
    send_key "f6";
    type_string "debugtheweb.com/test/passwordautocomplete.asp\n";
    sleep 4;
    check_screen "firefox_autocomplete-testpage_filled", 5;

    # Restore and close firefox
    x11_start_program("killall -9 firefox");                    # Exit firefox
    x11_start_program("rm -rf .mozilla");                       # Clear profile directory
    sleep 2;
}

1;
# vim: set sw=4 et:
