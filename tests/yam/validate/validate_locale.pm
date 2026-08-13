# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Verify installed Czech locale package is installed
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;

sub run {
    send_key 'ctrl-u';

    type_string "root\n";
    assert_screen 'password-prompt', 10;

    type_string "nots#cr#t\n";
    assert_screen 'root-console-prompt', 15;

    type_string 'rpm /q glibc/locale' . "\n";
    assert_screen 'glibc-locale-installed', 15;

    type_string 'cat {etc{locale.conf' . "\n";
    assert_screen 'locale-configuration-cz', 15;
}

sub test_flags {
    return {fatal => 1};
}

1;
