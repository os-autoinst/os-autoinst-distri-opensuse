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
use version_utils qw(is_sle_micro is_public_cloud);
use Utils::Systemd qw(systemctl);
use Utils::Logging 'save_and_upload_log';
use transactional qw(trup_call check_reboot_changes process_reboot);

sub run {
    select_console 'root-console';

    # Until bsc#1211058 is resolved, we cannot enable SELinux via `transactional-update setup-selinux`.
    if (is_sle_micro('=5.2')) {
        record_soft_failure("bsc#1211058 Enabling SELinux broken via transactional-update setup-selinux");
        return;
    }

    my $audit_log = "/var/log/audit/audit.log";

    # auditd should be enabled
    systemctl 'is-enabled auditd';

    # install and enable SELinux if not done by default
    if (script_run('test -d /sys/fs/selinux && test -e /etc/selinux/config && getenforce | grep -i "enforcing" >/dev/null') != 0) {
        trup_call('setup-selinux');
        upload_logs('/var/log/transactional-update.log');
        save_and_upload_log('rpm -qa', 'installed_pkgs.txt');
        check_reboot_changes;
        if (is_public_cloud) {
            # Additional packages required for semanage
            trup_call('pkg install policycoreutils-python-utils');
            check_reboot_changes;
            # allow ssh tunnel port (to openQA)
            my $upload_port = get_required_var('QEMUPORT') + 1;
            assert_script_run("semanage port -a -t ssh_port_t -p tcp $upload_port");
            process_reboot(trigger => 1);
        }
    }

    assert_script_run('selinuxenabled');
    validate_script_output("getenforce", sub { m/Enforcing/ });
    validate_script_output("sestatus", sub { m/Current mode:.*enforcing/ });
    validate_script_output("sestatus", sub { m/Mode from config file:.*enforcing/ });
    record_info('SELinux', script_output('sestatus'));
    record_info('Audit report', script_output('aureport'));
    record_info('Audit denials', script_output('aureport -a', proceed_on_failure => 1));
    upload_logs($audit_log);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
