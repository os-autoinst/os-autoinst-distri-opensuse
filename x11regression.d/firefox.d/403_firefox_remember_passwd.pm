#!/usr/bin/perl -w

##################################################
# Written by:    Xudong Zhang <xdzhang@suse.com>
# Case:        1248981
#Description:    Firefox Sidebar
#
#1.Click View from Firefox menu and click Sidebar.
#2.Select Bookmarks from Sidebar submenu.
#3.Click any bookmark
#4.Select History from Sidebar submenu.
#5.Click any history
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

    my $master_passwd = "123456";
    my $test_site     = "calendar.google.com";
    my $gmailuser     = "nooops6";
    my $gmailpasswd   = "opensuse";

    send_key "alt-e";
    sleep 1;
    send_key "n";
    sleep 1;
    for ( 1 .. 3 ) {    #select the "Security" tab of Preference
        send_key "left";
        sleep 1;
    }
    send_key "alt-u";
    sleep 1;            #choose "Use a master password"
    sendautotype $master_passwd;
    sleep 1;
    send_key "tab";
    sleep 1;            #re-enter password
    sendautotype $master_passwd. "\n";
    sleep 1;
    send_key "ret";
    sleep 1;            #"Password Change Succeeded" diag
    send_key "esc";
    sleep 1;

    send_key "ctrl-l";
    sleep 1;
    sendautotype $test_site. "\n";
    sleep 5;
    checkneedle( "firefox_page-calendar", 5 );
    sendautotype $gmailuser;
    sleep 1;
    send_key "tab";
    sleep 1;
    sendautotype $gmailpasswd. "\n";
    sleep 5;
    checkneedle( "firefox_remember-password", 5 );
    send_key "alt-r";
    sleep 1;    #remember password
    send_key "r";
    sleep 1;
    sendautotype $master_passwd. "\n";
    sleep 1;
    send_key "alt-e";
    sleep 1;
    send_key "n";
    sleep 1;
    send_key "alt-p";
    sleep 1;    #open the "Saved Passwords" diag
    checkneedle( "firefox_saved-passowrds", 5 );    #check if the passwd is saved
    send_key "alt-c";
    sleep 1;                                        #close the dialog
    send_key "esc";
    sleep 1;
    send_key "alt-f4";
    sleep 2;                                        #quit firefox and then re-launch
    send_key "ret";
    sleep 2;                                        # confirm "save&quit"

    #re-open firefox and login the calendar
    x11_start_program("firefox");

    #clear recent history otherwise calendar will login automatically
    send_key "ctrl-shift-delete";
    sleep 1;
    send_key "shift-tab";
    sleep 1;                                        #select clear now
    send_key "ret";
    sleep 1;

    #login calendar.google.com again to check the password
    send_key "ctrl-l";
    sleep 2;
    sendautotype $test_site. "\n";
    sleep 5;
    checkneedle( "firefox_passwd-required", 5 );
    sendautotype $master_passwd. "\n";
    sleep 1;
    checkneedle( "firefox_page-calendar-passwd", 3 );

    #recover all the changes
    send_key "alt-e";
    sleep 1;
    send_key "n";
    sleep 1;
    send_key "alt-p";
    sleep 1;    #open the "Saved Passwords" diag
    send_key "alt-a";
    sleep 1;    #remove all the saved passwords
    send_key "y";
    sleep 1;    #confirm the removing
    send_key "alt-c";
    sleep 1;    #close the "Saved..." dialog
    send_key "alt-u";
    sleep 2;    #disable the master password
    sendautotype $master_passwd. "\n";
    sleep 1;
    send_key "ret";
    sleep 1;    #answer to the popup window
    send_key "esc";
    sleep 1;    #close the Preference
    send_key "alt-e";
    sleep 1;
    send_key "n";
    sleep 1;

    for ( 1 .. 3 ) {    #switch the tab from "Security" to "General"
        send_key "right";
        sleep 1;
    }
    send_key "esc";
    sleep 1;

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;            # confirm "save&quit"
}

1;
# vim: set sw=4 et:
