# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Testopia case_id 1454736
#
# Summary: Basic tests for unzip
#    1. Unzip (basic usage)
#    TODO:
#     - 2. Unzip into a new directory
#     - 3. Test the credibility of the zip archive
#     - 4. Unzip only one file (instead of all)
# Maintainer: Panos Georgiadis <pgeorgiadis@suse.com>

use base "consoletest";
use strict;
use testapi;

sub run() {

    # Preparation
    select_console "root-console";
    assert_script_run "mkdir -p /tmp/unzip-test/";

    # Basic Usage (Extract an archive with 7 files and check if all of them were extracted)
    assert_script_run "wget --quiet " . data_url('console/test_unzip.zip') . " -O /tmp/unzip-test/archive.zip";
    assert_script_run "cd /tmp/unzip-test; unzip archive.zip";
    my $entries = script_output("ls -l /tmp/unzip-test/ | wc -l");
    die "Extract produced too few values: $entries instead of 7" unless ($entries eq "7");

    # Go one step further and verify the md5sum of each file
    assert_script_run "wget --quiet " . data_url('console/checklist.md5') . " -O /tmp/unzip-test/checklist.md5";
    assert_script_run "md5sum -c /tmp/unzip-test/checklist.md5";
}

1;
# vim: set sw=4 et:
