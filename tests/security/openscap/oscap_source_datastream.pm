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
# Summary: Test SCAP source data stream
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36910, tc#1621172

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use openscaptest;

sub run {

    my $xccdf_12 = 'xccdf-1.2.xml';

    my $source_ds_match = 'm/
        <ds:data-stream-collection.*
        <ds:component\s+id=.*xml.*
        <ns0:definition.*oval:no_direct_root_logins:def:1.*class.*compliance.*
        <ns0:reference\s+ref_id.*no_direct_root_logins.*
        <ds:component\s+id=.*xml.*
        <Benchmark.*xccdf_com.suse_benchmark_test.*
        <Profile.*xccdf_com.suse_profile_standard.*
        <Rule.*xccdf_com.suse_rule_no_direct_root_logins.*selected.*false.*
        <Rule.*xccdf_com.suse_rule_rule_misc_sysrq.*selected.*false/sxx';


    my $source_ds_result_match = 'm/
        version="[0-9]+\.[0-9]+"\s+encoding="UTF-8".*
        <Benchmark.*<Profile\s+id="xccdf_com\.suse_profile_standard".*
        select.*xccdf_com\.suse_rule_no_direct_root_logins".*selected="true".*
        select.*xccdf_com\.suse_rule_rule_misc_sysrq".*selected="true".*
        Rule.*xccdf_com\.suse_rule_no_direct_root_logins".*selected="false".*
        Rule.*xccdf_com\.suse_rule_rule_misc_sysrq".*selected="false".*
        <TestResult.*<benchmark.*id="xccdf_com\.suse_benchmark_test".*
        rule-result.*xccdf_com\.suse_rule_no_direct_root_logins".*notselected.*
        rule-result.*xccdf_com\.suse_rule_rule_misc_sysrq.*notselected/sxx';

    # Convert to XCCDF version 1.2 and validate
    assert_script_run "xsltproc --stringparam reverse_DNS com.suse /usr/share/openscap/xsl/xccdf_1.1_to_1.2.xsl xccdf.xml > $xccdf_12";
    assert_script_run "oscap xccdf validate $xccdf_12";

    # Generate source datastream
    assert_script_run "oscap ds sds-compose $xccdf_12 $source_ds";
    validate_result($source_ds, $source_ds_match);

    # Scanning with source datastream
    assert_script_run "oscap xccdf eval --results $source_ds_result $source_ds";
    validate_result($source_ds_result, $source_ds_result_match);
}

1;
