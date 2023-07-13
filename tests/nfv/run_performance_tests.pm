# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run NFV Performance tests
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends;
use strict;
use warnings;
use lockapi;

our $results_dir = '/tmp';
our $ovs_version;
our $test_url;

sub run_test {
    my ($test, $vswitch) = @_;
    my $testname = "$test\_$vswitch";
    my $cmd = "./vsperf --conf-file=/root/vswitchperf/conf/10_custom.conf --vswitch $vswitch $test";
    record_info("INFO", "Running test case $testname");
    record_info("INFO", "Command to run: $cmd");
    if (is_ipmi) {
        assert_script_run($cmd, timeout => 60 * 60 * 1.5);
    } elsif (is_qemu) {
        record_info("INFO", "Skip test as this is a virtual environment. Generate dummy results instead.");
        assert_script_run("mkdir -p $results_dir/results_dummy");
        assert_script_run("curl " . data_url('nfv/result_0_dummy.csv') . " -o $results_dir/results_dummy/result_0_dummy.csv");
    }
    record_info("INFO", "Push VSPerf Results to InfluxDB");
    assert_script_run(sprintf('./push2db.py --parsefolder "%s" --targeturl http://10.86.0.128:8086 --os_version %s --os_build %s --vswitch_version %s --openqa_url %s',
            $results_dir, get_var('VERSION'), get_var('BUILD'), $ovs_version, $test_url));
    assert_script_run("mv ./push2db.log $results_dir/push2db_$testname.log");
    upload_logs("$results_dir/push2db_$testname.log", failok => 1);
    assert_script_run("tar -czvf $results_dir/vsperf_logs_$testname.tar.gz $results_dir/results_*");
    upload_logs("$results_dir/vsperf_logs_$test.tar.gz", failok => 1);
    assert_script_run("rm -r $results_dir/results_*");
}

sub run {
    select_serial_terminal;

    # Arrayss for test specs
    my @tests = ('phy2phy_tput', 'pvp_tput', 'pvvp_tput');
    my @vswitch = ('OvsVanilla', 'OvsVanilla', 'OvsVanilla');

    # Get OVS version
    $ovs_version = script_output(q(ovs-vswitchd --version|head -1|awk '{print $NF}'));

    # Generate JOB URL (OSD)
    my ($test_id) = get_required_var("NAME") =~ m{^([^-]*)};
    $test_id =~ s/^0+//;
    $test_url = "http://openqa.suse.de/tests/$test_id";

    record_info("INFO", "Check Hugepages information");
    assert_script_run('cat /proc/meminfo |grep -i huge');

    # Get push to DB script
    record_info("INFO", "Download push2db.py script");
    assert_script_run("curl " . data_url('nfv/push2db.py') . " -o /root/vswitchperf/push2db.py");
    assert_script_run('chmod +x /root/vswitchperf/push2db.py');

    record_info("INFO", "Start VSPERF environment");
    assert_script_run('source /root/vsperfenv/bin/activate && cd /root/vswitchperf/');

    for my $i (0 .. $#tests) {
        record_info("Test $i");
        run_test($tests[$i], $vswitch[$i]);
    }

    record_info("INFO", "Mutex NFV_TESTING_DONE created");
    mutex_create("NFV_TESTING_DONE");
}

sub test_flags {
    return {fatal => 1};
}

1;
