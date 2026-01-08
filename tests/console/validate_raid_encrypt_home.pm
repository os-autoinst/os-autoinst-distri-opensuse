# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that a RAID multi-disk is directly formatted with an
# encrypted home (md is not partitioned).
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "opensusebasetest";
use testapi;
use Mojo::JSON qw(decode_json);
use scheduler 'get_test_suite_data';
use Test::Assert ':all';
use filesystem_utils qw(is_lsblk_able_to_display_mountpoints);
use version_utils qw(is_sle);

sub run {
    select_console 'root-console';
    my $md_name = get_test_suite_data()->{mds}[1]{name};
    my $params = is_sle('15+') ? '-M' : '-f -o +type';
    my $lsblk_output = decode_json(script_output("lsblk $params -J /dev/$md_name"));

    assert_equals($md_name, $lsblk_output->{blockdevices}[0]{name}, "Multi-disk name not found");
    assert_equals('crypt', $lsblk_output->{blockdevices}[0]{children}[0]{type}, "Encrypted type not found");
    assert_equals('/home', is_lsblk_able_to_display_mountpoints ? $lsblk_output->{blockdevices}[0]{children}[0]{mountpoints}[0] : $lsblk_output->{blockdevices}[0]{children}[0]{mountpoint}, "Encrypted mount point not found");
}

1;
