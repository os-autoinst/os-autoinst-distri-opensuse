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

    if (is_sle '>=12-SP3') {
        if (is_sle '<15') {
            register_product;
        }
        else {
            # only scc has update repos with src packages
            cleanup_registration;
            assert_script_run 'SUSEConnect -r ' . get_required_var('SCC_REGCODE') . ' --url https://scc.suse.com';
        }
        zypper_call 'ref';
        my $reponame          = ((is_sle '15+') ? 'SLE-Module-Basesystem' : 'SLES') . get_var('VERSION') . '-Updates';
        my $info_output_glib2 = script_output "zypper info -r $reponame srcpackage:glib2";
        check_srcpackage_output 'glib2', $info_output_glib2;
        cleanup_registration if (is_sle);
        register_product if (is_sle '15+');
    }
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
