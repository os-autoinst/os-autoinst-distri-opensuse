# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: util-linux-systemd rsyslog
# Summary: Check for syslog daemon
# - Run "logger Test Log Message FOOBAR123"
# - Check if syslog-ng is installed
# - If rsyslog is installed, check if rsyslog is enabled, active and its status,
# if system is not tumbleweed or jeos.
# - Check system log for test message
# - Check if systemd-journald is enabled, active and its status
# - Check journalctl -b output for test message
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;

sub run {
    select_serial_terminal;

    my $test_log_msg = 'Test Log Message FOOBAR123';
    assert_script_run "logger $test_log_msg";

    assert_script_run '! rpm -q syslog-ng';

    if (!is_tumbleweed && !is_jeos) {
        # check if rsyslogd is installed, enabled and running
        assert_script_run 'rpm -q rsyslog';
        systemctl 'is-enabled rsyslog';
        systemctl 'is-active rsyslog';
        systemctl 'status rsyslog';
        assert_script_run "grep \"$test_log_msg\" /var/log/messages";
    }

    # check for systemd-journald
    systemctl 'is-enabled systemd-journald';
    systemctl 'is-active systemd-journald';
    systemctl 'status systemd-journald';
    assert_script_run 'journalctl --no-pager -n10';
    assert_script_run "journalctl -b | grep \"$test_log_msg\"";
}

1;

