# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: blktests
# Summary: Block device layer tests
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use repo_tools 'add_qa_head_repo';
use package_utils 'install_package';
use Utils::Logging qw(export_logs_basic save_and_upload_log);

sub prepare_blktests_config {
    my ($devices) = @_;

    if ($devices eq 'none') {
        record_info('INFO', 'No specific tests device selected');
    } else {
        script_run("echo TEST_DEVS=\\($devices\\) > /etc/blktests/config");
        record_info('INFO', "$devices");
    }
}

sub run {
    select_serial_terminal;

    #below variable exposes blktests options to the openQA testsuite
    #definition, so that it allows flexible ways of re-runing the tests
    my $tests = get_required_var('BLKTESTS');
    my $quick = get_var('BLKTESTS_QUICK', 60);
    my $exclude = get_var('BLKTESTS_EXCLUDE');
    my $devices = get_required_var('BLKTESTS_DEVICE_ONLY');
    my $trtypes = get_var('BLKTESTS_TRTYPES');

    record_info('KERNEL', script_output('rpm -qi kernel-default'));
    save_and_upload_log('rpm -qi kernel-default', 'kernel_bug_report.txt');

    #QA repo is added with lower prio in order to avoid possible problems
    #with some packages provided in both, tested product and qa repo; example: fio
    add_qa_head_repo(priority => 100);
    install_package('blktests fio', trup_apply => 1);

    #Prepare configuration, log/results directories
    assert_script_run("mkdir -p /etc/blktests");

    my $log_dir = '/var/log/blktests';
    assert_script_run("mkdir -p ${log_dir}/results");

    prepare_blktests_config($devices);

    my @tests = split(',', $tests);
    assert_script_run('cd /usr/lib/blktests');

    $exclude = join(' ', map { "--exclude=$_" } split(/,/, $exclude // ''));
    $trtypes = "NVMET_TRTYPES=\"$trtypes\" " if $trtypes;
    foreach my $i (@tests) {
        my $config = $devices eq 'none' ? '' : '-c /etc/blktests/config';
        script_run("${trtypes} ./check $config -o ${log_dir}/results --quick=$quick $exclude $i", 1200);
    }

    script_run("cd ${log_dir}");
    script_run('wget --quiet ' . data_url('kernel/post_process') . ' -O post_process');
    script_run('chmod +x post_process');
    script_run('./post_process');

    record_info('results', script_output('ls ./results'));
    script_run('tar -zcvf results.tar.gz results');
    upload_logs('results.tar.gz');

    record_info('XML', script_output('ls ./'));
    my $output = script_output("find ${log_dir} -name \"*_results.xml\" 2>/dev/null || true");
    foreach my $file (split /\n/, $output) {
        parse_extra_log('XUnit', $file);
    }
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal;
    export_logs_basic;
}

1;
