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
# Summary: Determine type and print information about a openscap source file
# Maintainer: Wes <whdu@suse.com>
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
