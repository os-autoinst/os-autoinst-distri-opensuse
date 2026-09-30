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

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils 'is_sle';
use registration;
use utils;
use Mojo::Util 'trim';

# Total resident memory (kB) of the processes in SAP.slice
sub sap_slice_rss {
    my $rss = script_output(q{for p in $(cat /sys/fs/cgroup/SAP.slice/cgroup.procs); do awk '/^VmRSS:/ {print $2}' /proc/$p/status; done | awk '{sum+=$1} END {print sum+0}'},
        proceed_on_failure => 1);
    return $rss =~ /(\d+)/ ? $1 : 0;
}

# Wait for HANA to finish allocating memory after StartSystem. The memory is
# considered settled once the total RSS of SAP.slice has not changed by more
# than 50 MiB over three samples. Capped at the previous fixed 5 minute wait.
sub wait_for_sap_memory_settle {
    my $deadline = time + bmwqemu::scale_timeout(300);
    my ($previous, $stable) = (undef, 0);
    while (time < $deadline) {
        my $rss = sap_slice_rss();
        $stable = (defined $previous && abs($rss - $previous) < 50 * 1024) ? $stable + 1 : 0;
        $previous = $rss;
        last if $stable >= 3;
        sleep bmwqemu::scale_timeout(10);
    }
}

# Wait until stress-ng has put the system under memory pressure, detected as
# MemAvailable dropping below 10% of MemTotal, then give swapping a short grace
# period. If the pressure is never observed, wait the previous fixed 5 minutes.
sub wait_for_memory_pressure {
    my $deadline = time + bmwqemu::scale_timeout(300);
    my $mem_total = script_output(q{awk '/^MemTotal:/ {print $2}' /proc/meminfo}, proceed_on_failure => 1);
    $mem_total = $1 if $mem_total =~ /(\d+)/;
    while (time < $deadline) {
        my $available = script_output(q{awk '/^MemAvailable:/ {print $2}' /proc/meminfo}, proceed_on_failure => 1);
        $available = $1 if $available =~ /(\d+)/;
        if ($mem_total && $available && $available < $mem_total / 10) {
            sleep bmwqemu::scale_timeout(30);
            last;
        }
        sleep bmwqemu::scale_timeout(10);
    }
}

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


    # wait until the memory usage of HANA has settled
    wait_for_sap_memory_settle;

    # consume memory in the background
    background_script_run("stress-ng --vm-bytes $stressng_mem --vm-keep -m 1");

    # let the memory pressure build up
    wait_for_memory_pressure;

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

=head1 Description

Basic Workload Memory Protection (WMP) test for SAP systems. The test sets
C<MemoryLow> on the C<SAP.slice> systemd slice, starts the SAP system, then
uses C<stress-ng> (installed from PackageHub) to put the machine under memory
pressure. After that, every process in C<SAP.slice> is checked, and the test
fails if any of them has memory swapped out.

It expects a SAP instance that is already installed, and it only runs on
SLE 15 up to SLE 15-SP4. On other versions it returns without doing anything.

=head1 Configuration

=head2 WMP_MEMORY_LOW

Required. Value passed to C<systemctl set-property SAP.slice MemoryLow=>,
for example C<30G>.

=head2 WMP_STRESS_MEM

Amount of memory for C<stress-ng --vm-bytes> to consume. It is capped at the
C<MemFree> value from C</proc/meminfo>, and that value is also used if this is
unset or set to C<0>.

=head2 INSTANCE_SID

Required. SAP system ID, for example C<NDB>. It is used to work out the
C<E<lt>sidE<gt>adm> user and the instance path.

=head2 INSTANCE_ID

Required. SAP instance number, for example C<00>.

=head2 INSTANCE_TYPE

SAP instance type, used in the instance path. Defaults to C<HDB>.

=cut
