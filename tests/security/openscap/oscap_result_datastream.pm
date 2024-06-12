# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test SCAP result data stream
# Maintainer: QE Security <none@suse.de>
# Tags: poo#36913, tc#1621173

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use openscaptest;

sub run {

    my $arf_result_match = qr/
        version="[0-9]+\.[0-9]+"\s+encoding="UTF-8".*
        <arf:asset-report-collection.*<ns0:definitions.*
        <ns0:criteria\s+operator="AND".*
        test_ref="oval:no_direct_root_logins:tst:1.*
        test_ref="oval:etc_securetty_exists:tst:2.*
        <ns0:criteria.*test_ref="oval:rule_misc_sysrq:tst:1".*
        <arf:reports.*<arf:report.*<arf:content.*<oval_results.*
        <oval:product_name>cpe:\/a:open-scap:oscap.*
        <test\s+test_id="oval:etc_securetty_exists:tst:2".*
        check="all"\s+result="not\sevaluated".*
        <test\s+test_id="oval:no_direct_root_logins:tst:1".*
        check="all"\s+result="not\sevaluated".*
        <test\s+test_id="oval:rule_misc_sysrq:tst:1".*
        check="at\sleast\sone"\s+result="not\sevaluated".*
        \/arf:asset-report-collection>/sxx;

    ensure_generated_file($source_ds);

    assert_script_run "oscap xccdf eval --results-arf $arf_result $source_ds";

    validate_result($arf_result, $arf_result_match);
}

1;
