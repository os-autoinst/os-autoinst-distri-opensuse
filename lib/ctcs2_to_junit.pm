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
    my $writer   = XML::Writer->new(DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT => "self");

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
        if (!get_var('QA_TESTSUITE') && ($case_status eq 'failure' || $case_status eq 'skipped')) {
            (my $test_path = $test) =~ s/-/\//;
            $test_path = '/opt/log/' . $test_path;
            my $test_out_content = script_output("cat $test_path| sed \"s/'//g\" | sed \"s/[\\x00-\\x08\\x0B-\\x0C\\x0E-\\x1F]//g\"|tail -n 200", 600);
            $writer->startTag('system-out');
            $writer->characters($test_out_content);
            $writer->endTag('system-out');
            if ($case_status eq 'failure') {
                my $test_err_content = script_output("
                    echo '====out.bad log====';
                    if [ -f $test_path.out.bad ];
                        then cat $test_path.out.bad|sed \"s/'//g\"|sed \"s/[\\x00-\\x08\\x0B-\\x0C\\x0E-\\x1F]//g\"|tail -n 200;
                    else echo '$test_path.out.bad not exist';
                    fi;
                    echo '====full log====';
                    if [ -f $test_path.full ];
                        then cat $test_path.full|sed \"s/'//g\"|sed \"s/[\\x00-\\x08\\x0B-\\x0C\\x0E-\\x1F]//g\"|tail -n 200;
                    else echo '$test_path.full not exist';
                    fi;
                ", 600);
                $writer->startTag('system-err');
                $writer->characters($test_err_content);
                $writer->endTag('system-err');
            }
        }
        $writer->endTag('testcase');
    }

    $writer->endTag('testsuite');
    $writer->endTag('testsuites');

    $writer->end();
    $writer->to_string();
}

1;
