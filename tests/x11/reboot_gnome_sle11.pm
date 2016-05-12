# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;
use utils;

sub run() {
    wait_idle;
    send_key "alt-f1";    # applicationsmenu
    my $selected = check_screen 'shutdown_button', 0;
    if (!$selected) {
        send_key_until_needlematch 'shutdown_button', 'tab', 20;    # press tab till is shutdown button selected
    }

    send_key "ret";                                                 # press shutdown button
    assert_screen "logoutdialog", 15;
    send_key "tab";
    my $ret;
    for (my $counter = 10; $counter > 0; $counter--) {
        $ret = check_screen "logoutdialog-reboot-highlighted", 3;
        if (defined($ret)) {
            last;
        }
        else {
            send_key "tab";
        }
    }
    # report the failure or green
    unless (defined($ret)) {
        assert_screen "logoutdialog-reboot-highlighted", 1;
    }
    send_key "ret";    # confirm

    if (get_var("SHUTDOWN_NEEDS_AUTH")) {
        assert_screen 'reboot-auth', 15;
        type_password;
        send_key "ret";
    }

    power('reset');
    wait_boot;
}

sub test_flags() {
    return {important => 1, milestone => 1};
}
1;

# vim: set sw=4 et:
