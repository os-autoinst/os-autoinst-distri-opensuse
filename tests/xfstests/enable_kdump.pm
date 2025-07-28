# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: procps yast2-kdump kdump crash mokutil kernel-*-debuginfo
# Summary: Enable kdump and verify it's enabled
# - Run "echo "kernel.softlockup_panic = 1" >> /etc/sysctl.conf"
# - Run "sysctl -p"  and check for "kernel.softlockup_panic = 1"
# - Stop packagekit service
# - Install yast2-kdump kdump crash
# - If distro is sle, add kernel debuginfo repository
# - Otherwise, add repository from REPO_OSS_DEBUGINFO variable
# - Install kernel debuginfo
# - Add crashkernel parameters on grub commandline
# - Enable kdump service
# - Reboot
# - Check if kdump is enabled
# Maintainer: Yong Sun <yosun@suse.com>
package enable_kdump;

use 5.018;
use base 'opensusebasetest';
use utils;
use Utils::Backends;
use power_action_utils 'power_action';
use kdump_utils;
use testapi;

sub run {
    my $self = shift;
    select_console 'root-console';

    # Enable panic when softlockup happens
    assert_script_run('echo "kernel.softlockup_panic = 1" >> /etc/sysctl.conf');
    script_run('sysctl -p');

    # Activate kdump
    prepare_for_kdump;
    activate_kdump_without_yast;

    # Reboot
    power_action('reboot');
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(bootloader_time => 200);
    select_console('root-console');
    die "Failed to enable kdump" unless kdump_is_active;
}

sub test_flags {
    return {fatal => 1};
}

sub enable_kdump_failure_analysis {
    # Upload y2log for analysis if enable kdump fails
    assert_script_run 'save_y2logs /tmp/y2logs.tar.bz2';
    upload_logs '/tmp/y2logs.tar.bz2';
    save_screenshot;
}

sub post_fail_hook {
    my ($self) = @_;
    $self->enable_kdump_failure_analysis;
}

1;
