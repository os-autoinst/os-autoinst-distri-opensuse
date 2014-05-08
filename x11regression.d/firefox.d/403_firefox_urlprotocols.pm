#!/usr/bin/perl -w

##################################################
# Written by:    Xudong Zhang <xdzhang@suse.com>
# Case:        1248989
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

    send_key "ctrl-l";
    sleep 1;
    sendautotype "http://www.baidu.com\n";
    sleep 3;
    checkneedle( "firefox_page-baidu", 3 );
    send_key "ctrl-l";
    sleep 1;
    sendautotype "https://en.mail.qq.com\n";
    sleep 3;
    checkneedle( "firefox_page-qqmail", 3 );
    send_key "ctrl-l";
    sleep 1;
    sendautotype "ftp://download.nvidia.com/novell\n";
    sleep 3;
    checkneedle( "firefox_page-ftpnvidia", 3 );

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;    # confirm "save&quit"
}

1;
# vim: set sw=4 et:
