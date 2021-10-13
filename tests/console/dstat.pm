# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: dstat
# Summary: To check whether dstat runs
# Maintainer: Michael Vetter <mvetter@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    zypper_call('in dstat');

    assert_script_run('dstat --helloworld 1 5');
    assert_screen 'dstat-hello-world';
    clear_console;

    assert_script_run('dstat --nocolor 1 2');
    assert_screen 'dstat-nocolor';
    clear_console;

    assert_script_run('dstat -cdn --output testfile 1 2');
    assert_script_run('cat testfile');
    assert_screen 'dstat-fileoutput';
}

1;
