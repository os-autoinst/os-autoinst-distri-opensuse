# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-Later
#
# Summary: Controlling the Auditd daemon as root by "systemctl" to verify it can work
# Maintainer: llzhao <llzhao@suse.com>, shawnhao <weixuan.hao@suse.com>
# Tags: poo#81772, tc#1768549

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';

    # Install packages if they are not installed by default
    if (script_run('rpm -q audit')) {
        zypper_call('in audit libaudit1');
    }

    if (!is_sle("<=12-SP5")) {
        # Check auditd status by default on a clean new VM
        systemctl('is-active auditd');
    }

    # Stop auditd
    systemctl('stop auditd');

    # Check auditd status
    validate_script_output('systemctl status --no-pager auditd', sub { m/Active: inactive./ }, proceed_on_failure => 1);

    # Start auditd again
    systemctl('start auditd');

    # Check auditd status again
    systemctl('is-active auditd');
}

1;
