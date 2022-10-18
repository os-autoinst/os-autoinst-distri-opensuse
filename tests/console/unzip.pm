# SUSE's openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Testopia case_id 1454736
#
# Package: wget unzip
# Summary: Basic tests for unzip
#    1. Unzip (basic usage)
#    2. Unzip into a new directory
#    TODO:
#     - 3. Test the credibility of the zip archive
#     - 4. Unzip only one file (instead of all)
# Maintainer: Panos Georgiadis <pgeorgiadis@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';

sub run {
    my $self = shift;
    select_serial_terminal;
    zypper_call 'in wget unzip';
    assert_script_run 'mkdir -p /tmp/unzip-test/ && pushd /tmp/unzip-test';

    # 1. Unzip (basic usage)
    assert_script_run 'wget --quiet ' . data_url('console/test_unzip.zip');
    assert_script_run 'unzip test_unzip.zip';

    my $entries = 'entries1st=' . script_output('ls -1Uq /tmp/unzip-test/ | wc -l');
    die "Extract produced too few values: $entries instead of 6" unless ($entries =~ /entries1st=6$/);

    # Go one step further and verify the md5sum of each file
    assert_script_run 'wget --quiet ' . data_url('console/checklist.md5');
    assert_script_run 'md5sum -c checklist.md5';

    # 2. Unzip into a new directory
    assert_script_run 'unzip -d extract/ test_unzip.zip';
    $entries = 'entries2nd=' . script_output('ls -1Uq extract/ | wc -l');
    die "Extract produced too few values: $entries instead of 5" unless ($entries =~ /entries2nd=5$/);
    # Go one step further and verify the md5sum in extract folder of each file.
    assert_script_run 'cp test_unzip.zip extract/test_unzip.zip';
    assert_script_run 'md5sum -c checklist.md5';

    # 3. Test the credibility of the zip archive
    assert_script_run 'unzip -tq test_unzip.zip';
    assert_script_run 'popd';
}

1;
