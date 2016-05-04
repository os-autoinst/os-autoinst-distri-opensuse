# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "basetest";
use strict;
use testapi;
use Time::HiRes qw(sleep);

sub run() {
    assert_screen "inst-bootmenu", 30;
    sleep 2;
    send_key "ret";    # boot

    assert_screen "grub2", 15;
    sleep 1;
    send_key "ret";

    assert_screen "displaymanager", 200;
    mouse_hide(1);
    # do not login to desktop to reduce possibility of blocking zypper by packagekitd
    # and directly switch to text console
    select_console 'user-console';
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
