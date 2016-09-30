# G-Summary: Add test for awesome window manager
#    Based on "minimalx" installation.
#
#    Related issue: https://progress.opensuse.org/issues/9522
# G-Maintainer: Dominik Heidler <dheidler@suse.de>

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
