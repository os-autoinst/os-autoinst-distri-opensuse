# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rebootmgr
# Summary: Test rebootmgr using different strategies
# Maintainer: Martin Kravec <mkravec@suse.com>
# Tags: poo#16266

use Mojo::Base 'consoletest';
use testapi;
use transactional;
use utils;
use version_utils qw(is_tumbleweed is_sle_micro);
use Utils::Backends 'is_pvm';
use serial_terminal 'select_serial_terminal';

# Optionally skip exit status check in case immediate reboot is expected
sub rbm_call {
    my $cmd = shift;
    my $check = shift // 1;

    if ($check) {
        assert_script_run "rebootmgrctl $cmd";
    }
    else {
        script_run "rebootmgrctl $cmd", 0;
    }
}

sub rbm_check_status {
    my $expected = shift // 0;
    my $current = script_run "rebootmgrctl status --quiet";

    if ($current != $expected) {
        die "Unexpected rebootmgr status: $current, expected: $expected";
    }
}

# Sample time values: +1hour, -20minutes, now, 00:30
sub rbm_set_window {
    my $time = shift;
    my $duration = shift;
    rbm_call "set-window \$(date -d $time +%T) $duration";
}

# Soft reboot only triggers a full reboot when installing a new kernel
# update of the bootloader or any command like rollback, grub.cfg, bootloader, run or shell
sub is_soft_reboot_requested {
    return 0 if is_sle_micro;
    my $soft_reboot_requested;
    my $regex = qr/Minimally required reboot level:\s(.*)[\r\n]/;
    my $output = wait_serial($regex, timeout => 300) or die "Could not capture reboot type";
    if ($output =~ $regex) {
        $soft_reboot_requested = ($1 eq "soft-reboot") ? 1 : 0;
        record_info("Reboot strategy: $1");
    }
    return $soft_reboot_requested;
}

#1 Test instant reboot
sub check_strategy_instantly {
    select_console('root-console');
    rbm_call "set-strategy instantly";
    trup_call "reboot ptf install" . rpmver('interactive');

    my @reboot_args = is_soft_reboot_requested() ? (expected_grub => 0) : ();
    process_reboot(@reboot_args);

    rbm_call "get-strategy | grep instantly";
}

#2 Test maint-window strategy
sub check_strategy_maint_window {
    select_console('root-console');
    rbm_call "set-strategy maint-window";

    # Trigger reboot during maint-window
    rbm_set_window '-5minutes', '20m';
    trup_call "reboot pkg install" . rpmver('feature');

    my @reboot_args = is_soft_reboot_requested() ? (expected_grub => 0) : ();
    process_reboot(@reboot_args);

    # Trigger reboot and wait for maintenance window
    rbm_set_window '+2minutes', '1m';
    rbm_call 'reboot';
    rbm_check_status 2;
    die "System should be rebooting" unless wait_screen_change(undef, 180);
    process_reboot;

    # Trigger & cancel reboot
    rbm_set_window '+1hour', '20m';
    rbm_call 'reboot';
    rbm_check_status 2;
    rbm_call 'cancel';
    rbm_check_status 0;
}

sub run {
    select_serial_terminal;

    get_utt_packages;

    record_info 'Instantly', 'Test instant reboot';
    check_strategy_instantly;

    record_info 'Maint-window', 'Test maint-window strategy';
    check_strategy_maint_window;
}

1;
