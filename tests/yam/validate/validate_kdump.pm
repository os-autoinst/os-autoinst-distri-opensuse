# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
# SUSE's openQA tests
#
# Summary: Validation kdump services and kernel cmldline
# Scenarios covered:
# - Verify kdump services are enabled
# - Verify crashkernel= is present in /proc/cmdline
# - Verify kdump work with debug kernel and core file is present.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use kdump_utils qw(configure_service check_function);
use testapi;

sub run {
    select_console 'root-console';

    script_run("systemctl status kdump");
    script_run("systemctl status kdump-commandline.service");
    script_run("systemctl status kdump-commandline");

    assert_script_run("systemctl status --no-pager kdump | grep 'Active: active (exited)'");
    assert_script_run('grep "crashkernel=[0-9]*M" /proc/cmdline');
    # assert_script_run("systemctl status --no-pager kdump-commandline.service | grep 'Active: inactive (dead)'");
    configure_service(test_type => 'function', yast_interface => 'cli');
    check_function(test_type => 'function');
}

sub post_fail_hook {
    my ($self) = @_;

    script_run 'ls -lah /boot/';
    script_run 'tar -cvJf /tmp/crash_saved.tar.xz -C /var/crash .';
    upload_logs '/tmp/crash_saved.tar.xz';

    $self->SUPER::post_fail_hook;
}
1;
