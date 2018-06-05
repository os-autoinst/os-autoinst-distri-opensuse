# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary:  base class for convert QA:Head ctcs2 wrapper testsuite test log to junit format
# Maintainer: Yong Sun <yosun@suse.com>

package ctcs2_to_junit;

use strict;
use warnings;
use base "Exporter";
use Exporter;
use testapi;
use utils;
use XML::Writer;

our @EXPORT = qw(analyzeResult generateXML);

sub analyzeResult {
    my ($text) = @_;
    my $result = ();
    $text =~ /Test in progress(.*)Test run complete/s;
    my $rough_result = $1;
    foreach (split("\n", $rough_result)) {
        if ($_ =~ /(\S+)\s+\.{3}\s+\.{3}\s+(PASSED|FAILED|SKIPPED)\s+\((\S+)\)/g) {
            $result->{$1}{status} = $2;
            $result->{$1}{time}   = $3;
        }
    }
    return $result;
}

sub generateXML {
    my ($data) = @_;

    my %test_results = %$data;
    my $case_status;
    my $case_num = scalar(keys %test_results);
    my $pass_num = 0;
    my $fail_num = 0;
    my $skip_num = 0;
    my $writer   = new XML::Writer(DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT => "self");

    foreach my $test (keys(%test_results)) {
        if ($test_results{$test}->{status} =~ m/PASSED/) {
            $pass_num += 1;
        }
        elsif ($test_results{$test}->{status} =~ m/SKIPPED/) {
            $skip_num += 1;
        }
        else {
            $fail_num += 1;
        }
    }
    $writer->startTag(
        'testsuites',
        error    => "0",
        failures => "$fail_num",
        name     => "",
        skipped  => "$skip_num",
        tests    => "$case_num",
        time     => ""
    );
    $writer->startTag(
        'testsuite',
        error     => "0",
        failures  => "$fail_num",
        hostname  => `hostname`,
        id        => "0",
        name      => get_var("QA_TESTSUITE"),
        package   => get_var("QA_TESTSUITE"),
        skipped   => "0",
        tests     => "$case_num",
        time      => "",
        timestamp => `date`
    );

    my @tests = sort(keys(%test_results));
    foreach my $test (@tests) {
        if ($test_results{$test}->{status} =~ m/PASSED/) {
            $case_status = "success";
        }
        elsif ($test_results{$test}->{status} =~ m/SKIPPED/) {
            $case_status = "skipped";
        }
        else {
            $case_status = "failure";
        }

        $writer->startTag(
            'testcase',
            classname => get_var("QA_TESTSUITE"),
            name      => $test,
            status    => $case_status,
            time      => $test_results{$test}->{time});
        $writer->startTag('system-err');
        $writer->characters("");
        $writer->endTag('system-err');
        $writer->startTag('system-out');
        $writer->characters("");
        $writer->endTag('system-out');
        $writer->endTag('testcase');
    }

    $writer->endTag('testsuite');
    $writer->endTag('testsuites');

    $writer->end();
    $writer->to_string();
}

1;
