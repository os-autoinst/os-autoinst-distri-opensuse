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
use lockapi;

sub prepare_testdata_temp {
    assert_script_run('cd /tmp'); #
    assert_script_run('wget http://loewe.arch.suse.de/tests/1076/file/run_performance_tests-vsperf_logs.tar.gz'); #
    assert_script_run('wget http://loewe.arch.suse.de/tests/1094/file/run_performance_tests-vsperf_logs.tar.gz'); #
    assert_script_run('wget http://loewe.arch.suse.de/tests/1054/file/run_performance_tests-vsperf_logs.tar.gz'); #
    assert_script_run('wget http://loewe.arch.suse.de/tests/1050/file/run_performance_tests-vsperf_logs.tar.gz'); #
    assert_script_run('tar xvf run_performance_tests-vsperf_logs.tar.gz'); #
    assert_script_run('tar xvf run_performance_tests-vsperf_logs.tar.gz.1'); #
    assert_script_run('tar xvf run_performance_tests-vsperf_logs.tar.gz.2'); #
    assert_script_run('tar xvf run_performance_tests-vsperf_logs.tar.gz.3'); #
}

sub run {

    record_info("Package and upload logs");
    my $logs_path = '/tmp/vsperf_logs.tar.gz';
    my $results_folder = '/tmp';
    prepare_testdata_temp();
    assert_script_run("tar -czvf $logs_path $results_folder/results_*");
    upload_logs($logs_path, failok => 1);
    assert_script_run('wget https://raw.githubusercontent.com/asmorodskyi/vsperf_influxdb_connector/parse_folders/export.py');
    assert_script_run('chmod +x export.py');
    assert_script_run(sprintf('./export.py --parsefolder "%s" --targeturl http://10.86.0.128:8086 --os_version %s --os_build %s --vswitch_version %s --openqa_url %s',$results_folder,get_var('VERSION'),get_var('BUILD'),'1','1'));
}

sub test_flags {
    return {fatal => 0};
}

1;
