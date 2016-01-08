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
# Case:        1248978
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

    send_key "ctrl-k";
    sleep 1;
    send_key "ret";
    sleep 5;
    check_screen "firefox_page-google", 5;                      #check point 1
    send_key "ctrl-k";
    sleep 1;
    type_string "opensuse" . "\n";
    sleep 5;
    check_screen "firefox_search-opensuse", 5;                  #check point 2
    send_key "ctrl-k";
    sleep 1;
    send_key "f4";
    sleep 1;
    send_key "y";
    sleep 1;                                                    #select the yahoo as search engine
    send_key "ret";
    sleep 5;
    check_screen "firefox_yahoo-search", 5;                     #check point 4

    #recover the changes, change search engine to google
    send_key "ctrl-k";
    sleep 1;
    send_key "f4";
    sleep 1;
    send_key "g";
    sleep 1;

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;    # confirm "save&quit"
}

1;

# vim: set sw=4 et:
