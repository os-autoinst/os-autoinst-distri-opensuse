# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install openQA using openqa-bootstrap
# Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use base "consoletest";
use testapi;
use utils;


sub run {
    select_console 'root-console';

    zypper_call('in openQA-bootstrap');
    assert_script_run('/usr/share/openqa/script/openqa-bootstrap', 1600);
}

sub test_flags {
    return {fatal => 1};
}

1;
