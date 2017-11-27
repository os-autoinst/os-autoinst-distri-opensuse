# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Very simple, needle free, bind server test
# Maintainer: sysrich <RBrownCCB@opensuse.org>

use strict;
use base "consoletest";
use testapi;
use main_common 'is_bridged_networking';

sub run {
    # Skip the entire test on bridget networks (e.g. Xen, Hyper-V)
    if (is_bridged_networking) {
        record_soft_failure 'Bug 1064438: "bind" cannot resolve localhost';
        return;
    }
    select_console 'root-console';

    # Install bind
    assert_script_run "zypper -n -q in bind";

    # check that it can be enabled and disabled;
    assert_script_run "systemctl enable named.service";
    assert_script_run "systemctl disable named.service";

    # let's try to run it
    assert_script_run "systemctl start named.service";
    assert_script_run "systemctl show -p ActiveState named.service|grep ActiveState=active";
    assert_script_run "systemctl show -p SubState named.service|grep SubState=running";

    # verify dns server responds to anything
    assert_script_run "host localhost localhost";
}

1;
# vim: set sw=4 et:
