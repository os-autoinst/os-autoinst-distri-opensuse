# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

#
# Summary: consume memory and make sure selected process don't get swapped
#
# Maintainer: Michael Moese <mmoese@suse.de>
# Tags: https://progress.opensuse.org/issues/49031

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils 'is_sle';
use registration;
use utils;
use Mojo::Util 'trim';

sub run {
    my $meminfo;
    my $failed;

    my $cgroup_mem = get_required_var('WMP_MEMORY_LOW');
    my $stressng_mem = get_var('WMP_STRESS_MEM', 0);

    my $sid = get_required_var('INSTANCE_SID');
    my $instance_id = get_required_var('INSTANCE_ID');
    my $instance_type = get_var('INSTANCE_TYPE', 'HDB');


    if (is_sle('<15') || is_sle('>=15-SP5')) {
        diag "WMP not supported on " . get_var('VERSION');
        return;
    }

    select_serial_terminal;

    # we're only interested in the number
    my $mem_free = script_output('grep MemFree /proc/meminfo') =~ /(\d+)/;
    $stressng_mem = $mem_free if ($mem_free < $stressng_mem or $stressng_mem == 0);

    # we need packagehub for stress-ng, let's enable it
    add_suseconnect_product(get_addon_fullname('phub'));
    zypper_call("in stress-ng");

    # configure memory.low
    assert_script_run("systemctl set-property SAP.slice MemoryLow=$cgroup_mem");

    # start hana again and wait for the memory consumption to settle
    my $admuser = lc($sid) . "adm";
    my $sappath = "/usr/sap/" . $sid . "/" . $instance_type . $instance_id . "/exe";
    my $sapctrl = "/usr/sap/" . $sappath . "/sapcontrol";

    assert_script_run('sudo -u ' . $admuser . ' bash -c "export LD_LIBRARY_PATH=' . $sappath . '" "' . $sapctrl . ' -nr 00 -function StartSystem ALL"');


    # wait until memory usage of HANA settled, this takes a while and we have to patiently wait
    sleep 300;

    # consume memory in the background
    background_script_run("stress-ng --vm-bytes $stressng_mem --vm-keep -m 1");

    # let everything run for a while
    sleep 300;

    $meminfo = script_output("cat /proc/meminfo");
    record_info("meminfo", "$meminfo");


    my @pids = split(' ', script_output("cat /sys/fs/cgroup/SAP.slice/cgroup.procs"));

    foreach (@pids) {
        my $vmswap = trim(script_output("grep \"VmSwap:\"  /proc/$_/status | cut -d ':' -f 2"));
        my $cmdline = trim(script_output("cat /proc/$_/cmdline"));

        if ($vmswap eq "0 kB") {
            record_info("not swapped", "Process $cmdline (Pid $_) is not using swap", result => 'ok');
        } else {
            record_info("swapped", "Process $cmdline (Pid $_) is using $vmswap of swap", result => 'fail');
            $failed = 1;
        }
    }
    die "at least one process is using swap memory" if $failed;
    $meminfo = script_output("cat /proc/meminfo");
    record_info("meminfo", "$meminfo");
}

1;
