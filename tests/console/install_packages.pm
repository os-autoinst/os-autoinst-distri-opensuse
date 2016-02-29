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

sub run() {
    select_console 'root-console';

    my $packages = get_var("INSTALL_PACKAGES");

    assert_script_run("zypper -n in -l perl-solv");
    assert_script_run("~$username/data/lsmfip --verbose $packages > \$XDG_RUNTIME_DIR/install_packages.txt");
    assert_script_run("xargs zypper -n in -l < \$XDG_RUNTIME_DIR/install_packages.txt");
    assert_script_run("rpm -q $packages | tee /dev/$serialdev");
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
