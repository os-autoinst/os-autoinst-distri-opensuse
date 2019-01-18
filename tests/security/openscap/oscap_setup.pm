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
# Summary: Setup environment for openscap test
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#37006

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use openscaptest;
use version_utils 'is_opensuse';

sub run {

    zypper_call('in openscap-utils libxslt-tools');

    oscap_get_test_file("oval.xml");
    oscap_get_test_file("xccdf.xml");

    # xccdf.xml is for SLE, the CPE is different on openSUSE
    if (is_opensuse) {
        assert_script_run "sed -i 's#cpe:/o:suse#cpe:/o:opensuse#g' xccdf.xml";
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
