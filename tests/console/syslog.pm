# Copyright (C) 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check for syslog daemon
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'consoletest';
use strict;
use testapi;
use utils;
use version_utils;

sub run {
    select_console 'root-console';

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

