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
use strict;
use testapi;

sub run() {
    assert_script_run("systemctl show -p ActiveState sshd|grep ActiveState=active");
    assert_script_run("systemctl show -p SubState sshd|grep SubState=running");
}

sub test_flags() {
    return {important => 1};
}

1;
