# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


##################################################
# Written by:    Xudong Zhang <xdzhang@suse.com>
# Case:        1248964
# Description:    Test firefox help
##################################################

use strict;
use base "x11regressiontest";
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

    send_key "alt-h";
    sleep 1;
    send_key "h";
    sleep 6;
    check_screen "firefox_help-help", 8;
    send_key "ctrl-w";
    sleep 1;                                                    #close the firefox help tab
    send_key "alt-h";
    sleep 1;
    send_key "t";
    sleep 1;
    check_screen "firefox_help-trouble", 3;
    send_key "ctrl-w";
    sleep 1;                                                    #close the firefox troubleshooting tab
    send_key "alt-h";
    sleep 1;
    send_key "s";
    sleep 6;
    check_screen "firefox_help-feedback", 8;
    send_key "ctrl-w";
    sleep 1;                                                    #close the firefox submit feedback tab

    #test firefox--report web forgery
    send_key "alt-h";
    sleep 1;
    send_key "f";
    sleep 6;
    check_screen "firefox_help-forgery", 5;                     #need to close tab cause if open in current tab

    #test firefox--about firefox
    send_key "alt-h";
    sleep 1;
    send_key "a";
    sleep 1;
    check_screen "firefox_help-about", 5;
    send_key "alt-f4";
    sleep 1;                                                    #close the firefox about dialog

    #test firefox help--restart with addons disable
    send_key "alt-h";
    sleep 1;
    send_key "r";
    sleep 2;
    check_screen "firefox_restart-addons-disable", 5;
    send_key "ret";
    sleep 3;
    check_screen "firefox_safemode", 3;
    send_key "ret";
    sleep 4;
    check_screen "firefox_help-forgery", 5;    #will open last closed website
    send_key "ctrl-shift-a";
    sleep 3;
    send_key "tab";
    sleep 1;
    send_key "tab";
    sleep 1;                                   #switch to extension column of add-ons
    send_key "down";
    sleep 1;
    check_screen "firefox_addons-safemode", 5;

    #recover all changes--switch addons page to default column
    send_key "up";
    sleep 1;
    send_key "ctrl-w";
    sleep 1;                                   #close the firefox addons tab

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;                                   # confirm "save&quit"
}

1;

# vim: set sw=4 et:
