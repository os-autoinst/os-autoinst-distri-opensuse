# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test public cloud hardened images
#
# Maintainer: <qa-c@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    select_serial_terminal;

    # Basic tests required by https://github.com/SUSE-Enceladus/img-proof/issues/358
    assert_script_run('grep "Authorized uses only. All activity may be monitored and reported." /etc/motd');
    assert_script_run('sudo grep always,exit /etc/audit/rules.d/access.rules /etc/audit/rules.d/delete.rules');
    # Check that at least one account has password age
    assert_script_run("sudo awk -F: '\$5 ~ /[0-9]/ { print \$1, \$5; }' /etc/shadow  | grep '[0-9]'");
}

1;
