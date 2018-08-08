# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Process results of  NFV Performance tests :
#       - package and upload  perf logs to openQA job
#       - fill up results DB with data
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>, Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use testapi;
use strict;
use serial_terminal 'select_virtio_console';

sub run {
    select_console 'root-ssh' if (check_var('BACKEND', 'ipmi'));
    select_virtio_console()   if (check_var('BACKEND', 'qemu'));

    my $logs_path      = '/tmp/vsperf_logs.tar.gz';
    my $results_folder = '/tmp';
    my $export_script  = 'https://raw.githubusercontent.com/asmorodskyi/vsperf_influxdb_connector/master/export.py';

    record_info("Install requests");
    assert_script_run("pip2 install -q requests");

    record_info("Upload logs");
    assert_script_run("cd $results_folder");
    assert_script_run("tar -czvf $logs_path $results_folder/results_*");
    upload_logs($logs_path, failok => 1);

    # Get OVS version
    my $ovs_version = script_output(q(ovs-vswitchd --version|head -1|awk '{print $NF}'));

    # Generate JOB URL (OSD)
    my ($test_id) = get_required_var("NAME") =~ m{^([^-]*)};
    $test_id =~ s/^0+//;
    my $test_url = "http://openqa.suse.de/tests/$test_id";

    record_info("Parse results");
    assert_script_run("wget $export_script");
    assert_script_run('chmod +x export.py');
    assert_script_run(sprintf('./export.py --parsefolder "%s" --targeturl http://10.86.0.128:8086 --os_version %s --os_build %s --vswitch_version %s --openqa_url %s',
            $results_folder, get_var('VERSION'), get_var('BUILD'), $ovs_version, $test_url));

    upload_logs('/tmp/export.log', failok => 1);
}

sub test_flags {
    return {fatal => 0};
}

1;
