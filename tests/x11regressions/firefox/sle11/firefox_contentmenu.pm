#!/usr/bin/perl -w

##################################################
# Written by:   Xudong Zhang <xdzhang@suse.com>
# Case:     1248972
##################################################

use strict;
use base "basetest";
use testapi;

sub run() {
    my $self = shift;
    mouse_hide();
    x11_start_program("firefox");
    assert_screen "start-firefox", 5;
    if ( get_var("UPGRADE") ) { send_key "alt-d"; wait_idle; }    # dont check for updated plugins
    if ( get_var("DESKTOP") =~ /xfce|lxde/i ) {
        send_key "ret";                                      # confirm default browser setting popup
        wait_idle;
    }

    send_key "shift-f10";
    sleep 1;
    check_screen "firefox_contentmenu", 5;
    send_key "down";
    sleep 1;
    send_key "down";
    sleep 1;
    check_screen "firefox_contentmenu-arrow", 5;
    send_key "i";
    sleep 2;
    check_screen "firefox_pageinfo", 5;    #the page info of opensuse.org
    sleep 2;
    send_key "alt-f4";
    sleep 1;                                 #close the page info window
    send_key "shift-f10";
    sleep 1;
    send_key "esc";
    sleep 1;                                 #show that esc key can dismiss the menu

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;                                 # confirm "save&quit"
}

1;

# vim: set sw=4 et:
