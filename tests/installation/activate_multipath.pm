# Copyright (C) 2021 SUSE LLC
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

# Summary: Activates multipath when multipath activation message appears
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use parent 'y2_installbase';
use strict;
use warnings;
use scheduler 'get_test_suite_data';

sub run {
    my $expected_mpio_activation_text = get_test_suite_data()->{mpio_activation_text};
    my $warnings_controller = $testapi::distri->get_warnings_controller();

    $warnings_controller->check_warning({expected_text => $expected_mpio_activation_text});
    $warnings_controller->accept_warning();        
}

1;