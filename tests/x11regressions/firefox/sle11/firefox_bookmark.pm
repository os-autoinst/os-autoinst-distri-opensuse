# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# auther xjin
use base "basetest";
use testapi;
use strict;

sub run() {
    my $self = shift;
    mouse_hide(1);

    # to clear all of previous settings and then open the app
    x11_start_program("rm -rf .mozilla");
    x11_start_program("pkill -9 firefox");
    x11_start_program("firefox");
    sleep 10;

    # first confirm www.baidu.com has not been bookmarked yet.
    send_key "ctrl-shift-o";
    sleep 1;
    send_key "tab";
    sleep 1;
    send_key "tab";
    sleep 1;
    type_string "www.baidu.com";
    send_key "ret";
    sleep 3;

    check_screen "bookmark-not-yet", 2;
    send_key "alt-f4";

    # bookmark the page
    send_key "ctrl-l";
    type_string "www.baidu.com";
    sleep 1;
    send_key "ret";
    sleep 6;
    check_screen "bookmark-baidu-main", 3;

    send_key "ctrl-d";
    sleep 2;
    check_screen "bookmarking", 3;
    send_key "ret";
    sleep 2;

    # check all bookmarked page and open baidu mainpage in a new tab
    send_key "ctrl-t";
    sleep 1;
    send_key "ctrl-shift-o";
    sleep 1;

## check toolbar menu and unsorted section displayed; and baidu mainpage in menu section
    check_screen "bookmark-all-bookmark-menu", 3;
    send_key "down";
    sleep 1;
    send_key "ret";
    check_screen "bookmark-baidu-under-bookmark-menu", 3;

## open baidu page
    send_key "tab";
    send_key "tab";
    send_key "tab";
    type_string "www.baidu.com";
    send_key "ret";
    send_key "ret";
    send_key "tab";
    send_key "tab";
    send_key "ret";
    sleep 2;

    check_screen "bookmark-baidu-main", 2;

    # close the bookmark lib page and then close firefox
    send_key "alt-tab";
    sleep 2;
    send_key "alt-f4";
    sleep 5;
    check_screen "bookmark-menu-closed", 3;

## close firefox
    send_key "alt-f4";
    sleep 1;
    send_key "ret";
}

1;
# vim: set sw=4 et:
