# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Plasma kontact startup test
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use testapi;

sub run() {
    # start akonadi server to avoid the self-test running when we launch kontact
    x11_start_program('akonadictl start');

    # Workaround: sometimes the account assistant behind of mainwindow or tips window
    # To disable it run at first time start
    x11_start_program("echo \"[General]\" >> ~/.kde4/share/config/kmail2rc");
    x11_start_program("echo \"first-start=false\" >> ~/.kde4/share/config/kmail2rc");
    x11_start_program("echo \"[General]\" >> ~/.config/kmail2rc");
    x11_start_program("echo \"first-start=false\" >> ~/.config/kmail2rc");

    x11_start_program('kontact');
    my @tags = qw(test-kontact-1 kontact-import-data-dialog kontact-window);
    do {
        assert_screen \@tags;
        # kontact might ask to import data from another mailer, don't
        wait_screen_change { send_key 'alt-n' } if match_has_tag('kontact-import-data-dialog');
        # KF5-based account assistant ignores alt-f4
        wait_screen_change { send_key 'alt-c' } if match_has_tag('test-kontact-1');
    } until (match_has_tag('kontact-window'));
    send_key 'alt-f4';
}

1;
# vim: set sw=4 et:
