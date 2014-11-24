#!/usr/bin/perl -w

##################################################
# Written by:    Xudong Zhang <xdzhang@suse.com>
# Case:        1248971
# Description:    open new window and open link in new window
##################################################

use strict;
use base "basetest";
use testapi;

sub run() {
    my $self = shift;
    mouse_hide();
    x11_start_program("firefox");
    assert_screen "start-firefox", 5;
    if ( $vars{UPGRADE} ) { send_key "alt-d"; wait_idle; }    # dont check for updated plugins
    if ( $vars{DESKTOP} =~ /xfce|lxde/i ) {
        send_key "ret";                                      # confirm default browser setting popup
        wait_idle;
    }

    send_key "ctrl-n";
    sleep 5;
    check_screen "start-firefox", 5;
    send_key "ctrl-w";
    sleep 1;

    send_key "shift-tab";
    sleep 1;
    send_key "shift-ret";
    sleep 6;
    check_screen "firefox_page-opensuse-sponsors", 5;
    send_key "ctrl-w";
    sleep 1;

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;    # confirm "save&quit"
}

1;

# vim: set sw=4 et:
