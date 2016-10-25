# Summary: Install windowmanager awesome
# Maintainer: Dominik Heidler <dheidler@suse.de>
# Tags: poo#9522

use base "consoletest";
use strict;
use testapi;

sub run() {
    select_console 'root-console';

    if (check_var("DESKTOP", "awesome")) {
        assert_script_run("zypper -n in awesome");
        script_run("sed -i 's/^DEFAULT_WM.*\$/DEFAULT_WM=\"awesome\"/' /etc/sysconfig/windowmanager");
    }
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
