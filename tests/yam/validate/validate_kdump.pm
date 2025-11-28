# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
# SUSE's openQA tests
#
# Summary: Validation kdump in agama install and check kdump function
#
# Scenarios covered:
# - Verify kdump services are enabled
# - Verify crashkernel= is present in /proc/cmdline
# - Verify kdump work with debug kernel and core file is present.
# - Trigger system dump.
# - Check the crash dump after system reboot.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use power_action_utils 'power_action';
use Utils::Architectures qw(is_s390x);
use testapi;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    assert_script_run("systemctl status --no-pager kdump | grep 'Active: active (exited)'");
    assert_script_run('grep "crashkernel=[0-9]*M" /proc/cmdline');

    assert_script_run "reset";
    script_run "echo c | sudo tee /proc/sysrq-trigger", 0;

    power_action('reboot', textmode => 1, keepconsole => is_s390x() ? 0 : 1);
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);

    select_console 'root-console';

    assert_script_run 'find /var/crash/';
    assert_script_run('ls -d /var/crash/[0-9][0-9][0-9][0-9]*');
    script_run 'tar -cvJf /tmp/crash_saved.tar.xz -C /var/crash .';
    upload_logs '/tmp/crash_saved.tar.xz';
}

1;
