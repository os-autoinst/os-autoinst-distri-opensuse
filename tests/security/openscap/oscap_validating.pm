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
# Summary: Validate given OVAL and XCCDF file against a XML schema
# Maintainer: Wes <whdu@suse.com>
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
