# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Integrate the Lynis scanner into OpenQA: run test cases/modules
#          according to section list
# Maintainer: QE Security <none@suse.de>
# Tags: poo#78224, poo#78230

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use autotest;
use lynis::lynistest;

sub run {
    my ($self, $tinfo) = @_;
    my $section = $tinfo->test;
    my $section_orig = $tinfo->test;

    my $baseline_file = $lynis::lynistest::lynis_baseline_file;
    my $current_file = $lynis::lynistest::lynis_audit_system_current_file;

    my @section_content_baseline = ();
    my @section_content_current = ();

    my $found = 0;
    my $results;

    record_info("$section", " Got: $section in \"current\" \"# lynis audit system\" output file");

    # Rename the section for easier "regex match": e.g., replace special characters
    $section = lynis::lynistest::rename_lynis_section($section);
    $section = substr($section, 4);

    # Parse the "sections" in baseline file
    my @section_list_baseline = lynis::lynistest::parse_lynis_section_list("assets_private/$baseline_file");
    for my $section_baseline (@section_list_baseline) {
        # Rename the section for easier "regex match"
        $section_baseline = lynis::lynistest::rename_lynis_section($section_baseline);

        $section_baseline = substr($section_baseline, 4);
        if ("$section" eq "$section_baseline") {
            # Found the section in baseline
            $found = 1;
            last;
        }
    }

    # Replace "\n, \r" in this section for easier show up
    $section_orig =~ s/\n//g;
    $section_orig =~ s/\r//g;
    if ($found) {
        # Do find the section in baseline, compare the results between "baseline" and "current"
        record_info("Found", "Found \"$section_orig\" in baseline file, then compare the results between \"baseline\" and \"current\"!");
        @section_content_baseline = lynis::lynistest::parse_lynis_section_content($section_orig, "assets_private/$baseline_file");
        @section_content_current = lynis::lynistest::parse_lynis_section_content($section_orig, "assets_private/$current_file");
        $results = lynis::lynistest::compare_lynis_section_content($found, \@section_content_baseline, \@section_content_current);
    }
    else {
        # Do not find the section in baseline, check the current file testing results
        # It is a new section, report "WARNING" and "softfailure"
        # Check the results according to "Settings": "LYNIS_OK", "LYNIS_ERROR", "LYNIS_WARNING"
        record_info("NotFound", "Not found \"$section_orig\" in baseline file");
        record_info("WARNING", "New section \"$section_orig\" detected, please check and update the baseline!");
        # Set softfail for checking and updating the baseline
        record_soft_failure("poo#91383, Not found \"$section_orig\" in baseline file, set softfail and only check results in \"current\"");
        @section_content_baseline = lynis::lynistest::parse_lynis_section_content($section_orig, "assets_private/$baseline_file");
        @section_content_current = lynis::lynistest::parse_lynis_section_content($section_orig, "assets_private/$current_file");
        $results = lynis::lynistest::compare_lynis_section_content($found, \@section_content_baseline, \@section_content_current);
        if ("$results" eq "ok") {
            $results = "softfail";
        }
    }

    $self->result("$results");
}

1;
