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
use testapi;

sub run() {
    my $self = shift;

    # start akonadi server avoid self-test running when launch kontact
    x11_start_program("akonadictl start");
    wait_idle 3;

    # Workaround: sometimes the account assistant behind of mainwindow or tips window
    # To disable it run at first time start
    x11_start_program("echo \"[General]\" >> ~/.kde4/share/config/kmail2rc");
    x11_start_program("echo \"first-start=false\" >> ~/.kde4/share/config/kmail2rc");

    x11_start_program("kontact", 6, {valid => 1});

    # kontact has asking import data from another mailer
    if (check_screen('kontact-import-data-dialog')) {
        send_key "alt-n";    # Don't
    }

    assert_screen "test-kontact-1", 20;    # tips window or assistant
    send_key "alt-c";                      # KF5-based account assistant ignores alt-f4
    assert_screen "kontact-window", 3;
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
