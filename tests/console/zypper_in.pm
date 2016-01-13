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
    my $self = shift;
    become_root();

    script_run("zypper lr -d | tee /dev/$serialdev");

    my $pkgname = get_var("PACKAGETOINSTALL");
    assert_script_run("zypper -n in screen $pkgname");
    clear_console;    # clear screen to see that second update does not do any more
    assert_script_run("rpm -e $pkgname");
    script_run("rpm -q $pkgname");
    script_run('exit');
    assert_screen "package-$pkgname-not-installed", 5;
}

1;
# vim: set sw=4 et:
