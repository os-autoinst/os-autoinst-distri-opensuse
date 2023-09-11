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
use version_utils qw(is_leap_micro is_microos is_sle_micro is_public_cloud);
use Utils::Systemd qw(systemctl);
use Utils::Logging 'save_and_upload_log';
use transactional qw(trup_call check_reboot_changes process_reboot);
use publiccloud::utils qw(allow_openqa_port_selinux);
use bootloader_setup 'replace_grub_cmdline_settings';

sub check_enforcing {
    assert_script_run('selinuxenabled');
    validate_script_output("getenforce", sub { m/Enforcing/ });
    validate_script_output("sestatus", sub { m/Current mode:.*enforcing/ });
    validate_script_output("sestatus", sub { m/Mode from config file:.*enforcing/ });
    record_info('SELinux', script_output('sestatus'));
    record_info('Audit report', script_output('aureport'));
    record_info('Audit denials', script_output('aureport -a', proceed_on_failure => 1));
}

sub check_disabled {
    record_info('SELinux', script_output('sestatus'));
    assert_script_run('! selinuxenabled');
    validate_script_output("getenforce", sub { m/Disabled/ });
    validate_script_output("sestatus", sub { m/SELinux status:.*disabled/ });
}

sub is_enforcing {
    return (script_run('test -d /sys/fs/selinux && test -e /etc/selinux/config && getenforce | grep -i "enforcing" >/dev/null') == 0);
}

sub run {
    select_console 'root-console';

    # Until bsc#1211058 is resolved, we cannot enable SELinux via `transactional-update setup-selinux`.
    if (is_sle_micro('=5.2')) {
        record_soft_failure("bsc#1211058 Enabling SELinux broken via transactional-update setup-selinux");
        return;
    }

    my $trup_log = "/var/log/transactional-update.log";

    # auditd should be enabled
    systemctl 'is-enabled auditd';

    # install and enable SELinux if not done by default
    if (!is_enforcing) {
        if (is_sle_micro('5.4+') || is_leap_micro('5.4+') || is_microos) {
            if (is_sle_micro('=5.4')) {
                record_soft_failure("bsc#1211917 - SELinux not in enforcing mode on SLEM 5.4");
            } else {
                die("SELinux should be enabled by default on " . get_required_var("DISTRI") . " " . get_required_var("VERSION"));
            }
        }

        trup_call('setup-selinux');
        upload_logs($trup_log, log_name => $trup_log . ".txt");
        save_and_upload_log('rpm -qa', 'installed_pkgs.txt');
        check_reboot_changes;
    }
    allow_openqa_port_selinux() if (is_public_cloud);

    check_enforcing;

    # disable and re-enable SELinux
    record_info('Disable', "Disable SELinux");
    assert_script_run "sed -i -e 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config";
    # See "Note: Relabeling your system after switching from the disabled mode" section on:
    # https://documentation.suse.com/sle-micro/5.4/html/SLE-Micro-all/cha-selinux-slemicro.html
    assert_script_run "touch /etc/selinux/.autorelabel";
    # DEPRECATED runtime disable
    # see https://github.com/SELinuxProject/selinux-kernel/wiki/DEPRECATE-runtime-disable
    replace_grub_cmdline_settings('security=selinux selinux=1', 'security=selinux selinux=0', update_grub => 1);
    process_reboot(trigger => 1);
    check_disabled;
    record_info('Re-enable', "Re-enabling SELinux");
    trup_call('setup-selinux');
    replace_grub_cmdline_settings('security=selinux selinux=0', 'security=selinux selinux=1', update_grub => 1);
    process_reboot(trigger => 1);
    check_enforcing;
    assert_script_run "test -f /etc/selinux/.relabelled";
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_run_hook {
    my $audit_log = "/var/log/audit/audit.log";
    upload_logs($audit_log, log_name => $audit_log . ".txt");
}

1;
