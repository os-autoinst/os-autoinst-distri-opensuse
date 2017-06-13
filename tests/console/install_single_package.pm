# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Simple test for installing any given package
# Maintainer: soulofdestiny <mgriessmeier@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils;

sub run() {
    select_console 'root-console';

    pkcon_quit;

    # add specific repository which contains the package
    if (get_var('PACKAGE_REPO')) {
        zypper_call("ar -f " . get_var('PACKAGE_REPO') . " testrepo");
        zypper_call("--gpg-auto-import-keys ref");
    }

    # write 'zypper lr' to $serialdev for having more debug information
    script_run("zypper lr -d | tee /dev/$serialdev");

    # install desired package
    my $pkgname = get_required_var('PACKAGETOINSTALL');
    zypper_call "in $pkgname";

    # ensure that package was installed correctly
    assert_script_run("rpm -q $pkgname");
}

1;
# vim: set sw=4 et:
