# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
# SUSE's openQA tests
#
# Summary: Verify Kdump service status, Kdump kernel parameters
#          and crush dump after triggering a kernel crash.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use power_action_utils 'power_action';
use Utils::Architectures 'is_s390x';
use utils 'systemctl';
use testapi;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    systemctl("is-active kdump.service");
    systemctl("is-enabled kdump-commandline.service");
    assert_script_run('grep "crashkernel=[0-9]*M" /proc/cmdline');

    script_run "echo c | sudo tee /proc/sysrq-trigger", 0;
    power_action('reboot', is_s390x ? () : keepconsole => 1, textmode => 1);
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);

    select_console 'root-console';
    validate_script_output("find /var/crash/ -maxdepth 1 -type d -mmin -5 | wc -l", sub { $_ eq '2' });
    script_run 'tar -cvJf /tmp/crash_saved.tar.xz -C /var/crash .';
    upload_logs '/tmp/crash_saved.tar.xz';
}

1;
