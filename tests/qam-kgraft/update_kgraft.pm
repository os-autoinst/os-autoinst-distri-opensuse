# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base 'opensusebasetest';
use testapi;
use qam;
use utils;

use strict;
use warnings;

sub timemark {
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
    return sprintf("%02d%02d%02d.%02d%02d.%02d", $year % 100, $mon + 1, $mday, $hour, $min, $sec);
}

sub kgr_status {
    # precompiled regexes
    my $kgr_ready       = qr/^ready/;
    my $kgr_in_progress = qr/^in_progress/;

    script_run("kgr status | tee /dev/$serialdev", 0);
    my $out = wait_serial([$kgr_ready, $kgr_in_progress], 10);
    if ($out =~ $kgr_ready) {
        return 1;
    }
    elsif ($out =~ $kgr_in_progress) {
        return 0;
    }
}

sub kgr_block {
    my $kgr_block_free     = qr/kgr-$/;
    my $kgr_block_hwrandom = qr/kgr-hwrng/;
    my $kgr_block_other    = qr/kgr-.*/;
    my $out                = "";

    while (1) {
        script_run("kgr poke");
        script_run(qq{BLOCK="kgr-\$(kgr blocking)"; echo \$BLOCK |tee > /dev/$serialdev}, 0);
        $out = wait_serial([$kgr_block_hwrandom, $kgr_block_other, $kgr_block_free], 30);

        if ($out =~ $kgr_block_hwrandom) {
            script_run("dd if=/dev/random of=/dev/null bs=2048 count=2000");
        }
        elsif ($out =~ $kgr_block_other) {
        }
        elsif ($out =~ $kgr_block_free) {
            last;
        }
    }
}

sub run() {
    my $self  = shift;
    my $svirt = select_console('svirt');
    my $name  = get_var('VIRSH_GUESTNAME');
    $svirt->attach_to_running($name);
    select_console('sut');
    select_console("root-console");

    capture_state("before");
    script_run(qq{if \$(zypper lr | grep test-kgraft -q);then zypper rr test-kgraft ; fi });
    #check kgr status
    until (kgr_status) {
        kgr_block;
    }

    # create reference snapshot
    my $snapshot_before = "snap_before-" . timemark;
    my $ret             = $svirt->run_cmd("virsh snapshot-create-as $name $snapshot_before");
    die "snapshot $snapshot_before failed" if $ret;
    set_var('KGRAFT_SNAPSHOT_BEFORE', $snapshot_before);

    # check if automounter works
    check_automounter;

    # RUN HEAVY LOAD script
    # TODO: place script somewhere in git and deploy from here
    #       ie /var/tmp/scripty.sh ; applies for all used scripts
    script_run("/root/bin/heavy_load.sh");
    #
    sleep 15;

    #INSTALL UPDATE ... #TODO it needs some coop with IBS ( update repo , patch name)
    my $repo = get_var('KGRAFT_TEST_REPO');
    zypper_call("ar -f $repo test-kgraft");
    zypper_call("ref");

    # TODO . it needs patchinfo and definition of patch
    #save patch name to VAR
    script_run("zypper patches | awk '/test-kgraft/ { print \$3; }' | tee > /dev/$serialdev", 0);

    my $out = wait_serial(qr/SUSE-*/);
    set_var('KGRAFT_PATCH_NAME', $out);

    #patch system
    zypper_call(qq{in -l -y -t patch \$(zypper patches | awk -F "|" '/test-kgraft/ { print \$2;}')}, exitcode => [0, 102, 103], log => 1);

    zypper_call("rr test-kgraft");
    # check if kgraft patch is applied to all functions..
    until (kgr_status) {
        kgr_block;
    }

    # again check automounter
    check_automounter;

    #kill HEAVY-LOAD scripts
    script_run("screen -S LTP_syscalls -X quit");
    script_run("screen -S newburn_KCOMPILE -X quit");
    script_run("/root/bin/heavy_load--tidyup.sh");

    # wait for cooldown:)
    sleep 45;

    # create snapshot after update
    my $snapshot_after = "snap_after-" . timemark;
    $ret = $svirt->run_cmd("virsh snapshot-create-as $name $snapshot_after");
    die "snapshot $snapshot_after failed" if $ret;
    set_var('KGRAFT_SNAPSHOT_AFTER', $snapshot_after);
    capture_state("after");
    type_string("logout\n");

}

sub post_fail_hook() {
    my $self            = shift;
    my $name            = get_var('VIRSH_GUESTNAME');
    my $snapshot_before = get_var('KGRAFT_SNAPSHOT_BEFORE');
    save_screenshot;
    send_key('ctrl-c');
    sleep 2;
    script_run("screen -S LTP_syscalls -X quit");
    script_run("screen -S newburn_KCOMPILE -X quit");
    script_run("/root/bin/heavy_load--tidyup.sh");
    capture_state("fail");
    type_string("logout\n");

    # reconnect to svirt console
    my $svirt = select_console('svirt');
    $svirt->attach_to_running($name);

    # revert to snapshot before update if it exists
    if ($snapshot_before) {
        snap_revert($svirt, $name, $snapshot_before);
    }

}

sub test_flags() {
    return {fatal => 1};
}

1;
