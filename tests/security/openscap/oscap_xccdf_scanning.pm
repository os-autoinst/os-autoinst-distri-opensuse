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
# Summary: Perform evaluation of XCCDF (The eXtensible Configuration
#          Checklist Description Format) file
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36907, tc#1621171

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use openscaptest;
use version_utils qw(is_sle is_leap);

sub run {

    my $scanning_match = 'm/
        Rule.*no_direct_root_logins.*fail.*
        Rule.*rule_misc_sysrq.*fail/sxx';

    my $result_match = 'm/
        encoding="UTF-8".*
        <Benchmark.*<Profile\s+id="standard".*<select.*
        idref="no_direct_root_logins"\ selected="true".*
        idref="rule_misc_sysrq"\s+selected="true".*
        <Rule\s+id="no_direct_root_logins"\s+selected="false".*
        <Rule\s+id="rule_misc_sysrq"\s+selected="false".*
        <TestResult.*<platform.*cpe:\/o:(open)?suse.*
        <rule-result.*idref="no_direct_root_logins".*<result.*fail.*
        <rule-result.*idref="rule_misc_sysrq".*<result.*fail.*
        <score\s+system="urn:xccdf:scoring:default".*
        maximum="[0-9]+/sxx';

    my $scanning_match_single = 'm/
        Title.*Direct\ root\ Logins\ Not\ Allowed.*
        Rule.*no_direct_root_logins.*fail/sxx';

    my $result_match_single = 'm/
        encoding="UTF-8".*
        <Benchmark.*<Profile\s+id="standard".*<select.*
        idref="no_direct_root_logins"\ selected="true".*
        idref="rule_misc_sysrq"\s+selected="true".*
        <Rule\s+id="no_direct_root_logins"\s+selected="false".*
        <Rule\s+id="rule_misc_sysrq"\s+selected="false".*
        <TestResult.*<platform.*cpe:\/o:(open)?suse.*
        <rule-result.*idref="no_direct_root_logins".*<result.*fail.*
        <rule-result.*idref="rule_misc_sysrq".*<result.*notselected.*
        <score\s+system="urn:xccdf:scoring:default".*
        maximum="[0-9]+/sxx';

    # Always return failed here, so we use "||true" as workaround
    validate_script_output "oscap xccdf eval --profile standard --results $xccdf_result xccdf.xml || true", sub { $scanning_match };
    validate_result($xccdf_result, $result_match);

    # Single rule testing only available on the higher version for
    # openscap-utils
    if (!(is_sle('<15') or is_leap('<15.0'))) {    # openscap >= 1.2.16
        validate_script_output "oscap xccdf eval --profile standard --rule no_direct_root_logins --results $xccdf_result_single xccdf.xml || true",
          sub { $scanning_match_single };
        validate_result($xccdf_result_single, $result_match_single);
    }
}

1;
