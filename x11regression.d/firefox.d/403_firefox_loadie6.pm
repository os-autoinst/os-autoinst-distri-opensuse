#!/usr/bin/perl -w

##################################################
# Written by:    Xudong Zhang <xdzhang@suse.com>
# Case:        1248988
##################################################

use strict;
use base "basetest";
use bmwqemu;

my $addon  = "https://addons.mozilla.org/firefox/downloads/latest/8051";
my $ie6url = "https://svn.provo.novell.com/svn/opsqa/trunk/tests/qa_test_firefox/qa_test_firefox/test_source/NOVELL%20Worldwide.mht";
my $ie7url = "https://svn.provo.novell.com/svn/opsqa/trunk/tests/qa_test_firefox/qa_test_firefox/test_source/ie7test_page.mhtml";

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

    #install a firefox addon
    send_key "ctrl-l";
    sleep 1;
    type_string $addon. "\n";
    sleep 18;                                               #download addon need a long time
    checkneedle( "firefox_addon-unmht", 8 );                #wait for the install button
    send_key "ret";
    sleep 1;                                                #install

    #open ie6 mht file
    send_key "alt-e";
    sleep 1;
    send_key "alt";
    sleep 1;
    send_key "ctrl-l";
    sleep 1;
    type_string $ie6url. "\n";
    sleep 25;                                               #the file need a long time to load
    checkneedle( "firefox_page-ie6", 20 );
    sleep 3;

    #open ie7 file (IIS)
    send_key "ctrl-l";
    sleep 1;
    type_string $ie7url. "\n";
    sleep 12;
    checkneedle( "firefox_page-ie7", 10 );

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;    # confirm "save&quit"
}

1;
# vim: set sw=4 et:
