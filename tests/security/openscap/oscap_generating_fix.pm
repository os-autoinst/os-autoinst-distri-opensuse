# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Generate  a script that shall bring the system to a state of
#          compliance with given XCCDF Benchmark
# Maintainer: QE Security <none@suse.de>
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
    prepare_remediate_validation;

    validate_result($fix_script, $fix_script_match, 'sh');
    assert_script_run "bash ./$fix_script";

    # Verify the remediate action result
    validate_script_output "cat /etc/securetty", sub { m/^$/ };
    validate_script_output "cat /proc/sys/kernel/sysrq", sub { m/^0$/ };

    # Restore
    finish_remediate_validation;
}

1;
