# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test rebootmgr using different strategies
# Maintainer: Martin Kravec <mkravec@suse.com>
# Tags: poo#16266

use strict;
use base "opensusebasetest";
use testapi;
use transactional_system;
use caasp;
use utils;
use version_utils 'is_caasp';

# Optionally skip exit status check in case immediate reboot is expected
sub rbm_call {
    my $cmd   = shift;
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
    my $current  = script_run "rebootmgrctl status --quiet";

    if ($current != $expected) {
        die "Unexpected rebootmgr status: $current, expected: $expected";
    }
}

# Sample time values: +1hour, -20minutes, now, 00:30
sub rbm_set_window {
    my $time     = shift;
    my $duration = shift // '1h';
    rbm_call "set-window \$(date -d $time +%T) $duration";
}

#1 Test instant reboot
sub check_strategy_instantly {
    rbm_call "set-strategy instantly";
    trup_call "reboot ptf install" . rpmver('interactive'), 0;
    process_reboot;
    rbm_call "get-strategy | grep instantly";
}

#2 Test maint-window strategy
sub check_strategy_maint_window {
    rbm_call "set-strategy maint-window";

    # Trigger reboot during maint-window
    rbm_set_window '-5minutes';
    trup_call "reboot pkg install" . rpmver('feature'), 0;
    process_reboot;

    # Trigger reboot and wait for maintenance window
    rbm_set_window '+2minutes';
    rbm_call 'reboot';
    rbm_check_status 2;
    die "System should be rebooting" unless wait_screen_change(undef, 120);
    process_reboot;

    # Trigger & cancel reboot
    rbm_set_window '+1hour';
    rbm_call 'reboot';
    rbm_check_status 2;
    rbm_call "cancel";
    rbm_check_status 0;
}

#3 Test etcd locking strategy
sub check_strategy_etcd_lock {
    rbm_call "set-strategy etcd-lock";
    systemctl 'enable --now etcd';

    # Unlock during maintenance window - bsc#1026274
    rbm_call "lock lock1";
    rbm_set_window 'now', '1h';
    trup_call "reboot ptf install" . rpmver('reboot-needed');
    rbm_check_status 3;
    rbm_call "unlock lock1", 0;
    process_reboot;

    # Maintenance window passes while waiting for lock - bsc#1026298
    rbm_call "lock lock2";
    rbm_set_window '+1minute', '1m';
    rbm_call 'reboot';
    sleep 120;
    rbm_check_status 3;
    rbm_call "unlock lock2";
    rbm_check_status 0;
}

sub run {
    type_string "tput civis\n";

    record_info 'Instantly', 'Test instant reboot';
    check_strategy_instantly;

    record_info 'Maint-window', 'Test maint-window strategy';
    check_strategy_maint_window;

    if (!is_caasp('kubic')) {
        record_info 'Etcd', 'Test etcd locking strategy';
        check_strategy_etcd_lock;
    }
}

1;
