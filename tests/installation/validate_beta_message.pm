# Copyright 2021 SUSE LLC
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

# Summary: Validates text of Beta Distribution message
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use scheduler 'get_test_suite_data';
use Test::Assert 'assert_matches';

sub run {
    my $expected_beta_text = get_test_suite_data()->{beta_text};
    my $actual_beta_text = $testapi::distri->get_popup_controller()->get_text();
    assert_matches(qr/$expected_beta_text/, $actual_beta_text,
        "Beta Distribution message does not match the expected one.");
}

1;
