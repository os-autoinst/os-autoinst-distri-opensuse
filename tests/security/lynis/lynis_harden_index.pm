# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Integrate the Lynis scanner into OpenQA: Checking the "Hardening
#          index" numerical values should be the same
# Maintainer: QE Security <none@suse.de>
# Tags: poo#78224, poo#78230

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use lynis::lynistest;

sub run {
    my $dir = $lynis::lynistest::testdir;
    my $lynis_baseline_file = "$dir" . $lynis::lynistest::lynis_baseline_file;
    my $lynis_current_file = "$dir" . $lynis::lynistest::lynis_audit_system_current_file;
    my $str = "Hardening index";

    select_console "root-console";

    # Parse the "Hardening index" of baseline and current files
    my $out_b = script_output("grep \"$str\" $lynis_baseline_file");
    my $out_c = script_output("grep \"$str\" $lynis_current_file");
    my $index_b = script_output("echo $out_b | cut -d ':' -f2 | cut -d ' ' -f2");
    my $index_c = script_output("echo $out_c | cut -d ':' -f2 | cut -d ' ' -f2");
    if ("$index_b" eq "$index_c") {
        record_info("Same", "\"Hardening index\" is the same.\n Baseline: $out_b\n Current: $out_c");
    }
    else {
        record_info("NotSame", "\"Hardening index\" is NOT the same.\n Baseline: $out_b\n Current: $out_c");
        record_soft_failure("poo#91383, \"Hardening index\" is NOT the same please check");
    }
}

1;
