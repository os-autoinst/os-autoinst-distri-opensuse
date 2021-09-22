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

# Summary: Test module to validate what system role is selected.
#          using REST API.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use Test::Assert 'assert_equals';

sub run {
    my $system_role = $testapi::distri->get_system_role_controller();
    my $selected    = $system_role->get_selected_role();
    my $expected    = $system_role->get_system_role_page->{role_GNOME_desktop};
    assert_equals($expected, $selected, 'Wrong System Role is pre-selected');
}

1;