# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Determine type and print information about a openscap source file
# Maintainer: QE Security <none@suse.de>
# Tags: poo#36901, tc#1621169

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use openscaptest;

sub run {

    validate_script_output "oscap info oval.xml", sub {
        m/
            Document\ type:\ OVAL\ Definitions.*
            OVAL\ version:\ [0-9]+.*
            Generated:\ [0-9]+.*
            Imported:\ [0-9]+/sxx
    };

    validate_script_output "oscap info xccdf.xml", sub {
        m/
            Document\ type:\ XCCDF\ Checklist.*
            Checklist\ version:\ [0-9]+.*
            Imported:\ [0-9]+.*
            Status:\ draft.*
            Generated:\ [0-9]+.*
            Resolved:\ false.*
            Profiles:.*
            standard.*
            Referenced\ check\ files:.*
            oval\.xml.*
            system:/sxx
    };
}

1;
