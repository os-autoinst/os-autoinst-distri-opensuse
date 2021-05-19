# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Package: transactional-update
# Summary: Enable SELinux on transactional server
#
# Maintainer: QA-C team <qa-c@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use transactional qw(process_reboot);
use version_utils qw(is_sle_micro);
use Utils::Systemd qw(systemctl);

sub run {
    select_console 'root-console';
    my $audit_log = "/var/log/audit/audit.log";

    # auditd should be enabled
    systemctl 'is-enabled auditd';

    # install and enable SELinux if not done by default
    if (script_run('test -d /sys/fs/selinux && test -e /etc/selinux/config') != 0) {
        assert_script_run('transactional-update setup-selinux');
        process_reboot(trigger => 1);
    }

    assert_script_run('selinuxenabled');
    record_info('SELinux',       script_output('sestatus'));
    record_info('Audit report',  script_output('aureport'));
    record_info('Audit denials', script_output('aureport -a'));
    upload_logs($audit_log);
}

sub test_flags {
    return {fatal => 1};
}

1;
