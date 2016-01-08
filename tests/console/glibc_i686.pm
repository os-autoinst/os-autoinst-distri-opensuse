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

# this part contains the steps to run this test
sub run() {
    assert_script_sudo("zypper -n in -C libc.so.6");
    script_run("/lib/libc.so.*");
    assert_screen 'test-glibc_i686-1', 100;
}

1;
# vim: set sw=4 et:
