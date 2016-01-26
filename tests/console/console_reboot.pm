# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use testapi;
use utils;

sub run() {
    become_root;
    type_string "reboot\n";
    wait_boot;
    select_console 'user-console';
    assert_script_sudo "chown $username /dev/$serialdev";
    check_console_font;
}

sub test_flags() {
    return {milestone => 1, important => 1};
}
1;

# vim: set sw=4 et:
