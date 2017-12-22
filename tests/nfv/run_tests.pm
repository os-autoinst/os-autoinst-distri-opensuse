# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Placeholder for steps to run the tests
#
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "consoletest";
use testapi;
use strict;
use utils;
use lockapi;
use mmapi;

sub run {
    select_console 'root-console';
    mutex_create('nfv_trafficgen_ready');

    # wait until traffic generator installation finishes
    wait_for_children;

    # placeholder for running tests
    assert_script_run("ip a");

}

1;

# vim: set sw=4 et:
