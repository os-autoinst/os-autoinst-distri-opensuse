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
use utils;
use Mojo::Util 'trim';

sub run {
    my $self = shift;
    my $meminfo;
    my $failed;

    my $cgroup_mem = get_required_var('WMP_MEMORY_LOW');
    my $stressng_mem = get_required_var('WMP_STRESS_MEM');
    my $stressng_repo = get_var('WMP_STRESS_REPO', "https://download.opensuse.org/repositories/benchmark/SLE_15_SP3/benchmark.repo");

    my $sid = get_required_var('INSTANCE_SID');
    my $instance_id = get_required_var('INSTANCE_ID');
    my $instance_type = get_var('INSTANCE_TYPE', 'HDB');

    $self->select_serial_terminal;

    zypper_ar($stressng_repo, no_gpg_check => 1);
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

    my $scope = trim(script_output('systemd-cgls -u SAP.slice | grep \'wmp-.*.scope\' | cut -c 3-'));

    my @pids = split(' ', script_output("cat /sys/fs/cgroup/SAP.slice/$scope/cgroup.procs"));

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
