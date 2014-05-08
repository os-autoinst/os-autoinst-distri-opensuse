#!/usr/bin/perl -w

##################################################
# Written by:   Xudong Zhang <xdzhang@suse.com>
# Case:     1248944
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
    sleep 2;
    checkneedle( "firefox_menu-edit", 3 );
    send_key "alt-v";
    sleep 2;
    checkneedle( "firefox_menu-view", 3 );
    for ( 1 .. 2 ) {                                        #select the "Character Encoding" menu
        send_key "up";
        sleep 1;
    }
    for ( 1 .. 2 ) {                                        #select "Auto-Detect" then "Chinese"
        send_key "right";
        sleep 1;
    }
    checkneedle( "firefox_menu-submenu", 3 );
    for ( 1 .. 3 ) {                                        #dismiss all opened menus one by one
        send_key "esc";
        sleep 1;
    }
    waitforneedle( "start-firefox", 3 );

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;                                                # confirm "save&quit"
}

1;
# vim: set sw=4 et:
