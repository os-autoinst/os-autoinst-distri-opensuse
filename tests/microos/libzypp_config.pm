# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check that zypper configuration is customized for MicroOS
# fate#321764
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use version_utils qw(is_jeos is_transactional);

sub run {
    select_serial_terminal();
    unless (check_var('FLAVOR', 'JeOS-for-AArch64') || check_var('FLAVOR', 'JeOS-for-RPi')) {
        assert_script_run 'grep -E -x "^solver.onlyRequires ?= ?true" /etc/zypp/zypp.conf';
        assert_script_run 'grep -E -x "^rpm.install.excludedocs ?= ?yes" /etc/zypp/zypp.conf';
    }
    if (is_jeos || is_transactional) {
        assert_script_run 'echo multiversion="provides:multiversion(kernel)" >> /etc/zypp/zypp.conf';
        assert_script_run 'echo multiversion.kernels="latest" >> /etc/zypp/zypp.conf';
        assert_script_run 'echo LIVEPATCH_KERNEL="always" >> /etc/sysconfig/livepatching';
    }
}
sub post_fail_hook {
    upload_logs '/etc/zypp/zypp.conf';
}

1;
