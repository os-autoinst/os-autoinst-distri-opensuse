#!/usr/bin/perl -w

##################################################
# Written by:    Xudong Zhang <xdzhang@suse.com>
# Case:        1248977
##################################################

use strict;
use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;
    mouse_hide();
    x11_start_program("firefox");
    waitforneedle( "start-firefox", 5 );
    if ( $ENV{UPGRADE} ) { send_key "alt-d"; waitidle; }    # dont check for updated plugins
    if ( $ENV{DESKTOP} =~ /xfce|lxde/i ) {
        send_key "ret";                                      # confirm default browser setting popup
        waitidle;
    }

    send_key "alt-e";
    sleep 1;
    send_key "n";
    sleep 1;
    send_key "alt-p";
    sleep 1;
    sendautotype "www.google.com";
    sleep 2;
    checkneedle( "firefox_pref-general-homepage", 5 );
    send_key "ret";
    sleep 1;
    send_key "alt-home";
    sleep 5;
    checkneedle( "firefox_page-google", 5 );

    #exit and relaunch the browser
    send_key "alt-f4";
    sleep 2;
    x11_start_program("firefox");
    checkneedle( "firefox_page-google", 5 );

    #recover all the changes, home page
    send_key "alt-e";
    sleep 1;
    send_key "n";
    sleep 1;
    send_key "alt-r";
    sleep 1;    #choose "Restore to Default"
    send_key "esc";
    sleep 1;

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;    # confirm "save&quit"
}

1;
# vim: set sw=4 et:
