# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-Later
#
# Summary: Compare the baseline before and after remediation, generate a log
# Maintainer: QE Security <none@suse.de>
# Tags: poo#104944

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use Mojo::File 'path';

sub download_baseline_log {

    # Pass baseline filename & location to this function, download it to local vm and check
    # Parameter: baseline filename
    my $filename = $_[0];
    my $testdata = path('ulogs/' . $filename)->slurp;
    save_tmp_file($filename, $testdata);
    assert_script_run("curl -O " . autoinst_url . "/files/" . $filename);
    assert_script_run("test -e $filename");
}

sub run {
    my $py_script = 'oscap_profiles/baseline_comparison.py';
    my $baseline_orig = 'oscap_xccdf_eval-stdout';
    my $baseline_remediated = 'oscap_xccdf_remediate-stdout';
    my $baseline_comparison = 'baseline_comparison_result';

    select_console 'root-console';

    # Download python script for baseline comparison
    assert_script_run('wget --quiet ' . data_url("$py_script"));

    # Download original evaluation log to local
    download_baseline_log($baseline_orig);

    # Download remediated baseline log to local
    download_baseline_log($baseline_remediated);

    # Run python script to generate log
    my $output = script_output('python3 baseline_comparison.py');

    # Record baseline info in openQA
    record_info('Baseline compared: ', $output);

    # Upload comparison log
    upload_logs("$baseline_comparison");
}

1;
