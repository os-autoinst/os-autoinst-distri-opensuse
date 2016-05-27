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

# case 1436143-test nautilus open ftp

sub run() {
    my $self = shift;

    x11_start_program("nautilus");
    send_key "ctrl-l";
    type_string "ftp://ftp.suse.com\n";
    assert_screen "nautilus-ftp-login", 5;
    send_key "ret";
    assert_screen 'nautilus-ftp-suse-com', 20;

    if (sle_version_at_least('12-SP2')) {
        assert_and_click "unselected-pub";
        assert_and_click "ftp-path-selected";
        wait_still_screen;
    }
    send_key "shift-f10";
    assert_screen 'nautilus-ftp-rightkey-menu', 3;
    send_key "u";    #umount the ftp

    send_key "ctrl-w";
}

1;
# vim: set sw=4 et:
