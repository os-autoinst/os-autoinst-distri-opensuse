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
# Summary: Integrate the Lynis scanner into OpenQA: Performs a system audit
#          and upload related outputs
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#78224, poo#78230, poo#78330

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use lynis::lynistest;

sub run {
    my $dir                             = $lynis::lynistest::testdir;
    my $lynis_baseline_file             = "$dir" . $lynis::lynistest::lynis_baseline_file;
    my $lynis_audit_system_current_file = "$dir" . $lynis::lynistest::lynis_audit_system_current_file;
    my $lynis_audit_system_error_file   = "$dir" . $lynis::lynistest::lynis_audit_system_error_file;

    select_console "root-console";

    # Run "# lynis audit system" to "Performs a system audit" and save the outputs
    assert_script_run("rm -rf $lynis_audit_system_current_file");
    assert_script_run("rm -rf $lynis_audit_system_error_file");
    assert_script_run("lynis audit system --nocolors > $lynis_audit_system_current_file 2> $lynis_audit_system_error_file", timeout => 600);

    # Upload the outputs for reference: e.g.,
    # file "$lynis_audit_system_current_file" can be used to be a new baseline
    # file "$lynis_audit_system_error_file" can be used to check lynis warnings/errors
    upload_logs("$lynis_audit_system_current_file");
    upload_logs("/var/log/lynis.log");
    upload_logs("$lynis_audit_system_error_file", failok => 1);
}

sub test_flags {
    return {fatal => 1};
}

1;
