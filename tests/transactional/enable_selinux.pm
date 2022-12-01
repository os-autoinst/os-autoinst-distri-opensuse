# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: transactional-update
# Summary: Enable SELinux on transactional server
#
# Maintainer: QA-C team <qa-c@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use transactional qw(process_reboot);
use version_utils qw(is_sle_micro);
use Utils::Systemd qw(systemctl);
use Utils::Logging 'save_and_upload_log';

sub run {
    select_console 'root-console';
    my $audit_log = "/var/log/audit/audit.log";

    # auditd should be enabled
    systemctl 'is-enabled auditd';

    # install and enable SELinux if not done by default
    if (script_run('test -d /sys/fs/selinux && test -e /etc/selinux/config') != 0) {
        assert_script_run('transactional-update setup-selinux');
        upload_logs('/var/log/transactional-update.log');
        save_and_upload_log('rpm -qa', 'installed_pkgs.txt');
        process_reboot(trigger => 1);
    }

    assert_script_run('selinuxenabled');
    record_info('SELinux', script_output('sestatus'));
    record_info('Audit report', script_output('aureport'));
    record_info('Audit denials', script_output('aureport -a', proceed_on_failure => 1));
    upload_logs($audit_log);
}

sub test_flags {
    return {fatal => 1};
}

1;
