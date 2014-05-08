#!/usr/bin/perl -w

###########################################################
# Test Case:	1248953
# Case Summary: Firefox - Java plugin
# Written by:	wnereiz@github
###########################################################

# Needle Tags:
# firefox-open
# test-firefox_java-1, test-firefox_java-2, test-firefox_java-3
# test-firefox_java-java_warning

use strict;
use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;
    mouse_hide();

    # Launch firefox
    x11_start_program("firefox");
    waitforneedle( "start-firefox", 5 );
    if ( $ENV{UPGRADE} ) { send_key "alt-d"; waitidle; }    # Don't check for updated plugins
    if ( $ENV{DESKTOP} =~ /xfce|lxde/i ) {
        send_key "ret";                                      # Confirm default browser setting popup
        waitidle;
    }
    send_key "alt-f10";
    sleep 1;                                                # Maximize

    # Open Add-ons Manager
    send_key "ctrl-shift-a";
    sleep 2;

    # Open "Email link" to launch default email client (evolution)
    send_key "ctrl-f";
    sleep 1;                                                #"Search all add-ons"
    type_string "icedTea\n";
    sleep 2;

    #Switch to "My Add-ons"
    foreach ( 1 .. 5 ) {
        send_key "tab";
    }
    send_key "left";
    sleep 2;

    waitforneedle( "test-firefox_java-1", 5 );

    #Focus to "Always Activate"
    send_key "tab";
    send_key "down";
    send_key "tab";
    send_key "tab";
    send_key "down";    #Switch to "Never Active"
    sleep 2;

    #Test java plugin on website javatester.org
    send_key "ctrl-t";
    sleep 1;
    type_string "javatester.org/version.html\n";
    sleep 5;
    checkneedle( "test-firefox_java-2", 5 );

    #Close tab, return to Add-ons Manager
    send_key "ctrl-w";
    sleep 2;
    send_key "down";
    sleep 1;    #Switch back to "Always Activate"

    #Test java plugin again
    send_key "ctrl-t";
    sleep 2;
    type_string "javatester.org/version.html\n";
    sleep 4;
    checkneedle( "test-firefox_java-java_warning", 5 );    #Java - unsigned application warning
    send_key "tab";                                         #Proceed
    send_key "ret";
    sleep 3;
    checkneedle( "test-firefox_java-3", 5 );

    # Restore and close firefox
    x11_start_program("killall -9 firefox");               # Exit firefox
    x11_start_program("rm -rf .mozilla");                  # Clear profile directory
    sleep 2;

}

1;
# vim: set sw=4 et:
