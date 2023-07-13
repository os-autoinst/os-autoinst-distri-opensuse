# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Integrate the Lynis scanner into OpenQA: analyze the "system audit"
#          current outputs with baseline
# Maintainer: QE Security <none@suse.de>
# Tags: poo#78224, poo#78230, poo#78330

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use lynis::lynistest;

sub run {
    my $dir = $lynis::lynistest::testdir;
    my $baseline_file = $lynis::lynistest::lynis_baseline_file;
    my $current_file = $lynis::lynistest::lynis_audit_system_current_file;
    my $f_position_b = $lynis::lynistest::f_position_b;
    my $f_position_c = $lynis::lynistest::f_position_c;

    # Section name list
    my @section_list_current = ();
    my @section_list_baseline = ();

    select_console "root-console";

    # Parse the "sections" in baseline file
    upload_asset("$dir" . "$baseline_file");
    @section_list_baseline = lynis::lynistest::parse_lynis_section_list("assets_private/$baseline_file");

    # Parse the "sections" in new/current output files of "# lynis audit system"
    upload_asset("$dir" . "$current_file");
    @section_list_current = lynis::lynistest::parse_lynis_section_list("assets_private/$current_file");

    if (@section_list_baseline != @section_list_current) {
        record_soft_failure("poo#91383, Section quantity are not the same");
    }

    # Generate test cases/modules dynamically according to the sections,
    # compare the results between "current" and "baseline",
    # initiate files' pointer
    $f_position_b = 0;
    $f_position_c = 0;
    lynis::lynistest::load_lynis_section_tests(@section_list_current);
}

1;
