# SUSE's openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test openqa-review can be started (with runtime dependencies)
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';

    zypper_call('in python3-openqa_review');
    assert_script_run 'openqa-review --help';
}

1;
