# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run NFV Performance tests
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use testapi;
use strict;
use lockapi;

our $results_dir = '/tmp';
our $ovs_version;
our $test_url;

sub run_test {
    my ($test, $vswitch) = @_;
    my $testname = "$test\_$vswitch";
    record_info($testname);
    assert_script_run("./vsperf --conf-file=/root/vswitchperf/conf/10_custom.conf --vswitch $vswitch $test", timeout => 4000);
    record_info("Push Results");
    assert_script_run(sprintf('./push2db.py --parsefolder "%s" --targeturl http://10.86.0.128:8086 --os_version %s --os_build %s --vswitch_version %s --openqa_url %s',
            $results_dir, get_var('VERSION'), get_var('BUILD'), $ovs_version, $test_url));
    assert_script_run("mv /tmp/push2db.log /tmp/push2db_$testname.log");
    upload_logs("/tmp/push2db_$testname.log", failok => 1);
    assert_script_run("tar -czvf /tmp/vsperf_logs_$testname.tar.gz $results_dir/results_*");
    upload_logs("/tmp/vsperf_logs_$test.tar.gz", failok => 1);
    assert_script_run("rm -r $results_dir/results_*");
}

sub run {
    select_console 'root-ssh';

    # Arrayss for test specs
    my @tests   = ('phy2phy_tput', 'phy2phy_cont');
    my @vswitch = ('OvsVanilla',   'OvsVanilla');

    # Get OVS version
    $ovs_version = script_output(q(ovs-vswitchd --version|head -1|awk '{print $NF}'));

    # Generate JOB URL (OSD)
    my ($test_id) = get_required_var("NAME") =~ m{^([^-]*)};
    $test_id =~ s/^0+//;
    $test_url = "http://openqa.suse.de/tests/$test_id";

    assert_script_run("pip2 install -q requests");

    record_info("Check Hugepages");
    assert_script_run('cat /proc/meminfo |grep -i huge');

    # Get push to DB script
    record_info("Get push2db.py");
    assert_script_run("curl " . data_url('nfv/push2db.py') . " -o /root/vswitchperf/push2db.py");
    assert_script_run('chmod +x /root/vswitchperf/push2db.py');

    record_info("Start tests");
    assert_script_run('source /root/vsperfenv/bin/activate && cd /root/vswitchperf/');

    for my $i (0 .. $#tests) {
        record_info("Test $i");
        run_test($tests[$i], $vswitch[$i]);
    }
    mutex_create("NFV_TESTING_DONE");
}

sub test_flags {
    return {fatal => 1};
}

1;
