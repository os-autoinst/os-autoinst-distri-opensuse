# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: liblouis
# Summary: New tests for the braille translation library
# Maintainer: QE Core <qe-core@suse.com>

use Mojo::Base 'x11test';
use serial_terminal qw(select_serial_terminal);
use testapi;
use version_utils;
use utils "zypper_call";

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Three files are generated: uppercase alphabet, lowercase and
    # another one with the symbols defined in the braille code.
    record_info("Translating", "Making the translations into braille");
    zypper_call("install python3-louis");
    assert_script_run("curl -O " . data_url("console/python_liblouis.py"));
    assert_script_run("python3 python_liblouis.py");

    # The three files are compared and a soft failure is recorded if any of them
    # does not match the expected translation.
    record_info("Comparing", "Checking if the translations match the expected");
    assert_script_run("curl -O " . data_url("console/braille_expected_lowercase.txt"));
    my $output = script_output("diff -u braille_expected_lowercase.txt braille_result_lowercase.txt | tail -n 2", proceed_on_failure => 1);
    if ($output ne '') {
        die("\nLowercase translation does not match!\n");
    }
    else {
        record_info("Lowercase OK", "Lowercase translation is correct");
    }

    assert_script_run("curl -O " . data_url("console/braille_expected_uppercase.txt"));
    $output = script_output("diff -u braille_expected_uppercase.txt braille_result_uppercase.txt | tail -n 2", proceed_on_failure => 1);
    if ($output ne '') {
        die("\nUppercase translation does not match! - bsc#1195435\n");
    }
    else {
        record_info("Uppercase OK", "Uppercase translation is correct");
    }

    assert_script_run("curl -O " . data_url("console/braille_expected_symbols.txt"));
    $output = script_output("diff -u braille_expected_symbols.txt braille_result_symbols.txt | tail -n 2", proceed_on_failure => 1);
    if ($output ne '') {
        die("\nSymbols translation does not match - bsc#1195435\n");
    }
    else {
        record_info("Symbols OK", "Symbols translation is correct");
    }
}

1;
