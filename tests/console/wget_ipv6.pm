# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wget
# Summary: Test curl fallback from IPv6 to IPv4
# - Install wget
# - Test that wget is installed
# - Download a file and display its contents
# Maintainer: QE Core <qe-core@suse.de>
# Tags: bsc#598574

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    select_console 'root-console';
    zypper_call 'in wget';
    select_console 'user-console';
    assert_script_run('rpm -q wget');
    assert_script_run('wget -O- -6 -q www3.zq1.de/test.txt');
}

1;
