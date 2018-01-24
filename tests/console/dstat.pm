# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: To check whether dstat runs
# Maintainer: Michael Vetter <mvetter@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils;

sub run {
    select_console "root-console";

    zypper_call("in dstat");

    assert_script_run("dstat --helloworld 1 5");
    assert_screen "dstat-hello-world";
    type_string("clear\n");

    assert_script_run("dstat --nocolor 1 2");
    assert_screen "dstat-nocolor";
    type_string("clear\n");

    assert_script_run("dstat -cdn --output testfile 1 2");
    type_string("cat testfile\n");
    assert_screen "dstat-fileoutput";
}

1;
# vim: set sw=4 et:
