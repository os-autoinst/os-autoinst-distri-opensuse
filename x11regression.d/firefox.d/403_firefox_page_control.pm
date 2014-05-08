#!/usr/bin/perl -w

##################################################
# Written by:    Xudong Zhang <xdzhang@suse.com>
# Case:        1248975
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

    my @sites = ( 'www.baidu.com', 'www.novell.com', 'www.google.com' );

    for my $site (@sites) {
        send_key "ctrl-l";
        sleep 1;
        type_string $site. "\n";
        sleep 5;
        $site =~ s{\.com}{};
        $site =~ s{.*\.}{};
        checkneedle( "firefox_page-" . $site, 5 );
    }

    send_key "alt-left";
    sleep 2;
    send_key "alt-left";
    sleep 3;
    checkneedle( "firefox_page-baidu", 5 );
    send_key "alt-right";
    sleep 3;
    checkneedle( "firefox_page-novell", 5 );
    send_key "f5";
    sleep 3;
    checkneedle( "firefox_page-novell", 5 );

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;    # confirm "save&quit"
}

1;
# vim: set sw=4 et:
