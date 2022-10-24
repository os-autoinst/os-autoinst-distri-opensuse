# SUSE's openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Ensure zypper info shows expected output
# - Check output of "zypper info vim" for header and package name
# - Add zypper source repository to correspondent distro version
# - Check headers and package name on output of "zypper info srcpackage:coreutils"
# - Remove source repositories added before
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>
# Tags: fate#321104, poo#15932

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use repo_tools qw(prepare_source_repo disable_source_repo);
use version_utils qw(is_sle is_leap is_opensuse);
use registration;

sub check_srcpackage_output {
    my ($pkgname, $info_output) = @_;

    my $expected_header = "Information for srcpackage $pkgname:";
    die "Missing info header. Expected: /$expected_header/" unless $info_output =~ /$expected_header/;

    my $expected_package_name = "Name *: $pkgname";
    die "Missing package name. Expected: /$expected_package_name/" unless $info_output =~ /$expected_package_name/;
}

sub test_srcpackage_output {
    my $info_output_coreutils = script_output 'zypper info srcpackage:coreutils';
    check_srcpackage_output 'coreutils', $info_output_coreutils;
}

sub test_package_output {
    my $info_output_vim = script_output 'zypper info vim';

    my $expected_header_vim = 'Information for package vim:';
    die "Missing info header. Expected: /$expected_header_vim/"
      unless $info_output_vim =~ /$expected_header_vim/;

    my $expected_package_name_vim = 'Name *: vim';
    die "Missing package name. Expected: /$expected_package_name_vim/"
      unless $info_output_vim =~ /$expected_package_name_vim/;
}

sub run {
    select_serial_terminal;

    # check for zypper info
    test_package_output;

    if (is_sle('>=12-SP2') || is_opensuse) {
        prepare_source_repo;
        test_srcpackage_output;
        disable_source_repo;
    }
}

1;
