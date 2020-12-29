# Copyright (C) 2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Integrate the Lynis scanner into OpenQA: lynis env setup
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#78224, poo#88155

use base 'consoletest';
use version_utils qw(is_sle);
use registration qw(add_suseconnect_product);
use strict;
use warnings;
use testapi;
use utils;
use lynis::lynistest;

sub run {
    my $lynis_baseline_file = $lynis::lynistest::lynis_baseline_file;
    my $dir                 = $lynis::lynistest::testdir;

    select_console "root-console";

    if (is_sle) {
        add_suseconnect_product("PackageHub", undef, undef, undef, 300, 1);
        zypper_call("in lynis", timeout => 300);
    }

    # Record the pkgs' version for reference
    my $results = script_output("rpm -qi lynis");
    record_info("Pkg_ver", "Lynix packages' version is: $results");

    # Download the $LYNIS_BASELINE_FILE ($lynis_baseline_file_bydefault) baseline
    assert_script_run("wget --quiet " . data_url("lynis/$lynis_baseline_file") . " -O " . "$dir" . "$lynis_baseline_file");

    # Install server software, e.g., apache
    zypper_call("in apache2 apache2-utils");
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
