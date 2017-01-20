# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Live Patching regression testsuite
# Maintainer: Ondřej Súkup <osukup@suse.cz>

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
        script_run(qq{BLOCK="kgr-\$(kgr blocking)"; echo \$BLOCK > /dev/$serialdev}, 0);
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
    my $svirt = select_console('svirt');
    my $name  = get_var('VIRSH_GUESTNAME');
    my $build = get_var('BUILD');
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
    my $ret             = $svirt->run_cmd("virsh snapshot-create-as $name $snapshot_before $build");
    die "snapshot $snapshot_before failed" if $ret;
    set_var('KGRAFT_SNAPSHOT_BEFORE', $snapshot_before);

    # check if automounter works
    check_automounter;

    script_run(
        qq{rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE} (%{INSTALLTIME:date})\n" | sort -t '-' > /tmp/rpmlist.before});
    upload_logs('/tmp/rpmlist.before');

    # RUN HEAVY LOAD script
    assert_script_run("curl -f " . autoinst_url . "/data/qam/heavy_load.sh -o /tmp/heavy_load.sh");
    script_run("bash /tmp/heavy_load.sh");
    #
    sleep 15;

    #INSTALL UPDATE ... #TODO it needs some coop with IBS ( update repo , patch name)
    my $repo = get_var('KGRAFT_TEST_REPO');
    zypper_call("ar -f $repo test-kgraft");
    zypper_call("ref");

    # TODO . it needs patchinfo and definition of patch
    #patch system
    zypper_call(
        qq{in -l -y -t patch \$(zypper patches | awk -F "|" '/test-kgraft/ { print \$2;}')},
        exitcode => [0, 102, 103],
        log      => 'zypper.log'
    );

    zypper_call("rr test-kgraft");

    script_run("rm /tmp/heavy_load.sh");

    # check if kgraft patch is applied to all functions..
    until (kgr_status) {
        kgr_block;
    }

    # again check automounter
    check_automounter;

    #kill HEAVY-LOAD scripts
    script_run("screen -S LTP_syscalls -X quit");
    script_run("screen -S newburn_KCOMPILE -X quit");
    script_run("rm -Rf /var/log/qa");

    # wait for cooldown:)
    sleep 45;

    script_run(
        qq{rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE} (%{INSTALLTIME:date})\n" | sort -t '-' > /tmp/rpmlist.after});
    upload_logs('/tmp/rpmlist.after');

    capture_state("after");
    script_run("clear");
    type_string("logout\n");

    # create snapshot after update
    my $snapshot_after = "snap_after-" . timemark;
    $ret = $svirt->run_cmd("virsh snapshot-create-as $name $snapshot_after $build");
    die "snapshot $snapshot_after failed" if $ret;
    set_var('KGRAFT_SNAPSHOT_AFTER', $snapshot_after);
}

sub post_fail_hook() {
    my $name            = get_var('VIRSH_GUESTNAME');
    my $snapshot_before = get_var('KGRAFT_SNAPSHOT_BEFORE');
    save_screenshot;
    send_key('ctrl-c');
    sleep 2;
    script_run("screen -S LTP_syscalls -X quit");
    script_run("screen -S newburn_KCOMPILE -X quit");
    script_run("rm -Rf /var/log/qa", 120);
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
