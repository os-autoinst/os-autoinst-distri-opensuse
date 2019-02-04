# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ensure zypper info shows expected output
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>
# Tags: fate#321104, poo#15932

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use repo_tools qw(prepare_source_repo disable_source_repo);
use version_utils qw(is_sle is_leap is_opensuse);

sub test_srcpackage_output {
    my $info_output_coreutils = script_output 'zypper info srcpackage:coreutils';

    my $expected_header_coreutils = 'Information for srcpackage coreutils:';
    die "Missing info header. Expected: /$expected_header_coreutils/"
      unless $info_output_coreutils =~ /$expected_header_coreutils/;

    my $expected_package_name_coreutils = 'Name *: coreutils';
    die "Missing package name. Expected: /$expected_package_name_coreutils/"
      unless $info_output_coreutils =~ /$expected_package_name_coreutils/;
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
    select_console 'root-console';

    # check for zypper info
    test_package_output;

    if (is_sle('>=12-SP2') || is_opensuse) {
        prepare_source_repo;
        test_srcpackage_output;
        disable_source_repo;
    }
}

1;
