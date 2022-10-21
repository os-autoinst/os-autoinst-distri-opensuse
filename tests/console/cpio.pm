#SUSE"s openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: cpio
# Summary: Create and extract archives with cpio, including all the supported archive formats
# Maintainer: QE-Core <qe-core@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    select_serial_terminal;

    # Define the archive formats that will be used
    my @formats = ("bin", "odc", "newc", "crc", "tar", "ustar", "hpbin", "hpodc");

    # Download a folder with some files that will be used for the test purpose
    my $testdatadir = "/usr/share";
    assert_script_run "cd $testdatadir";
    assert_script_run "wget --quiet " . data_url('console/cpio/topack.tar.gz');
    assert_script_run "tar -xzvf $testdatadir/topack.tar.gz";

    # Copy the files into an archive using the different archive formats
    assert_script_run "mkdir /tmp/archive";
    foreach my $format (@formats) {
        assert_script_run "cd $testdatadir/topack && ls | cpio -o -H $format -O /tmp/archive/test_$format";
    }

    # Extract the files from an archive to a folder
    assert_script_run "mkdir /tmp/unpacked";
    foreach my $format (@formats) {
        assert_script_run "cd /tmp/unpacked; mkdir $format; cd $format; cpio -i -H $format -I /tmp/archive/test_$format";
    }

    # Check that the initial files used for testing remain the same after the archive/extract process
    foreach my $format (@formats) {
        my $result = script_output "diff  $testdatadir/topack /tmp/unpacked/$format 2>&1";
        if ($result ne "") {
            assert_script_run "rm -r /tmp/archive /tmp/unpacked";
            die "An issue occured with format $format";
        }
    }

    # Check a cpio regression : bsc#1189463
    assert_script_run "echo 1234 > filelist";
    my $res = script_output "cpio -i -d -v -E filelist </dev/null", proceed_on_failure => 1;
    record_soft_failure "bsc#1189463 - All build workers are hanging in a cpio call" if (index($res, "ioctl") == -1);

    # Cleanup
    assert_script_run "rm -r /tmp/archive /tmp/unpacked";


}
1;
