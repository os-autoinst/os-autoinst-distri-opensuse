# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This test looks for selinux fails in audit log
# Maintainer: Ludwig Nussel <lnussel@suse.com>

use base "consoletest";
use testapi;

sub run {
    select_console 'root-console';

    script_run "ausearch -ts boot -m avc | tee /root/selinux_audit_logs.txt";

    upload_logs "/root/selinux_audit_logs.txt";

    assert_script_run "! grep denied /root/selinux_audit_logs.txt";
}

sub test_flags {
    return {fatal => 1};
}

1;
