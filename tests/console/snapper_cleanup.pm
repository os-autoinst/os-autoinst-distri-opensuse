# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use utils;
use testapi;

sub snapper() {
    # we want to fill up disk enough so that snapper cleanup triggers
    my $scratch_size_gb = 8;
    for (1 .. $scratch_size_gb / 2) {
        assert_script_run "snapper create --cleanup number --command 'dd if=/dev/urandom of=data bs=1M count=1024'";
    }
    for (1 .. $scratch_size_gb / 2) {
        assert_script_run "snapper create --cleanup number -u important=yes --command 'dd if=/dev/urandom of=data bs=1M count=1024'";
    }
    clear_console;
    assert_script_run("btrfs qgroup show -p / | tail -20", 3);
    script_run("snapper cleanup number");    # cleanup created snapshots
    assert_script_run("btrfs qgroup show -p / ", 3);
    script_run("snapper ls");
    script_run("btrfs filesystem df -h /");
    clear_console;
}

sub run() {
    select_console 'root-console';

    if (get_var("UPGRADE") || get_var("AUTOUPGRADE") && !get_var("BOOT_TO_SNAPSHOT")) {
        script_run("snapper setup-quota");
        script_run("snapper set-config NUMBER_LIMIT=2-10 NUMBER_LIMIT_IMPORTANT=4-10 | tee /dev/$serialdev");
    }

    script_run("snapper set-config NUMBER_MIN_AGE=0 | tee /dev/$serialdev");
    assert_script_run("btrfs qgroup show -p /");

    # we need to run snapper at least some times to ensure it cleans up properly
    # arbitrary value proven by test
    my $snapper_runs = 4;
    for (1 .. $snapper_runs) { snapper() }

    script_run("snapper set-config NUMBER_MIN_AGE=1800 | tee /dev/$serialdev");
}

sub test_flags() {
    return {important => 1};
}

1;
