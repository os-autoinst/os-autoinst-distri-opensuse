#!/usr/bin/perl -w

##################################################
# Written by:    Xudong Zhang <xdzhang@suse.com>
# Case:        1248994
##################################################

use strict;
use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;
    mouse_hide();
    x11_start_program("firefox");
    assert_screen  "start-firefox", 5 ;
    if ( $envs->{UPGRADE} ) { send_key "alt-d"; waitidle; }    # dont check for updated plugins
    if ( $envs->{DESKTOP} =~ /xfce|lxde/i ) {
        send_key "ret";                                      # confirm default browser setting popup
        waitidle;
    }

    send_key "ctrl-l";
    sleep 1;
    type_string "https://pdb.suse.de" . "\n";
    sleep 5;                                                #open this site
    check_screen  "firefox_https-risk", 3 ;                 #will get untrusted page
    send_key "ctrl-l";
    sleep 1;
    type_string "https://svn.provo.novell.com/svn/opsqa/trunk/tests/qa_test_firefox/qa_test_firefox/test_source/pdb.suse.de" . "\n";
    sleep 5;
    check_screen  "firefox_page-pdbsuse", 5 ;
    send_key "ctrl-s";
    sleep 2;
    check_screen  "firefox_saveas", 5 ;
    send_key "ctrl-a";
    sleep 1;
    send_key "backspace";
    sleep 1;
    type_string "/home/" . $username . "/pdb.suse.de" . "\n";
    sleep 1;

    send_key "alt-e";
    sleep 1;
    send_key "n";
    sleep 1;
    send_key "left";
    sleep 1;    #switch to "Advanced" tab
    send_key "tab";
    sleep 1;            #switch to "General" submenu
    for ( 1 .. 4 ) {    #4 times right  switch to "Encryption"
        send_key "right";
        sleep 1;
    }
    send_key "alt-s";
    sleep 1;            #open the "Certificate Manager"
    send_key "shift-tab";
    sleep 1;            #select the default "Authorities"
    send_key "left";
    sleep 1;
    send_key "alt-m";
    sleep 1;            #Certificate File to Import
    send_key "slash";
    sleep 1;
    send_key "ret";
    sleep 1;
    type_string "/home/" . $username . "/pdb.suse.de" . "\n";
    sleep 1;

    #recover all the changes done to "Preference"
    send_key "shift-tab";
    sleep 1;            #switch to tab "Server"
    send_key "shift-tab";
    sleep 1;
    send_key "right";
    sleep 1;            #switch to tab "Authorities" default
    send_key "alt-f4";
    sleep 1;
    send_key "shift-tab";
    sleep 1;            #switch to tab "Certificates"
    send_key "shift-tab";
    sleep 1;

    for ( 1 .. 4 ) {    #4 times left to switch to "General" sub-menu
        send_key "left";
        sleep 1;
    }
    send_key "shift-tab";
    sleep 1;            #switch to the "Advanced" tab of Preference
    send_key "right";
    sleep 1;            #switch to the "General" tab of Preference

    send_key "alt-f4";
    sleep 1;
    send_key "ctrl-l";
    sleep 1;
    type_string "https://pdb.suse.de" . "\n";
    sleep 5;            #open this site again
    check_screen  "firefox_https-pdbsuse", 3 ;    #will get untrusted page

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;                                      # confirm "save&quit"
}

1;

# vim: set sw=4 et:
