# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: dstat
# Summary: To check whether dstat runs
# Maintainer: Michael Vetter <mvetter@suse.com>

use base 'consoletest';
use testapi;
use utils;
use version_utils qw(is_sle is_leap);

sub run {
    select_console 'root-console';

    my $binary = (is_sle('<16') || is_leap('<16.0')) ? "dstat" : "dool";
    zypper_call("in $binary");

    assert_script_run("$binary --helloworld 1 5");
    assert_screen 'dstat-hello-world';
    if (is_sle('=12-SP3')) {
        record_info("bsc#1085238", "12sp3 - dstat counts to 6 instead of 5");
    }
    clear_console;

    assert_script_run("$binary --nocolor 1 2");
    assert_screen 'dstat-nocolor';
    clear_console;

    assert_script_run("$binary -cdn --output testfile 1 2");
    assert_script_run('cat testfile');
    assert_screen 'dstat-fileoutput';
}

1;
