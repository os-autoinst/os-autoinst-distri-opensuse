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
# Case:        1248977
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

    send_key "alt-e";
    sleep 1;
    send_key "n";
    sleep 1;
    send_key "alt-p";
    sleep 1;
    type_string "www.google.com";
    sleep 2;
    check_screen "firefox_pref-general-homepage", 5;
    send_key "ret";
    sleep 1;
    send_key "alt-home";
    sleep 5;
    check_screen "firefox_page-google", 5;

    #exit and relaunch the browser
    send_key "alt-f4";
    sleep 2;
    x11_start_program("firefox");
    check_screen "firefox_page-google", 5;

    #recover all the changes, home page
    send_key "alt-e";
    sleep 1;
    send_key "n";
    sleep 1;
    send_key "alt-r";
    sleep 1;    #choose "Restore to Default"
    send_key "esc";
    sleep 1;

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;    # confirm "save&quit"
}

1;
# vim: set sw=4 et:
