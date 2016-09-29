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
# Test Case:	1248952
# Case Summary: Firefox: Test send link in firefox
# Written by:	wnereiz@github
###########################################################

# Needle Tags:
# firefox-open
# test-firefox_sendlink-1, test-firefox_sendlink-2, test-firefox_sendlink-3
# test-firefox_sendlink-unstable_warning

# G-Summary: Restore SLE11 cases to sub-directory, remove main.pm lines because no openSUSE cases.
# G-Maintainer: wnereiz <wnereiz@gmail.com>

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

    # Open www.google.com
    send_key "alt-d";
    sleep 1;
    type_string "www.google.com\n";
    sleep 8;
    check_screen "test-firefox_sendlink-1", 5;
    sleep 2;

    # Open "Email link" to launch default email client (evolution)
    send_key "alt-f";
    sleep 1;
    send_key "e";
    sleep 3;

    #Close the window if there is a unstable warning for this version
    if (check_screen "test-firefox_sendlink-unstable_warning", 5) {
        sleep 1;
        send_key "alt-o";
        sleep 1;    #Close warning window
    }

    #Evolution Account Assistant
    assert_screen "test-firefox_sendlink-2", 15;
    sleep 1;
    send_key "alt-o";
    sleep 1;

    #Restore from Backup
    send_key "alt-o";
    sleep 1;

    #Identity
    send_key "alt-a";    #Set Email Address
    type_string "novell\@novell.com";
    send_key "alt-o";
    sleep 2;
    send_key "alt-s";
    sleep 5;             #Skip Lookup

    #Receiving Email
    send_key "alt-s";    #Set Server
    type_string "imap.novell.com";
    sleep 1;
    send_key "alt-n";    #Set Username
    type_string "novell-test";
    sleep 1;
    send_key "alt-o";
    sleep 1;

    #Receiving Options
    send_key "alt-o";
    sleep 1;             #Sending Email
    send_key "alt-s";    # Set Server
    type_string "smtp.novell.com";
    sleep 1;
    send_key "alt-o";
    sleep 1;

    #Account Summary
    send_key "alt-o";
    sleep 1;

    #Done
    send_key "alt-a";
    sleep 15;            #Applied

    #Cancel Mail authentication request dialog
    send_key "esc";
    sleep 3;

    check_screen "test-firefox_sendlink-3", 5;
    sleep 2;

    # Restore and close firefox
    x11_start_program("killall -9 firefox");          # Exit firefox profile directory
    x11_start_program("killall -9 evolution");        # Exit evolution
    x11_start_program("rm -rf .mozilla");             # Clear profile directory
    x11_start_program("rm -rf .config/evolution");    # Clear evolution profile directory
    sleep 2;

}

1;
# vim: set sw=4 et:
