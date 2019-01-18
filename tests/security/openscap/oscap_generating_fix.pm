# Copyright (C) 2018 SUSE LLC
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
# Summary: Generate  a script that shall bring the system to a state of
#          compliance with given XCCDF Benchmark
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36916, tc#1621174

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use openscaptest;

sub run {
    my $fix_script = "fix-script.sh";

    my $fix_script_match = 'm/
        echo\s*>\s*\/etc\/securetty.*
        echo\s+0\s*>\s*\/proc\/sys\/kernel\/sysrq/sxx';

    assert_script_run "oscap xccdf generate fix --template urn:xccdf:fix:script:sh --profile standard --output $fix_script xccdf.xml";

    my $script_output = script_output "cat $fix_script";
    if ($script_output =~ m/securettyecho/) {
        record_soft_failure 'bsc#1097759';
    }
    elsif ($script_output =~ m/sysrq#\s+END/) {
        record_soft_failure 'bsc#1102706';
    }
    else {
        prepare_remediate_validation;

        validate_result($fix_script, $fix_script_match, 'sh');
        assert_script_run "bash ./$fix_script";

        # Verify the remediate action result
        validate_script_output "cat /etc/securetty",         sub { m/^$/ };
        validate_script_output "cat /proc/sys/kernel/sysrq", sub { m/^0$/ };

        # Restore
        finish_remediate_validation;
    }
}

1;
