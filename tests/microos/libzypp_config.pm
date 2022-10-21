# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check that zypper configuration is customized for MicroOS
# fate#321764
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use version_utils qw(is_jeos);

sub run {
    shift->select_serial_terminal();
    unless (check_var('FLAVOR', 'JeOS-for-AArch64') || check_var('FLAVOR', 'JeOS-for-RPi')) {
        assert_script_run 'grep -E -x "^solver.onlyRequires ?= ?true" /etc/zypp/zypp.conf';
        assert_script_run 'grep -E -x "^rpm.install.excludedocs ?= ?yes" /etc/zypp/zypp.conf';
    }
    assert_script_run sprintf('grep -E -x "^multiversion ?=%s" /etc/zypp/zypp.conf', is_jeos ? ' ?provides:multiversion\(kernel\)' : '');
}

sub post_fail_hook {
    upload_logs '/etc/zypp/zypp.conf';
}

1;
