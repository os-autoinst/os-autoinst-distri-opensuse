#!/usr/bin/perl -w

##################################################
# Written by:    Xudong Zhang <xdzhang@suse.com>
# Case:        1248984
##################################################

use strict;
use base "basetest";
use testapi;

sub run() {
    my $self = shift;
    mouse_hide();
    x11_start_program("firefox");
    assert_screen "start-firefox", 5;
    if (get_var("UPGRADE")) { send_key "alt-d"; wait_idle; }    # dont check for updated plugins
    if (get_var("DESKTOP") =~ /xfce|lxde/i) {
        send_key "ret";                                         # confirm default browser setting popup
        wait_idle;
    }

    send_key "ctrl-l";
    sleep 2;

    #login mail.google.com
    type_string "mail.google.com\n";
    sleep 4;
    check_screen "firefox_page-gmail1", 5;
    type_string "nooops6";
    sleep 1;
    send_key "tab";
    sleep 1;
    type_string "opensuse\n";
    sleep 6;
    check_screen "firefox_page-gmail2", 5;
    send_key "alt-r";
    sleep 1;    #remember password
    send_key "r";
    sleep 1;

    #clear recent history otherwise gmail will login automatically
    send_key "ctrl-shift-delete";
    sleep 2;
    send_key "shift-tab";
    sleep 1;    #select clear now
    send_key "ret";
    sleep 1;

    #login mail.google.com again to check the password
    send_key "ctrl-l";
    sleep 2;
    type_string "mail.google.com\n";
    sleep 5;
    check_screen "firefox_page-gmail3", 5;

    #recover all the changes
    #    send_key "alt-e"; sleep 1;
    #    send_key "n"; sleep 1;
    #    for(1..3) {            #select the "Security" tab of Preference
    #        send_key "left"; sleep 1;
    #    }
    #    send_key "alt-p"; sleep 1;
    #    send_key "alt-a"; sleep 1;
    #    send_key "y"; sleep 1;
    #    send_key "alt-c"; sleep 1;
    #    send_key "esc"; sleep 1;            #close the Preference
    #    send_key "alt-e"; sleep 1;
    #    send_key "n"; sleep 1;
    #    for(1..3) {                #switch the tab from "Security" to "General"
    #        send_key "right"; sleep 1;
    #    }
    #    send_key "esc"; sleep 1;

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;    # confirm "save&quit"

    send_key "alt-f2";
    sleep 2;
    type_string "rm -rf .mozilla\n";
    sleep 2;
    send_key "ret";
    sleep 5;
}

1;
# vim: set sw=4 et:
