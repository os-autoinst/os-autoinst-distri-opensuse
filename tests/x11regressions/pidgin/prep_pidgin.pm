# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;

# Preparation for testing pidgin
sub pidgin_preparation() {
    my $self = shift;
    mouse_hide(1);
    my @packages = qw/pidgin pidgin-otr/;

    # Install packages
    x11_start_program("xterm");
    type_string "xdg-su -c 'zypper -n in @packages'\n";
    sleep 3;
    if ($password) {
        type_password;
        send_key "ret";
    }
    sleep 60;            # give time to install
    type_string "\n";    # prevent the screensaver...
                         # make sure pkgs installed
    type_string "clear;rpm -qa @packages\n";
    assert_screen "pidgin-pkg-installed", 10;

    # Enable the showoffline
    type_string "pidgin\n";
    assert_screen "pidgin-welcome", 10;
    send_key "alt-c";
    sleep 1;

    # pidgin main winodow is hidden in tray at first run
    # need to show up the main window
    send_key "super-m";
    sleep 1;
    send_key "ret";
    sleep 1;

    # check showoffline status is off
    send_key "alt-b";
    sleep 1;
    send_key "o";
    sleep 1;
    assert_screen "pidgin-showoffline-off", 10;
    # enable showoffline
    send_key "o";
    # check showoffline status is on
    send_key "alt-b";
    sleep 1;
    send_key "o";
    assert_screen "pidgin-showoffline-on", 10;
    send_key "esc";

    send_key "ctrl-q";       # quit pidgin
    sleep 1;
    type_string "exit\n";    # close xterm
    sleep 2;
}

sub run() {
    my $self = shift;
    pidgin_preparation;
}

1;
# vim: set sw=4 et:
