#!/usr/bin/perl -w

##################################################
# Written by:    Xudong Zhang <xdzhang@suse.com>
# Case:        1248978
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

    send_key "ctrl-k";
    sleep 1;
    send_key "ret";
    sleep 5;
    checkneedle( "firefox_page-google", 5 );                #check point 1
    send_key "ctrl-k";
    sleep 1;
    type_string "opensuse" . "\n";
    sleep 5;
    checkneedle( "firefox_search-opensuse", 5 );            #check point 2
    send_key "ctrl-k";
    sleep 1;
    send_key "f4";
    sleep 1;
    send_key "y";
    sleep 1;                                                #select the yahoo as search engine
    send_key "ret";
    sleep 5;
    checkneedle( "firefox_yahoo-search", 5 );               #check point 4

    #recover the changes, change search engine to google
    send_key "ctrl-k";
    sleep 1;
    send_key "f4";
    sleep 1;
    send_key "g";
    sleep 1;

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;    # confirm "save&quit"
}

1;

# vim: set sw=4 et:
