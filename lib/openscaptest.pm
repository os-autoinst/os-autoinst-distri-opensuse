# Copyright (C) 2017-2018 SUSE LLC
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

# Summary: Base module for openSCAP test cases
# Maintainer: Wes <whdu@suse.com>

package openscaptest;

use strict;
use testapi;
use utils;
use version_utils qw(is_sle is_leap);
use base 'consoletest';

sub oscap_get_test_file {
    my ($self, $source) = @_;

    assert_script_run "test -f $source || wget " . data_url("openscap/$source");
}

sub validate_result {
    my ($self, $result_file, $match) = @_;

    assert_script_run "xmllint $result_file";
    validate_script_output "cat $result_file", sub { $match };
    upload_logs($result_file);
}

sub pre_run_hook {
    my ($self) = @_;

    select_console 'root-console';

    zypper_call('in openscap-utils');

    $self->oscap_get_test_file("oval.xml");
    $self->oscap_get_test_file("xccdf.xml");
}

1;
