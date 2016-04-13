# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

#package install_update;

use base "consoletest";

use strict;

use qam;
use testapi;

sub run {
    system_login;

    assert_script_run("cmp -s /tmp/ip_a_before.log /tmp/ip_a_after.log");
    assert_script_run("cmp -s /tmp/ip_r_before.log /tmp/ip_r_after.log");
}

sub flags {
    return {fatal => 1};
}

1;
