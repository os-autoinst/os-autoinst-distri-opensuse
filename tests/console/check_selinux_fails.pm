# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: This test looks for selinux fails in audit log
# Maintainer: Ludwig Nussel <lnussel@suse.com>

use base "consoletest";
use strict;
use warnings;
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
