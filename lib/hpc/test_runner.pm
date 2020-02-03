# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Test Runner for HPC single tests
#    This module ensures that single, separate tests can be executed
#    against provisioned HPC cluster
# Maintainer: Sebastian Chlad <sebastian.chlad@suse.com>

package hpc::test_runner;
use base hpcbase;
use strict;
use warnings;
use testapi;
use utils;

sub _validate_result {
    my ($self, $result) = @_;

    if ($result == 0) {
        return 'PASS';
    } elsif ($result == 1) {
        return 'FAIL';
    } else {
        return undef;
    }
}

sub generate_results {
    my ($self, $name, $description, $result) = @_;

    my %results = (
        test        => $name,
        description => $description,
        result      => _validate_result($result)
    );
    return %results;
}

sub pars_results {
    my ($self, @test) = @_;
    my $file = 'tmpresults.xml';
    assert_script_run("touch $file")

    # check if there are some single test failing
    # and if so, make sure the whole testsuite will fail
    my $fail_check = 0;
    for my $i (@test) {
        if ($i->{result} eq 'FAIL') {
            $fail_check++;
        }
    }

    if ($fail_check > 0) {
        script_run("echo \"<testsuite name='HPC single tests' errors='1'>\" >> $file");
    } else {
        script_run("echo \"<testsuite name='HPC single tests'>\" >> $file");
    }

    # pars all results and provide expected xml file
    for my $i (@test) {
        if ($i->{result} eq 'FAIL') {
            script_run("echo \"<testcase name='$i->{test}' errors='1'>\" >>  $file");
        } else {
            script_run("echo \"<testcase name='$i->{test}'>\" >> $file");
        }
        script_run("echo \"<system-out>\" >> $file");
        script_run("echo $i->{description} >>  $file");
        script_run("echo \"</system-out>\" >> $file");
        script_run("echo \"</testcase>\" >> $file");
    }

    script_run("echo \"</testsuite>\" >> $file");
    parse_extra_log('XUnit', 'tmpresults.xml');
}
