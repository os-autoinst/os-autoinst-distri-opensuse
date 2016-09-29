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
# Case:        1248985
##################################################

# G-Summary: Restore SLE11 cases to sub-directory, remove main.pm lines because no openSUSE cases.
# G-Maintainer: wnereiz <wnereiz@gmail.com>

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

    send_key "ctrl-l";
    sleep 1;
    type_string "https://www.google.com" . "\n";
    sleep 6;
    check_screen "firefox_https-google", 3;

    send_key "ctrl-l";
    sleep 1;
    type_string "http://147.2.207.207/repo" . "\n";
    sleep 3;
    check_screen "firefox_http207", 3;

    send_key "ctrl-l";
    sleep 1;
    type_string "https://147.2.207.207/repo" . "\n";
    sleep 3;
    check_screen "firefox_https-risk", 3;
    send_key "shift-tab";
    sleep 1;    #select "I Understand..."
    send_key "ret";
    sleep 1;    #open the "I Understand..."
    send_key "tab";
    sleep 1;    #select the "Add Exception"
    send_key "ret";
    sleep 1;    #click "Add Exception"
    check_screen "firefox_addexcept", 3;
    send_key "alt-c";
    sleep 1;
    check_screen "firefox_https-207", 3;

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;    # confirm "save&quit"
}

1;
# vim: set sw=4 et:
