#!/usr/bin/perl -w

##################################################
# Written by:    Xudong Zhang <xdzhang@suse.com>
# Case:        1248969 and 1248966
# Description:    test some top websites and then check the history
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

    #clear recent history otherwise calendar will login automatically
    send_key "ctrl-shift-h";
    sleep 2;
    checkneedle( "firefox_history", 3 );                    #open the "history"
    send_key "ctrl-a";
    sleep 1;                                                #select all
    send_key "delete";
    sleep 1;                                                #delete all
    checkneedle( "firefox_history-empty", 3 );              #confirm all history removed
    send_key "alt-f4";
    sleep 12;

    my @topsite = ( 'www.yahoo.com', 'www.amazon.com', 'www.ebay.com', 'slashdot.org', 'www.wikipedia.org', 'www.flickr.com', 'www.facebook.com', 'www.youtube.com', 'ftp://ftp.novell.com' );

    for my $site (@topsite) {
        send_key "ctrl-l";
        sleep 1;
        sendautotype $site. "\n";
        sleep 8;
        $site =~ s{\.(com|org|net)$}{};
        $site =~ s{.*\.}{};
        checkneedle( "firefox_page-" . $site, 7 );
    }

    #visit sf.net, check it will redirect to sourceforge.net
    send_key "ctrl-l";
    sleep 1;
    sendautotype "www.sf.net\n";
    sleep 5;
    checkneedle( "firefox_page-sourceforge", 5 );
    send_key "ctrl-shift-h";
    sleep 2;    #open "show all history"
    checkneedle( "firefox_history-sourceforge", 3 );
    send_key "shift-f10";
    sleep 1;    #send right click on the item
    send_key "d";
    sleep 1;    #delete the selected item
    checkneedle( "firefox_history-ftpnovell", 3 );    #confirm the sf hitory was deleted
    send_key "ret";
    sleep 3;                                          #open an item in history
    checkneedle( "firefox_page-ftpnovell", 5 );

    send_key "alt-f4";
    sleep 2;                                          #two alt-f4 to close firefox and history
    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;                                          # confirm "save&quit"
}

1;
# vim: set sw=4 et:
