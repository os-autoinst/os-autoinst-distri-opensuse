# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that a RAID multi-disk is directly formatted with an
# encrypted home (md is not partitioned).
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use Mojo::JSON qw(decode_json);
use scheduler 'get_test_suite_data';
use Test::Assert ':all';

sub run {
    select_console 'root-console';
    my $md_name = get_test_suite_data()->{mds}[1]{name};
    my $lsblk_output = decode_json(script_output("lsblk -M -J /dev/$md_name"));

    assert_equals($md_name, $lsblk_output->{blockdevices}[0]{name}, "Multi-disk name not found");
    assert_equals('crypt', $lsblk_output->{blockdevices}[0]{children}[0]{type}, "Encrypted type not found");
    assert_equals('/home', $lsblk_output->{blockdevices}[0]{children}[0]{mountpoints}[0], "Encrypted mount point not found");
}

1;
