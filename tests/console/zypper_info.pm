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

    # preparation of source repositories
    my $cmd;
    if (check_var('DISTRI', 'sle')) {
        # SLE maintenance tests are assumed to be SCC registered
        # and source repositories disabled by default
        if (get_var('FLAVOR') =~ /-Updates$/) {
            $cmd = q{mr -e $(zypper -n lr | awk '/-Source/ {print $1}')};
        }
        # use dvd2 as the src-repository
        else {
            # Xen PV has different device for 2nd CDROM
            if (check_var('VIRSH_VMM_TYPE', 'linux')) {
                $cmd = 'ar --type plaindir hd:///?device=/dev/xvdd repo-source';
            }
            else {
                $cmd = "ar --type plaindir cd:///?devices=/dev/sr1 repo-source";
            }
        }
    }
    # source repository is disabled by default
    elsif (check_var('DISTRI', 'opensuse')) {
        $cmd = "mr -e repo-source";
    }

    zypper_call($cmd);
    zypper_call("ref");

    # check for zypper info
    test_package_output;

    if (sle_version_at_least('12-SP2') || check_var('DISTRI', 'opensuse')) {
        test_srcpackage_output;
    }
}

1;
# vim: set sw=4 et:
