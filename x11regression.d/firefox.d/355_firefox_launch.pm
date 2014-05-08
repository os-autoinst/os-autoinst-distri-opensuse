#!/usr/bin/perl -w

##################################################
# Written by:   Xudong Zhang <xdzhang@suse.com>
# Case:         1248965
# Description:  Launch firefox, click "know your right" quit and relaunch
# This case is available only when you run firefox the first time
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

    checkneedle( "firefox_know-rights", 3 );
    send_key "alt-k";
    sleep 1;                                                #click know your rights
    checkneedle( "firefox_about-rights", 3 );
    send_key "ctrl-w";
    sleep 1;

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;                                                # confirm "save&quit"
}

1;
# vim: set sw=4 et:
