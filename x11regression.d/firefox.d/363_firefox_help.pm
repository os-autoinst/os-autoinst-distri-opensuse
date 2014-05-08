#!/usr/bin/perl -w

##################################################
# Written by:    Xudong Zhang <xdzhang@suse.com>
# Case:        1248964
# Description:    Test firefox help
##################################################

use strict;
use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;
    mouse_hide();
    x11_start_program("firefox");
    assert_screen  "start-firefox", 5 ;
    if ( $ENV{UPGRADE} ) { send_key "alt-d"; waitidle; }    # dont check for updated plugins
    if ( $ENV{DESKTOP} =~ /xfce|lxde/i ) {
        send_key "ret";                                      # confirm default browser setting popup
        waitidle;
    }

    send_key "alt-h";
    sleep 1;
    send_key "h";
    sleep 6;
    checkneedle( "firefox_help-help", 8 );
    send_key "ctrl-w";
    sleep 1;                                                #close the firefox help tab
    send_key "alt-h";
    sleep 1;
    send_key "t";
    sleep 1;
    checkneedle( "firefox_help-trouble", 3 );
    send_key "ctrl-w";
    sleep 1;                                                #close the firefox troubleshooting tab
    send_key "alt-h";
    sleep 1;
    send_key "s";
    sleep 6;
    checkneedle( "firefox_help-feedback", 8 );
    send_key "ctrl-w";
    sleep 1;                                                #close the firefox submit feedback tab

    #test firefox--report web forgery
    send_key "alt-h";
    sleep 1;
    send_key "f";
    sleep 6;
    checkneedle( "firefox_help-forgery", 5 );               #need to close tab cause if open in current tab

    #test firefox--about firefox
    send_key "alt-h";
    sleep 1;
    send_key "a";
    sleep 1;
    checkneedle( "firefox_help-about", 5 );
    send_key "alt-f4";
    sleep 1;                                                #close the firefox about dialog

    #test firefox help--restart with addons disable
    send_key "alt-h";
    sleep 1;
    send_key "r";
    sleep 2;
    checkneedle( "firefox_restart-addons-disable", 5 );
    send_key "ret";
    sleep 3;
    checkneedle( "firefox_safemode", 3 );
    send_key "ret";
    sleep 4;
    checkneedle( "firefox_help-forgery", 5 );    #will open last closed website
    send_key "ctrl-shift-a";
    sleep 3;
    send_key "tab";
    sleep 1;
    send_key "tab";
    sleep 1;                                     #switch to extension column of add-ons
    send_key "down";
    sleep 1;
    checkneedle( "firefox_addons-safemode", 5 );

    #recover all changes--switch addons page to default column
    send_key "up";
    sleep 1;
    send_key "ctrl-w";
    sleep 1;                                     #close the firefox addons tab

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;                                     # confirm "save&quit"
}

1;

# vim: set sw=4 et:
