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
# Case:        1248975
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

    my @sites = ('www.baidu.com', 'www.novell.com', 'www.google.com');

    for my $site (@sites) {
        send_key "ctrl-l";
        sleep 1;
        type_string $site. "\n";
        sleep 5;
        $site =~ s{\.com}{};
        $site =~ s{.*\.}{};
        check_screen "firefox_page-" . $site, 5;
    }

    send_key "alt-left";
    sleep 2;
    send_key "alt-left";
    sleep 3;
    check_screen "firefox_page-baidu", 5;
    send_key "alt-right";
    sleep 3;
    check_screen "firefox_page-novell", 5;
    send_key "f5";
    sleep 3;
    check_screen "firefox_page-novell", 5;

    send_key "alt-f4";
    sleep 2;
    send_key "ret";
    sleep 2;    # confirm "save&quit"
}

1;
# vim: set sw=4 et:
