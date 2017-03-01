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

sub run() {
    select_console 'root-console';

    zypper_call('mr -e repo-source');
    zypper_call('ref');
    my $info_output = script_output 'zypper info srcpackage:htop';

    my $expected_header = 'Information for srcpackage htop:';
    die "Missing info header. Expected: /$expected_header/"
      unless $info_output =~ /$expected_header/;

    my $expected_package_name = 'Name                  : htop';
    die "Missing package name. Expected: /$expected_package_name/"
      unless $info_output =~ /$expected_package_name/;
}

1;
# vim: set sw=4 et:
