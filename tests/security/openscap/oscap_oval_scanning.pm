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
# Summary: Perform evaluation of oval (Open Vulnerability and Assessment
#          Language) file
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36904, tc#1621170

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use openscaptest;

sub run {

    my $scanning_match = 'm/
        Definition\ oval:rule_misc_sysrq:def:[0-9]:\ false.*
        Definition\ oval:no_direct_root_logins:def:[0-9]:\ false.*
        Evaluation\ done/sxx';

    my $result_match = 'm/
        encoding="UTF-8".*
        <oval_results\ xmlns:xsi.*XMLSchema-instance.*
        xmlns:oval=.*oval-common-5.*xmlns=.*oval-results-5.*
        xsi:schemaLocation=.*oval-results-5.*
        oval-results-schema.xsd.*oval-common-schema.xsd">.*
        <generator>.*product_name>cpe:\/a:open-scap:oscap.*
        product_version>.*
        <oval_definitions.*
        <definition.*id="oval:rule_misc_sysrq:def:1".*compliance.*
        <criterion.*test_ref="oval:rule_misc_sysrq:tst:1".*
        <definition.*id="oval:no_direct_root_logins:def:1".*compliance.*
        <criterion.*test_ref="oval:no_direct_root_logins:tst:1".*
                    test_ref="oval:etc_securetty_exists:tst:2".*
        <results.*<system.*<definitions.*
        definition_id="oval:rule_misc_sysrq:def:1".*
        result="false".*
        definition_id="oval:no_direct_root_logins:def:1".*
        result="false"/sxx';

    my $scanning_match_single = 'm/
        Definition\ oval:rule_misc_sysrq:def:[0-9]:\ false.*
        Evaluation\ done/sxx';

    my $result_match_single = 'm/
        encoding="UTF-8".*
        <results.*<system.*<definitions.*
        definition_id="oval:rule_misc_sysrq:def:1".*
        result="false".*
        definition_id="oval:no_direct_root_logins:def:1".*
        result="not\ evaluated"/sxx';

    validate_script_output "oscap oval eval --results $oval_result oval.xml", sub { $scanning_match };
    validate_result($oval_result, $result_match);

    validate_script_output "oscap oval eval --id oval:rule_misc_sysrq:def:1 --results $oval_result_single oval.xml", sub { $scanning_match_single };
    validate_result($oval_result_single, $result_match_single);
}

1;
