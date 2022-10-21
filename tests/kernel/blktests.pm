# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: blktests
# Summary: Block device layer tests
# Maintainer: Sebastian Chlad <schlad@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use repo_tools 'add_qa_head_repo';

sub prepare_blktests_config {
    my ($devices) = @_;

    if ($devices eq 'none') {
        record_info('INFO', 'No specific tests device selected');
    } else {
        script_run("echo TEST_DEVS=\\($devices\\) > /usr/lib/blktests/config");
        record_info('INFO', "$devices");
    }
}

sub run {
    select_serial_terminal;

    #below variable exposes blktests options to the openQA testsuite
    #definition, so that it allows flexible ways of re-runing the tests
    my $tests = get_required_var('BLK_TESTS');
    my $quick = get_required_var('BLK_QUICK');
    my $exclude = get_required_var('BLK_EXCLUDE');
    my $config = get_required_var('BLK_CONFIG');
    my $devices = get_required_var('BLK_DEVICE_ONLY');

    record_info('KERNEL', script_output('rpm -qi kernel-default'));

    #QA repo is added with lower prio in order to avoid possible problems
    #with some packages provided in both, tested product and qa repo; example: fio
    add_qa_head_repo(priority => 100);
    zypper_call('in blktests');

    prepare_blktests_config($devices);

    my @tests = split(',', $tests);
    assert_script_run('cd /usr/lib/blktests');

    foreach my $i (@tests) {
        script_run("./check --quick=$quick --exclude=$exclude $i", 480);
    }

    # below part is Work-in-progress, please see:
    # https://progress.opensuse.org/issues/64872
    script_run('wget --quiet ' . data_url('kernel/post_process') . ' -O post_process');
    script_run('chmod +x post_process');
    script_run('./post_process');

    if ($devices ne 'none') {
        my @all_dev = split(' ', $devices);
        foreach my $i (@all_dev) {
            $i =~ s/\/dev\///;
            parse_extra_log('XUnit', "${i}_results.xml");
        }
    }

    parse_extra_log('XUnit', 'nodev_results.xml');
    parse_extra_log('XUnit', 'nullb0_results.xml');

    script_run('tar -zcvf results.tar.gz results');
    upload_logs('results.tar.gz');
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal;
    $self->export_logs_basic;
    script_run('rpm -qi kernel-default > /tmp/kernel_info');
    upload_logs('/tmp/kernel_info');
}

1;
