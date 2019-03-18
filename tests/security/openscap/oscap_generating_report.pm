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
# Summary: Generate document - security guide or report - form XCCDF file
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36925, tc#1621177

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use openscaptest;

sub run {
    my $xccdf_guide       = "xccdf_guide.html";
    my $xccdf_report      = "xccdf_report.html";
    my $xccdf_fix         = "xccdf_fix.sh";
    my $oval_report       = "oval_report.html";
    my $xccdf_oval_report = "xccdf_oval_report.html";

    my $xccdf_guide_match = 'm/
            Checklist.*
            contains 2 rules.*
            Restrict Root Logins.*
            Direct root Logins Not Allowed.*
            sysctl kernel.sysrq must be 0.*/sxx';

    my $xccdf_report_match = 'm/
            with profile.*Standard System Security Profile.*
            The target system did not satisfy the conditions of 2 rules.*
            Hardening SUSE Linux Enterprise.*2x fail.*
            Restrict Root Logins.*1x fail.*
            Direct root Logins Not Allowed.*
            sysctl kernel.sysrq must be 0/sxx';

    my $oval_report_match = 'm/
            OVAL Results Generator Information.*
            OVAL Definition Generator Information.*
            System Information.*
            cpe:\/a:open-scap:oscap.*
            OVAL Definition Results.*
            oval:rule_misc_sysrq:def:1.*false.*
            oval:no_direct_root_logins:def:1.*false/sxx';

    my $xccdf_oval_report_match = 'm/
            with profile.*Standard System Security Profile.*
            Evaluation Characteristics.*
            CPE Platforms.*cpe:\/o:suse.*
            Compliance and Scoring.*
            The target system did not satisfy the conditions of 2 rules.*
            Rule results.*2 failed.*
            Severity of failed rules.*1 other.*
            Score.*
            Rule Overview.*
    ';

    ensure_generated_file($oval_result);
    ensure_generated_file($xccdf_result);

    # Generate XCCDF guide
    assert_script_run "oscap xccdf generate guide --profile standard --output $xccdf_guide $xccdf_result";
    validate_result($xccdf_guide, $xccdf_guide_match, 'html');

    # Generate XCCDF report
    assert_script_run "oscap xccdf generate report --profile standard --output $xccdf_report $xccdf_result";
    validate_result($xccdf_report, $xccdf_report_match, 'html');

    # Generate OVAL report
    assert_script_run "oscap oval generate report --output $oval_report $oval_result";
    validate_result($oval_report, $oval_report_match, 'html');

    # Generate XCCDF report with additional information from failed OVAL tests
    assert_script_run "oscap xccdf generate report --oval-template $oval_result --output $xccdf_oval_report $xccdf_result";
    validate_result($xccdf_oval_report, $xccdf_oval_report_match, 'html');
}

1;
