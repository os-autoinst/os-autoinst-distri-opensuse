# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Simple 'zypper in' test
# - List download repositories ("zypper lr -d") and redirect to serial output
# - If no specific package is defined, try to install "x3270" in sle or
# "xdelta3" in openSUSE and "screen"
# - Remove package using rpm -e
# - Check if package was removed
# Maintainer: Richard Brown <rbrownccb@opensuse.org>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    script_run("zypper lr -d | tee /dev/$serialdev");
    my $pkgname = get_var('PACKAGETOINSTALL');
    if (!$pkgname) {
        $pkgname = 'x3270'   if check_var('DISTRI', 'sle');
        $pkgname = 'xdelta3' if check_var('DISTRI', 'opensuse');
    }
    zypper_call "in screen $pkgname";
    clear_console;    # clear screen to see that second update does not do any more
    assert_script_run("rpm -e $pkgname");
    assert_script_run("! rpm -q $pkgname");
}

1;
