# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Validate given OVAL and XCCDF file against a XML schema
# Maintainer: QE Security <none@suse.de>
# Tags: poo#36928, tc#1626472

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use openscaptest;

sub run {
    assert_script_run "oscap oval validate oval.xml";
    assert_script_run "oscap oval validate $oval_result";

    assert_script_run "oscap xccdf validate xccdf.xml";
    assert_script_run "oscap xccdf validate $xccdf_result";
}

1;
