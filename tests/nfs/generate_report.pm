# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Upload logs and generate report
# Maintainer: Yong Sun <yosun@suse.com>
package generate_report;

use strict;
use warnings;
use base 'opensusebasetest';
use Mojo::JSON;
use testapi;
use upload_system_log;

sub display_results {
    my $self = shift;
    my $skip = "";
    my $pass = "";
    my $fail = 0;

    my $folder = get_required_var('PYNFS');

    assert_script_run("cd ~/pynfs/$folder");
    upload_logs('results.json', failok => 1);

    my $content = script_output('cat results.json');
    my $results = Mojo::JSON::decode_json($content);

    die 'failed to parse results.json' unless $results;
    die 'results.json is not array' unless (ref($results->{testcase}) eq 'ARRAY');

    record_info('Results', "failures: $results->{failures}\nskipped: $results->{skipped}\ntime: $results->{time}");

    for my $test (@{$results->{testcase}}) {
        if (exists($test->{skipped})) {
            $skip .= "$test->{code}\n";
        } elsif (!exists($test->{failure})) {
            $pass .= "$test->{code}\n";
        }
    }

    record_info('Passed', $pass);
    record_info('Skipped', $skip);

    for my $test (@{$results->{testcase}}) {
        bmwqemu::fctinfo("code: $test->{code}");
        next unless (exists($test->{failure}));

        my $targs = OpenQA::Test::RunArgs->new();
        $targs->{data} = $test;
        autotest::loadtest("tests/nfs/pynfs_result.pm", name => $test->{code}, run_args => $targs);
        $fail = 1;
    }

    if (!$fail) {
        my $targs = OpenQA::Test::RunArgs->new();
        $targs->{all_passed} = 'ALL TESTS PASSED';
        autotest::loadtest("tests/nfs/pynfs_result.pm", name => $targs->{all_passed}, run_args => $targs);
    }
}

sub upload_cthon04_log {
    my $self = shift;
    assert_script_run('cd ~/cthon04');
    if (script_output("grep 'All tests completed' ./result* | wc -l") =~ '4') {
        record_info('Complete', "All tests completed");
    }
    else {
        $self->result("fail");
        record_info("Test fail: Not all test completed");
    }
    if (script_output("grep ' ok.' ./result_basic_test.txt | wc -l") =~ '9') {
        record_info('Pass', "Basic test pass");
    }
    else {
        $self->result("fail");
        record_info('Fail', "Basic test failed");
    }
    if (script_output("grep -E ' ok|success' ./result_special_test.txt | wc -l") =~ '7') {
        record_info('Pass', "Special test pass");
    }
    else {
        $self->result("fail");
        record_info('Fail', "Special test failed");
    }
    if (script_run("grep 'Congratulations' ./result_lock_test.txt")) {
        $self->result("fail");
        record_info('Fail', "Lock test failed");
    }
    else {
        record_info('Pass', "Lock test pass");
    }
    upload_logs('result_basic_test.txt', failok => 1);
    upload_logs('result_general_test.txt', failok => 1);
    upload_logs('result_special_test.txt', failok => 1);
    upload_logs('result_lock_test.txt', failok => 1);
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    if (get_var("PYNFS")) {
        $self->display_results();
    }
    elsif (get_var("CTHON04")) {
        $self->upload_cthon04_log();
    }
    upload_system_logs();

    autotest::loadtest("tests/shutdown/shutdown.pm");
}

sub test_flags {
    return {no_rollback => 1};
}

1;
